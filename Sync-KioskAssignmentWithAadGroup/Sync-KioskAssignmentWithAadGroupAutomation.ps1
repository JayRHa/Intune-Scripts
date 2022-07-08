
<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Sync-KioskAssignmentWithAadGroup
Description:
Sync aad group with kisok profile
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
        $apiUri,
        [Parameter(Mandatory)]
        $method
    )
    return Invoke-RestMethod -Uri https://graph.microsoft.com/beta/$apiUri -Headers $authToken -Method $method
}




#################################################################################################
########################################### Start ###############################################
#################################################################################################
$tenantId = Get-AutomationVariable -Name 'TenantId'
$clientId = Get-AutomationVariable -Name 'AppId'
$clientSecret = Get-AutomationVariable -Name 'AppSecret'

$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

$profileId = ''
$groupId = ''



$kioskProfile  = Get-GraphCall -apiUri "deviceManagement/deviceConfigurations/$profileId" -method GET
$request = @'
{
    "@odata.type": "#microsoft.graph.windowsKioskConfiguration",
    "kioskProfiles": []
}
'@ | ConvertFrom-Json
$request.kioskProfiles += $kioskProfile.kioskProfiles

$kioskProfileAssignments = @()
($groupMember = Get-GraphCall -apiUri "/groups/$groupId/members" -method GET).Value | ForEach-Object {
    if($_.'@odata.type' -eq '#microsoft.graph.user'){
        $groupMemberJson = @'
        {
            "@odata.type":  "#microsoft.graph.windowsKioskAzureADUser",
            "userId":  "",
            "userPrincipalName":  ""
        }
'@ | ConvertFrom-Json
$groupMemberJson.userId = $_.id
$groupMemberJson.userPrincipalName = $_.userPrincipalName
$kioskProfileAssignments += $groupMemberJson
    }
}


$request.kioskProfiles[0].userAccountsConfiguration = $kioskProfileAssignments

Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$profileId" -Headers $authToken -Method PATCH -Body ($request | ConvertTo-Json -Depth 7)
