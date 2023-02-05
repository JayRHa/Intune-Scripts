<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-AllErrorAssignments
Description:
Get all failed assignment in the tenant as csv
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

function Get-GraphCall {
    param(
        [Parameter(Mandatory)]
        $url
    )
    return Invoke-RestMethod -Uri https://graph.microsoft.com/beta/$url -Headers $authToken -Method GET
}


function Get-FailedConfigAssignments{
    param(
        [Parameter(Mandatory)]
        $configProfileId
    ) 
    $result = (Get-GraphCall -url ("deviceManagement/deviceConfigurations/$configProfileId/deviceStatuses?" + '$filter=(platform%20eq%200)')).value
    return $result | Where-Object {$_.status -eq 'error'} | Select-Object deviceDisplayName, userPrincipalName, status, lastReportedDateTime
}

function Get-FailedAppAssignments{
    param(
        [Parameter(Mandatory)]
        $appId
    ) 
    $result = (Get-GraphCall -url "deviceAppManagement/mobileApps/$appId/deviceStatuses").value
    return $result | Select-Object deviceName, userPrincipalName, installState, lastSyncDateTime | Where-Object {($_.installState -ne 'installed
')}
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################
# Variables
$MailSender = "mail@abc.onmicrosoft.com"
$MailTo = "mail@abc.onmicrosoft.com"

# Automation Secrets
$tenantId = Get-AutomationVariable -Name 'TenantId'
$clientId = Get-AutomationVariable -Name 'AppId'
$clientSecret = Get-AutomationVariable -Name 'AppSecret'

# Authentication
$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

# Config Profiles
$config = (Get-GraphCall -url 'deviceManagement/deviceConfigurations?$select=id,displayName').value
$configProfiles = @()
$config | ForEach-Object {
    $results = Get-FailedConfigAssignments -configProfileId $_.id
    foreach($result in $results) {
        $result | Add-Member -MemberType NoteProperty -Name "ProfileName" -Value $_.displayName
        $configProfiles += $result
    }
}

# Apps
$apps = 'deviceAppManagement/mobileApps?$filter=(isof(%27microsoft.graph.windowsStoreApp%27)%20or%20isof(%27microsoft.graph.microsoftStoreForBusinessApp%27)%20or%20isof(%27microsoft.graph.officeSuiteApp%27)%20or%20isof(%27microsoft.graph.win32LobApp%27)%20or%20isof(%27microsoft.graph.windowsMicrosoftEdgeApp%27)%20or%20isof(%27microsoft.graph.windowsPhone81AppX%27)%20or%20isof(%27microsoft.graph.windowsPhone81StoreApp%27)%20or%20isof(%27microsoft.graph.windowsPhoneXAP%27)%20or%20isof(%27microsoft.graph.windowsAppX%27)%20or%20isof(%27microsoft.graph.windowsMobileMSI%27)%20or%20isof(%27microsoft.graph.windowsUniversalAppX%27)%20or%20isof(%27microsoft.graph.webApp%27)%20or%20isof(%27microsoft.graph.windowsWebApp%27)%20or%20isof(%27microsoft.graph.winGetApp%27))%20and%20(microsoft.graph.managedApp/appAvailability%20eq%20null%20or%20microsoft.graph.managedApp/appAvailability%20eq%20%27lineOfBusiness%27%20or%20isAssigned%20eq%20true)&$select=id,displayName'
$apps = (Get-GraphCall -url $apps).value
$appsObject = @()
$apps | ForEach-Object {
    $results = Get-FailedAppAssignments -appId $_.id
    foreach($result in $results) {
        $result | Add-Member -MemberType NoteProperty -Name "AppName" -Value $_.displayName
        $appsObject += $result
    }
}


#Generate CSV
$configProfiles | Export-Csv -Path .\configProfileErrors.csv -NoTypeInformation
$appsObject | Export-Csv -Path .\appInstallationErrors.csv -NoTypeInformation
$configProfiles_csv = [Convert]::ToBase64String([IO.File]::ReadAllBytes(".\configProfileErrors.csv"))
$appsObject_csv = [Convert]::ToBase64String([IO.File]::ReadAllBytes(".\appInstallationErrors.csv"))

#Send Mail    
$URLsend = "https://graph.microsoft.com/v1.0/users/$MailSender/sendMail"
$BodyJsonsend = @"
{
    "message": {
      "subject": "Intune error report",
      "body": {
        "contentType": "Text",
        "content": "Dear Admin, this Mail contains the error report from Intunn"
      },
      "toRecipients": [
        {
          "emailAddress": {
            "address": "$MailTo"
          }
        }
      ],
      "attachments": [
        {
          "@odata.type": "#microsoft.graph.fileAttachment",
          "name": "configProfileErrors.csv",
          "contentType": "text/plain",
          "contentBytes": "$configProfiles_csv"
        },
        {
            "@odata.type": "#microsoft.graph.fileAttachment",
            "name": "appInstallationErrors.csv",
            "contentType": "text/plain",
            "contentBytes": "$appsObject_csv"
        }
      ]
    }
  }
"@


Invoke-RestMethod -Method POST -Uri $URLsend -Headers $global:authToken -Body $BodyJsonsend