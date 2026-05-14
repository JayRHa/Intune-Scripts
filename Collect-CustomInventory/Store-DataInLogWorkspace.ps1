<#PSScriptInfo
.SYNOPSIS
    Azure Function to validate incoming device inventory requests and store data in Log Analytics.
.DESCRIPTION
    Receives an HTTP request containing device telemetry, validates the tenant ID
    and device name against Azure AD, then forwards the payload to a Log Analytics
    workspace via the HTTP Data Collector API.
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
    Release: v1.0 - Init
             v1.1 - Bug fixes, code-quality improvements
#>

using namespace System.Net
param($Request, $TriggerMetadata)

# Configuration
$logType = "MMSRemediationData"
###########################################################################################
################################### Functions #############################################
###########################################################################################

function Get-TenantIdValidated {
    param(
        [Parameter(Mandatory = $true)]
        [string]$tenantId
    )
    $currentTenantId = (Get-MgOrganization).Id
    if ($currentTenantId -ne $tenantId) {
        throw "The tenant id provided is not the same as the current tenant id"
    }
    return $true
}

function Get-DeviceNameValidated {
    param(
        [Parameter(Mandatory = $true)][string]$deviceName,
        [Parameter(Mandatory = $true)][string]$aadDeviceId
    )
    # The device name comes from an HTTP request body and is therefore untrusted user
    # input. Interpolating it directly into an OData $filter expression allows an
    # attacker to break out of the string literal and modify the filter. Escape any
    # single quotes per the OData spec (a literal quote is encoded as two quotes)
    # before embedding the value.
    $escapedDeviceName = $deviceName -replace "'", "''"
    $currentDeviceId = (Get-MgDevice -Filter "displayName eq '$escapedDeviceName'").DeviceId
    if ($currentDeviceId -ne $aadDeviceId) {
        throw "The device name provided is not the same as the current device name"
    }
    return $true
}
Function Get-SignatureBuilded ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource) {
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)
    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId, $encodedHash
    return $authorization
}


Function Send-LogAnalyticsData($f_customerId, $f_sharedKey, $f_body, $f_logType) {
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $f_body.Length
    $signature = Get-SignatureBuilded `
        -customerId $f_customerId `
        -sharedKey $f_sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $f_customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization"        = $signature;
        "Log-Type"             = $f_logType;
        "x-ms-date"            = $rfc1123date;
        "time-generated-field" = "";
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $f_body -UseBasicParsing
    return $response.StatusCode

}

function Get-NameFromRequest {
    param (
        [Parameter(Mandatory = $true)][string]$varName
    )

    $name = ($Request.Body | ConvertFrom-Json).$varName
    if (-not $name) {
        $name = $($Request.Body | ConvertFrom-Json).$varName
    }

    if (-not $name) {
        Push-OutputBinding -Name response -Value ([HttpResponseContext]@{
                StatusCode = [System.Net.HttpStatusCode]::BadRequest
                Body       = "Please pass a name on the query string or in the request body for $varName"
            })
    }
    return $name
}
###########################################################################################
##################################### Start ###############################################
###########################################################################################
try {
    Connect-AzAccount -Identity
    $token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"
    $token = (ConvertTo-SecureString $token.Token -AsPlainText -Force)
    Connect-MgGraph -AccessToken $token
}
catch {
    Push-OutputBinding -Name response -Value ([HttpResponseContext]@{
            StatusCode = [System.Net.HttpStatusCode]::InternalServerError
            Body       = "Failed to authenticate to Azure AD: $_"
        })
    return
}


# Variables
$workspaceId = $env:WORKSPACE_ID
$workspaceKey = $env:WORKSPACE_KEY

try {
    $json_data = (Get-NameFromRequest -varName "data")
}
catch {
    Push-OutputBinding -Name response -Value ([HttpResponseContext]@{
            StatusCode = [System.Net.HttpStatusCode]::BadRequest
            Body       = "Failed to get data from request: $_"
        })
    return
}

try {
    $json_validation = (Get-NameFromRequest -varName "validation")
}
catch {
    Push-OutputBinding -Name response -Value ([HttpResponseContext]@{
            StatusCode = [System.Net.HttpStatusCode]::BadRequest
            Body       = "Failed to get data from request: $_"
        })
    return
}

try {
    if (-not (Get-TenantIdValidated -tenantId $json_validation.tenantId)) {
        throw "The tenant id provided is not the same as the current tenant id "
    }

    if (-not (Get-DeviceNameValidated -deviceName $json_data.data.hostname -aadDeviceId $json_validation.aadDeviceId)) {
        throw "The device name provided is not the same as the current device name"
    }
}
catch {
    Push-OutputBinding -Name response -Value ([HttpResponseContext]@{
            StatusCode = [System.Net.HttpStatusCode]::BadRequest
            Body       = "Validation failed: $_"
        })
    return
}


try {
    $data = $json_data | ConvertTo-Json -Depth 100
    $params = @{
        f_customerId = $workspaceId
        f_sharedKey  = $workspaceKey
        f_body       = ([System.Text.Encoding]::UTF8.GetBytes($data))
        f_logType    = $logType
    }

    $logResponse = Send-LogAnalyticsData @params
}
catch {
    Push-OutputBinding -Name response -Value ([HttpResponseContext]@{
            StatusCode = [System.Net.HttpStatusCode]::InternalServerError
            Body       = "Failed to send data to Log Analytics: $_"
        })
    return
}

Push-OutputBinding -Name response -Value ([HttpResponseContext]@{
        StatusCode = [System.Net.HttpStatusCode]::OK
        Body       = "Log response: $logResponse"
    })
