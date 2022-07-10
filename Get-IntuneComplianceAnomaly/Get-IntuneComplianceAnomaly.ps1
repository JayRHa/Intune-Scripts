<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-IntuneComplianceAnomaly
Description:
Detect anomaly in the compliance state
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
    "summary" = "Meine erste Alert-Summary!"
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
$anomalyEndpoint = "https://intune-anomaly.cognitiveservices.azure.com"
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

$complianceState = Invoke-RestMethod -Uri ("https://graph.microsoft.com/beta/deviceManagement/reports/getHistoricalReport") -ContentType 'application/json' -Headers $authToken -Method POST -Body ($params | ConvertTo-Json)
$stateCountJson = @'
{ 
    "series": [],
    "maxAnomalyRatio": 0.40,
    "sensitivity": 95,
    "granularity": "daily"
}
'@ | ConvertFrom-Json


foreach($check in $checks) {
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
    $stateCountJson.series = $stateCountJson.series | Group-Object timestamp | %{
        New-Object psobject -Property @{
            timestamp = $_.Name
            value = ($_.Group | Measure-Object value -Sum).Sum
        }
    } | Sort-Object timestamp -uniqu
    
    
    $authHeader = @{'Ocp-Apim-Subscription-Key'="$anomalyKey"}
    $result = Invoke-RestMethod -Uri "$anomalyEndpoint/anomalydetector/v1.0/timeseries/last/detect" -ContentType 'application/json' -Headers $authHeader -Method POST -Body  ($stateCountJson | ConvertTo-JSON)
    if($result.isAnomaly -eq $true -and $result.isPositiveAnomaly -eq $true){
	$text  = "`n  
		Anomaly detected for compliance rule: $check.
		Expected value: $($result.expectedValue)
		Current values: $(($stateCountJson.series[$stateCountJson.series.count -1]).value)
		Date: $(($stateCountJson.series[$stateCountJson.series.count -1]).timestamp)
"

        Send-TeamsWebHook -textMessage $text -titel "Compliance rule anomaly detected for: $check" -uri $teamWebHookUri
    }
}