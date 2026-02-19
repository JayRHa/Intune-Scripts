<#PSScriptInfo
.SYNOPSIS
    Detect anomalies in Intune compliance state using Azure Cognitive Services.
.DESCRIPTION
    Queries Microsoft Graph for device compliance trend data, builds a time series
    per compliance check, and sends each series to the Azure Anomaly Detector API.
    When a positive anomaly is found a notification is posted to a Teams webhook.
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
    Release: v1.0 - Init
             v1.1 - Bug fixes, code-quality improvements
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

    Invoke-RestMethod @parameters | Out-Null
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

$params = @{
	Name = "deviceComplianceTrend"
    Filter = "(ComplianceState ne '9A09757A-6676-43A7-A0F1-F749A406142C') and (DeviceType ne '9A09757A-6676-43A7-A0F1-F749A406142C')"
	Select = @(
		"Date"
		"ComplianceState"
		"Count"
        "DeviceType"
	)
	Top = 10000
}

try {
    $complianceState = Invoke-RestMethod -Uri ("https://graph.microsoft.com/beta/deviceManagement/reports/getHistoricalReport") -ContentType 'application/json' -Headers $authToken -Method POST -Body ($params | ConvertTo-Json)
} catch {
    Write-Error "Failed to retrieve compliance report: $_"
    return
}

$stateCountJson = @'
{
    "series": [],
    "maxAnomalyRatio": 0.40,
    "sensitivity": 95,
    "granularity": "daily"
}
'@ | ConvertFrom-Json


foreach($check in $checks) {
    $stateCountJson.series = @()
    $complianceState.values | ForEach-Object {
        if($_[0] -eq $check){
            $compliantState = @'
            {
                "timestamp" : "",
                "value" : "",
                "group" : ""
            }
'@ | ConvertFrom-Json
            $compliantState.timestamp = $_[2]
            $compliantState.value = $_[1]
            $compliantState.group = $_[0]

            $stateCountJson.series += $compliantState
        }
    }
    $stateCountJson.series = $stateCountJson.series | Group-Object timestamp | ForEach-Object {
        New-Object psobject -Property @{
            timestamp = $_.Name
            value = ($_.Group | Measure-Object value -Sum).Sum
        }
    } | Sort-Object timestamp -Unique


    $authHeader = @{'Ocp-Apim-Subscription-Key'="$anomalyKey"}
    try {
        $result = Invoke-RestMethod -Uri "$anomalyEndpoint/anomalydetector/v1.0/timeseries/last/detect" -ContentType 'application/json' -Headers $authHeader -Method POST -Body  ($stateCountJson | ConvertTo-JSON)
    } catch {
        Write-Error "Failed to call Anomaly Detector API for check '$check': $_"
        continue
    }
    if($result.isAnomaly -eq $true -and $result.isPositiveAnomaly -eq $true){

        $date = [System.DateTime]::Parse($(($stateCountJson.series[$stateCountJson.series.count -1]).timestamp)).ToString("yyyy.MM.dd")
        $expectedValue = [math]::Round($($result.expectedValue), 2)
        $currentValue = [math]::Round($(($stateCountJson.series[$stateCountJson.series.count -1]).value), 2)

	$text  = "`n
		Anomaly detected for compliance rule: $check.
		Expected value: $expectedValue
		Current values: $currentValue
		Date: $date
"

        Send-TeamsWebHook -textMessage $text -titel "Compliance rule anomaly detected for: $check" -uri $teamWebHookUri
    }
}
