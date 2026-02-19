<#
.SYNOPSIS
    Send a Teams notification for the top failed app installations.
.DESCRIPTION
    Queries the Intune reports API for apps with the highest installation failure
    rates and posts a summary to a Microsoft Teams channel via webhook.
.NOTES
    Author : Jannik Reinhard
    Version: 1.1
#>

Function Get-AuthHeader {
    param (
        [parameter(Mandatory=$true)]$tenantId,
        [parameter(Mandatory=$true)]$clientId,
        [parameter(Mandatory=$true)]$clientSecret
    )

    $authBody = @{
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }

    $uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $accessToken = Invoke-WebRequest -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $authBody -Method Post -ErrorAction Stop -UseBasicParsing
    $accessToken = $accessToken.content | ConvertFrom-Json

    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer " + $accessToken.access_token
        'ExpiresOn'     = $accessToken.expires_in
    }

    return $authHeader
}

function Send-TeamsWebHook {
    param (
        [parameter(Mandatory=$true)]$textMessage,
        [parameter(Mandatory=$true)]$titel,
        [parameter(Mandatory=$true)]$uri
    )

    $JSONBody = ' {
        "@context": "https://schema.org/extensions",
        "@type": "MessageCard",
        "themeColor": "0072C6",
        "title": "",
        "text": "",
        "potentialAction": [

          {
            "@type": "OpenUri",
            "name": "Open App Crashes",
            "targets": [
              { "os": "default", "uri": "https://endpoint.microsoft.com/#view/Microsoft_Intune_DeviceSettings/AppsMonitorMenu/~/appInstallStatus" }
            ]
          }
        ]
      }' | ConvertFrom-Json
   $JSONBody.title = $titel
   $JSONBody.text = $textMessage


    $TeamMessageBody = ConvertTo-Json $JSONBody -Depth 5

    $parameters = @{
    "URI"         = $uri
    "Method"      = 'POST'
    "Body"        = $TeamMessageBody
    "ContentType" = 'application/json'
    }

    Invoke-RestMethod @parameters | Out-Null
}

function Get-FailedAppInstallations {
    param (
        [parameter(Mandatory=$true)]$top
    )
    $body = '{"select":["DisplayName","Publisher","Platform","AppVersion","FailedDevicePercentage","FailedDeviceCount","FailedUserCount","ApplicationId"],"skip":0,"top":5,"filter":"","orderBy":["FailedDevicePercentage desc"]}' | ConvertFrom-Json
    $body.top = $top

    $uri = 'https://graph.microsoft.com/beta/deviceManagement/reports/getAppsInstallSummaryReport'
    try {
        $result = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body ($body | ConvertTo-Json -Depth 5) -ContentType "application/json").Values
    }
    catch {
        Write-Error "Failed to retrieve app installation report: $_"
        throw
    }

    $appCrashes = @()
    $result | ForEach-Object {
        $crash = @'
        {
            "appName" : "",
            "percent" : ""
        }
'@ | ConvertFrom-Json
        $crash.appName = $_[2]
        $crash.percent = [math]::Round($_[4], 2)
        $appCrashes += $crash
    }

    return $appCrashes
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################
# To be adapted
$top = 5

# Variables
$teamWebHookUri = Get-AutomationVariable -Name 'WebHookUri'
$tenantId = Get-AutomationVariable -Name 'TenantId'
$clientId = Get-AutomationVariable -Name 'AppId'
$clientSecret = Get-AutomationVariable -Name 'AppSecret'

# Authentication
$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

try {
    $appCrashes = Get-FailedAppInstallations -top $top
    $text = ""
    $appCrashes | ForEach-Object {
        $text = $text + "
    - $($_.percent)% $($_.appName)"
    }

    Send-TeamsWebHook -textMessage $text -titel "Top 5 apps with the most installation errors" -uri $teamWebHookUri
}
catch {
    Write-Error "Failed to send Teams notification: $_"
    throw
}
