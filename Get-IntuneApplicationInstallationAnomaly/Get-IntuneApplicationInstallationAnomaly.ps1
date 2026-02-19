<#PSScriptInfo
.SYNOPSIS
    Detect anomalies in Intune application installation states.
.DESCRIPTION
    Queries Microsoft Graph for mobile app installation reports, builds a daily
    failure time series per application, and sends each series to the Azure
    Anomaly Detector API. When a positive anomaly is found a notification is
    posted to a Teams webhook.
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
function Get-AppTimeSeries {
    param(
             [Parameter(Mandatory)]
             $appId
    )

    # Get App report
    $params = @{
        Select = @(
            "DeviceName"
            "LastModifiedDateTime"
            "AppInstallState"
        )
        Skip = 0
        Filter = "(ApplicationId eq '$appId')"
        OrderBy = @(
        )
    }
    try {
        $appInstallationState = Invoke-RestMethod -Uri ("https://graph.microsoft.com/beta/deviceManagement/reports/getDeviceInstallStatusReport") -ContentType 'application/json' -Headers $authToken -Method POST -Body ($params | ConvertTo-Json)
    } catch {
        Write-Error "Failed to retrieve app install status for app $appId : $_"
        return $null
    }

    # Structure result
    $appState = @()
    $appInstallationState.Values | ForEach-Object {
        $computerAppState = @'
        {
            "timestamp" : "",
            "value" : ""
        }
'@ | ConvertFrom-Json

        if(-not($_[1] -eq 'Installed' -or $_[1] -eq 'Not applicable')){
            $computerAppState.timestamp = [System.DateTime]::Parse($_[3]).ToString("yyyy.MM.ddT00:00:00")
            $computerAppState.value = 1
            $appState += $computerAppState
        }
    }

    $appState = $appState | Group-Object timestamp | ForEach-Object {
        New-Object psobject -Property @{
            timestamp = $_.Name
            value = ($_.Group | Measure-Object value -Sum).Sum
        }
    } | Sort-Object timestamp -Unique

    return $appState
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################
# To be adapted
$anomalyEndpoint = "https://xxxx.cognitiveservices.azure.com"

# Variables
$teamWebHookUri = Get-AutomationVariable -Name 'WebHookUri'
$anomalyKey = Get-AutomationVariable -Name 'AnomalyKey'
$tenantId = Get-AutomationVariable -Name 'TenantId'
$clientId = Get-AutomationVariable -Name 'AppId'
$clientSecret = Get-AutomationVariable -Name 'AppSecret'

# Authentication
$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

try {
    $apps = (Invoke-RestMethod -Uri ("https://graph.microsoft.com/beta/deviceAppManagement/mobileApps") -Headers $authToken -Method GET).value
} catch {
    Write-Error "Failed to retrieve mobile apps: $_"
    return
}
$apps = $apps | Where-Object {-not ($_.'@odata.type' -eq '#microsoft.graph.managedIOSStoreApp' -or $_.'@odata.type' -eq '#microsoft.graph.managedAndroidStoreApp')}

foreach ($app in $apps) {
    $appSeriesContent = Get-AppTimeSeries -appId ($app.id)


    if($null -eq $appSeriesContent -or $appSeriesContent.count -lt 12){continue}

    $stateCountJson = @'
    {
        "series": [],
        "maxAnomalyRatio": 0.40,
        "sensitivity": 95,
        "granularity": "daily"
    }
'@ | ConvertFrom-Json

    $stateCountJson.series = $appSeriesContent

    $authHeader = @{'Ocp-Apim-Subscription-Key'="$anomalyKey"}
    try {
        $result = Invoke-RestMethod -Uri "$anomalyEndpoint/anomalydetector/v1.0/timeseries/last/detect" -ContentType 'application/json' -Headers $authHeader -Method POST -Body  ($stateCountJson | ConvertTo-JSON)
    } catch {
        Write-Error "Failed to call Anomaly Detector API for app '$($app.displayname)': $_"
        continue
    }

     if($result.isAnomaly -eq $true -and $result.isPositiveAnomaly -eq $true){
        $date = [System.DateTime]::Parse($(($stateCountJson.series[$stateCountJson.series.count -1]).timestamp)).ToString("yyyy.MM.dd")
        $expectedValue = [math]::Round($($result.expectedValue), 2)
        $currentValue = [math]::Round($(($stateCountJson.series[$stateCountJson.series.count -1]).value), 2)

	$text  = "`n
		Anomaly detected for application: $($app.displayname)
            ApplicationId: $($app.id)
		Expected value: $expectedValue
		Current values: $currentValue
		Date: $date
"

        Send-TeamsWebHook -textMessage $text -titel "Application installation anomaly detected for: $($app.displayname)" -uri $teamWebHookUri
    }
}
