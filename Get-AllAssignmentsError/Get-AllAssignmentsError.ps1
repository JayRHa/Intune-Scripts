<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-AllErrorAssignments
Description:
Get all failed assignment in the tenant as csv
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
if(-not $global:authToken){
    if($User -eq $null -or $User -eq ""){
    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host
    }
    $global:authToken = Get-AuthToken -User $User
}

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
