<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Copy-DeviceConfigurationPolicy
Description:
Copy an configuration profile in intune. This script does not work with ADMX templates
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

    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
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
function Get-ListOfProfiles {
    $response = Invoke-RestMethod -Uri https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations -Headers $authToken -Method GET
    $profiles = @()
    $nr = 1
    foreach ($profile in $response.value)
    {
        $objProfile = [PSCustomObject]@{
            number = $nr
            id = $profile.id
            name = $profile.displayName
            description = $profile.description
            profile =$profile
        }
        
        $profiles += $objProfile 
        $nr++
    }
    return $profiles
}
function Import-ConfigurationProfile {
    param(
             [Parameter(Mandatory)]
             $ConfigProfile
       )
    
    $profile = $ConfigProfile | Select-Object -Property * -ExcludeProperty id,createdDateTime,lastModifiedDateTime,version,supportsScopeTags
    $profile = $ConfigProfile | ConvertTo-Json
    Write-Host $profile
    Invoke-RestMethod -Uri https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations -Headers $authToken -Method Post -Body $profile -ContentType "application/json" 
}


##################################################
#Get auth toke
if(-not $global:authToken.Authorization){
    if($User -eq $null -or $User -eq ""){
    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host
    }
    $global:authToken = Get-AuthToken -User $User
}

# Write all existing confi profiles
$profiles = Get-ListOfProfiles
Write-Host "++++++++++++++++++++++++++++++"
Write-Host "+++++++Config Profiles++++++++"
Write-Host "++++++++++++++++++++++++++++++"
$profiles.ForEach({Write-Host " - " $_.name})
Write-Host "++++++++++++++++++++++++++++++"


$profileName = Read-Host "Enter the name of the profile you want to copy"
$profileToBeCopied = ($profiles | where {$_.name -eq "$profileName"})[0]

if($profileToBeCopied -eq $null) {
   Write-Host "Profile not found" -ForegroundColor Yellow
   return
}

$profileNameNew = Read-Host "Enter the new name of the object you want to create"
$profileToBeCopied.profile.displayName = $profileNameNew

Import-ConfigurationProfile -ConfigProfile $profileToBeCopied.profile