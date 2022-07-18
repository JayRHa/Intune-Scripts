<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-IntuneBlueScreenAnomaly
Description:
Detect anomaly for BSOD occurrence
Release notes:
Version 1.0: Init
#> 
Function Get-AuthHeader{
    param (
        [parameter(Mandatory=$true)]$tenantId,
        [parameter(Mandatory=$true)]$clientId,
        [parameter(Mandatory=$true)]$clientSecret
       )
    
    $authBody=@{
        client_id=$clientId
        client_secret=$clientSecret
        scope="https://graph.microsoft.com/.default"
        grant_type="client_credentials"
    }

    $uri="https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $accessToken=Invoke-WebRequest -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $authBody -Method Post -ErrorAction Stop -UseBasicParsing
    $accessToken=$accessToken.content | ConvertFrom-Json

    $authHeader = @{
        'Content-Type'='application/json'
        'Authorization'="Bearer " + $accessToken.access_token
        'ExpiresOn'=$accessToken.expires_in
    }
    
    return $authHeader
}

function Send-TeamsWebHook{
    param (
        [parameter(Mandatory=$true)]$textMessage,
        [parameter(Mandatory=$true)]$titel,
        [parameter(Mandatory=$true)]$uri
       )

    $JSONBody = [PSCustomObject][Ordered]@{
    "@type" = "MessageCard"
    "@context" = "<http://schema.org/extensions>"
    "summary" = "."
    "themeColor" = '0078D7'
    "title" = "$titel"
    "text" = "$textMessage"
    }

    $TeamMessageBody = ConvertTo-Json $JSONBody

    $parameters = @{
    "URI" = $uri
    "Method" = 'POST'
    "Body" = $TeamMessageBody
    "ContentType" = 'application/json'
    }

    Invoke-RestMethod @parameters | Out-NULL
}
#################################################################################################
########################################### Start ###############################################
#################################################################################################
# To be adapted
$anomalyEndpoint = "https://xxxx.cognitiveservices.azure.com"
$checks = "Not compliant", "Not evaluated"

# Variables
$teamWebHookUri = Get-AutomationVariable -Name 'WebHookUri'
$anomalyKey = Get-AutomationVariable -Name 'AnomalyKey'
$tenantId = Get-AutomationVariable -Name 'TenantId'
$clientId = Get-AutomationVariable -Name 'AppId'
$clientSecret = Get-AutomationVariable -Name 'AppSecret'


# Authentication
$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret
$restartReason = Invoke-RestMethod -Uri ('https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsMetricHistory/?dtFilter=all&$select=metricDateTime,userExperienceAnalyticsMetric&$expand=*') -Headers $authToken -Method GET

$blueScreenCountDevices = $restartReason.value | Where-Object {$_.userExperienceAnalyticsMetric.id -eq "blueScreenAveragePerDevice"}

$allBlueScreenAveragePerDevice = @()
$blueScreenCountDevices | ForEach-Object {
    $blueScreenAveragePerDevice = @'
        {
            "timestamp" : "",
            "value" : ""
        }
'@ | ConvertFrom-Json
    $blueScreenAveragePerDevice.timestamp = $_.metricDateTime
    $blueScreenAveragePerDevice.value = $_.userExperienceAnalyticsMetric.value
    
    $allBlueScreenAveragePerDevice += $blueScreenAveragePerDevice

}

$allBlueScreenAveragePerDevice = $allBlueScreenAveragePerDevice | Group-Object timestamp | %{
    New-Object psobject -Property @{
        timestamp = $_.Name
        value = ($_.Group | Measure-Object value -Sum).Sum
    }
} | Sort-Object timestamp -uniqu

$stateCountJson = @'
{ 
    "series": [],
    "maxAnomalyRatio": 0.40,
    "sensitivity": 95,
    "granularity": "daily"
}
'@ | ConvertFrom-Json


$stateCountJson.series = $allBlueScreenAveragePerDevice
    
$authHeader = @{'Ocp-Apim-Subscription-Key'="$anomalyKey"}
$result = Invoke-RestMethod -Uri "$anomalyEndpoint/anomalydetector/v1.0/timeseries/last/detect" -ContentType 'application/json' -Headers $authHeader -Method POST -Body  ($stateCountJson | ConvertTo-JSON)

if($result.isAnomaly -eq $true -and $result.isPositiveAnomaly -eq $true){

    $date = [System.DateTime]::Parse($(($stateCountJson.series[$stateCountJson.series.count -1]).timestamp)).ToString("yyyy.MM.dd")
    $expectedValue = [math]::Round($($result.expectedValue), 2)
    $currentValue = [math]::Round($(($stateCountJson.series[$stateCountJson.series.count -1]).value), 2)

$text  = "`n  
    Anomaly detected for Bluescreen of Death (Avg per device)
    Expected value: $expectedValue
    Current values: $currentValue
    Date: $date
"
    Send-TeamsWebHook -textMessage $text -titel "Bluescreen of Death anomaly detected" -uri $teamWebHookUri
}
