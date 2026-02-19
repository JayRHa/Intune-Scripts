<#
.SYNOPSIS
    Export discovered apps from Intune to a Log Analytics workspace.
.DESCRIPTION
    Connects to Microsoft Graph, enumerates all managed devices and their
    detected applications, then sends each app record as JSON to the Azure
    Monitor HTTP Data Collector API.
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
    Release: v1.0 - Init
             v1.1 - Removed deprecated Select-MgProfile, fixed Get-GraphAuthentication,
                     renamed Send-LogAnalyticsData, added guards and try/catch
#>

################################################################################################################
############################################# Variables ########################################################
################################################################################################################
$customerId = "" # Add Workspace ID
$sharedKey = "" # Add Primary key
$logType = "DiscoveredApps"

if ([string]::IsNullOrEmpty($customerId) -or [string]::IsNullOrEmpty($sharedKey)) {
    Write-Error "Log Analytics credentials are not configured. Set `$customerId and `$sharedKey before running."
    exit 1
}

function Get-GraphAuthentication{
    if (-not (Get-Module -ListAvailable -Name 'Microsoft.Graph')) {
        Write-Error "Microsoft.Graph module is not installed. Install via: Install-Module Microsoft.Graph -Scope CurrentUser"
        return $false
    }

    try {
      Connect-MgGraph -Scopes "Device.Read.All"
    } catch {
      Write-Error "Failed to connect to MgGraph: $_"
      return $false
    }

    return $true
}

Function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}

Function Send-LogAnalyticsData($f_customerId, $f_sharedKey, $f_body, $f_logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $f_body.Length
    $signature = Build-Signature `
        -customerId $f_customerId `
        -sharedKey $f_sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $f_customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $f_logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = "";
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $f_body -UseBasicParsing
    return $response.StatusCode
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################

Get-GraphAuthentication | Out-Null

try {
    Get-MgDeviceManagementManagedDevice | ForEach-Object {
        $deviceHostname = $_.deviceName
        $device = Get-MgDeviceManagementManagedDevice -Expand detectedApps -ManagedDeviceId $_.id
        $device.detectedApps | ForEach-Object {
            $properties = [Ordered] @{
                "Hostname"      = $deviceHostname
                "AppName"       = $_.DisplayName
                "Version"       = $_.Version
            }

            $sdeviceAppInventory = (New-Object -TypeName "PSObject" -Property $properties) | ConvertTo-Json

            $params = @{
                f_customerId = $customerId
                f_sharedKey  = $sharedKey
                f_body       = ([System.Text.Encoding]::UTF8.GetBytes($sdeviceAppInventory))
                f_logType    = $logType
            }
            $logResponse = Send-LogAnalyticsData @params
        }
    }
}
catch {
    Write-Error "Failed to process device app inventory: $_"
    exit 1
}
