<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Sync-KioskAssignmentWithAadGroup
Description:
Sync aad group with kisok profile
Release notes:
Version 1.0: Init
#>

function Get-AuthToken {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $User
    )

    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    $tenant = $userUpn.Host
    $AadModule = Get-Module -Name "AzureAD" -ListAvailable
    if ($AadModule -eq $null) {
        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    }

    $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    Add-Type -Path $adal
    Add-Type -Path $adalforms
    # [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    # [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$Tenant"

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
    $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
    $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result

      
    $authHeader = @{
        'Content-Type'='application/json'
        'Authorization'="Bearer " + $authResult.AccessToken
        'ExpiresOn'=$authResult.ExpiresOn
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
$profileId = '813d246a-d4cf-473a-bf85-91e0e0873ee3'
$groupId = 'b1b7ec1f-1158-4b5c-b4c2-2004df3eb182'

#Auth
if(-not $global:authToken){
    if($User -eq $null -or $User -eq ""){
    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host
    }
    $global:authToken = Get-AuthToken -User $User
}

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




