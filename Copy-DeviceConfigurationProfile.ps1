<#
.SYNOPSIS
    Copy an Intune device configuration profile
.DESCRIPTION
    Copy a device configuration profile in Intune. This script does not work with ADMX templates.
    Uses Microsoft Graph API via the Microsoft.Graph.Authentication module.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

#Requires -Modules Microsoft.Graph.Authentication

function Connect-MgGraphIfNeeded {
    $context = Get-MgContext
    if (-not $context) {
        Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All" -NoWelcome
    }
}

function Get-ListOfProfiles {
    try {
        $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations" -Method GET
    } catch {
        Write-Error "Failed to retrieve configuration profiles: $_"
        return
    }
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

    $filteredProfile = $ConfigProfile | Select-Object -Property * -ExcludeProperty id,createdDateTime,lastModifiedDateTime,version,supportsScopeTags
    $profileJson = $filteredProfile | ConvertTo-Json -Depth 10
    Write-Host $profileJson
    try {
        Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations" -Method POST -Body $profileJson -ContentType "application/json"
    } catch {
        Write-Error "Failed to import configuration profile: $_"
    }
}


##################################################
#Get auth token
Connect-MgGraphIfNeeded

# Write all existing config profiles
$profiles = Get-ListOfProfiles
Write-Host "++++++++++++++++++++++++++++++"
Write-Host "+++++++Config Profiles++++++++"
Write-Host "++++++++++++++++++++++++++++++"
$profiles.ForEach({Write-Host " - " $_.name})
Write-Host "++++++++++++++++++++++++++++++"


$profileName = Read-Host "Enter the name of the profile you want to copy"
$profileToBeCopied = ($profiles | Where-Object {$_.name -eq "$profileName"})[0]

if($null -eq $profileToBeCopied) {
   Write-Host "Profile not found" -ForegroundColor Yellow
   return
}

$profileNameNew = Read-Host "Enter the new name of the object you want to create"
$profileToBeCopied.profile.displayName = $profileNameNew

Import-ConfigurationProfile -ConfigProfile $profileToBeCopied.profile
