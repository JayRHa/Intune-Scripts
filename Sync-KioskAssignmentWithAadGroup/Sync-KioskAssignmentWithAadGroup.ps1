<#
.SYNOPSIS
    Sync an AAD group membership with an Intune kiosk profile assignment.
.DESCRIPTION
    Reads members from the specified AAD group and updates the kiosk profile
    user accounts configuration to match the group membership.
.NOTES
    Author : Jannik Reinhard
    Version: 1.1
#>

#Requires -Modules Microsoft.Graph.Authentication

function Connect-MgGraphIfNeeded {
    $context = Get-MgContext
    if (-not $context) {
        Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All","Group.Read.All" -NoWelcome
    }
}

function Get-GraphCall {
    param(
        [Parameter(Mandatory)]
        $apiUri,
        [Parameter(Mandatory)]
        $method
    )
    return Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/$apiUri" -Method $method
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################
$profileId = ''
$groupId = ''

if ([string]::IsNullOrEmpty($profileId)) {
    Write-Error "profileId is empty. Please set a valid kiosk profile ID."
    return
}
if ([string]::IsNullOrEmpty($groupId)) {
    Write-Error "groupId is empty. Please set a valid AAD group ID."
    return
}

# Auth
Connect-MgGraphIfNeeded

try {
    $kioskProfile = Get-GraphCall -apiUri "deviceManagement/deviceConfigurations/$profileId" -method GET
    $request = @'
{
    "@odata.type": "#microsoft.graph.windowsKioskConfiguration",
    "kioskProfiles": []
}
'@ | ConvertFrom-Json
    $request.kioskProfiles += $kioskProfile.kioskProfiles

    $kioskProfileAssignments = @()
    ($groupMember = Get-GraphCall -apiUri "/groups/$groupId/members" -method GET).Value | ForEach-Object {
        if ($_.'@odata.type' -eq '#microsoft.graph.user') {
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

    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$profileId" -Method PATCH -Body ($request | ConvertTo-Json -Depth 7) -ContentType "application/json"
}
catch {
    Write-Error "Failed to sync kiosk assignment: $_"
    throw
}
