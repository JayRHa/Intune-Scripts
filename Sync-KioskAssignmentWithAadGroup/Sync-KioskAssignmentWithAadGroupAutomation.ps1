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
    $tenantId = 'ad7cb8fd-339e-438e-8db7-0168697e33f2'
    $clientId = '2aa220cc-f720-4b56-abfe-fecd8031c278'
    $clientSecret = 'fDM8Q~kgNYRGOV9xeBlDR-7U0tuIIWme5GiG6aYN'


    $connectionDetails = @{
        'tenant'     	= $tenantId
        'client_id'  	= $clientId
        'scope'	 	 	= 'https://graph.microsoft.com/.default'
        'client_secret' = $clientSecret
        'grant_type'	= 'client_credentials'
    }

    $response = Invoke-WebRequest -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -ContentType "application/x-www-form-urlencoded" -Body $connectionDetails -Method Post
    
    $authHeader = @{
        'Content-Type'='application/json'
        'Authorization'="Bearer " + ($response.content | ConvertFrom-Json).access_token
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
