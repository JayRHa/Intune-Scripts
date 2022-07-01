<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-DeviceAppInventory
Description:
Write all discovered app in an log analytics workspace
Release notes:
Version 1.0: Init
#>

################################################################################################################
############################################# Variables ########################################################
################################################################################################################
$customerId = "" # Add Workspace ID
$sharedKey = "" # Add Primary key
$logType = "DiscoveredApps"

function Get-GraphAuthentication{
    $GraphPowershellModulePath = "$global:Path/Microsoft.Graph.psd1"
    if (-not (Get-Module -ListAvailable -Name 'Microsoft.Graph')) {
  
        if (-Not (Test-Path $GraphPowershellModulePath)) {
            Write-Error "Microsoft.Graph.Intune.psd1 is not installed on the system check: https://docs.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0"
            Return
        }
        else {
            Import-Module "$GraphPowershellModulePath"
            $Success = $?
  
            if (-not ($Success)) {
                Write-Error "Microsoft.Graph.Intune.psd1 is not installed on the system check: https://docs.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0"
                Return
            }
        }
    }
  

    try {
      Connect-MgGraph -Scopes "Device.Read.All"
    } catch {
      Write-Error "Failed to connect to MgGraph"
      return $false
    }
    
    Select-MgProfile -Name "beta"
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

Function Post-LogAnalyticsData($f_customerId, $f_sharedKey, $f_body, $f_logType)
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
        $logResponse = Post-LogAnalyticsData @params
    }
}
