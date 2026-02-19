<#
.SYNOPSIS
    Get all failed Intune assignments as CSV
.DESCRIPTION
    Retrieves all failed configuration profile and app assignments in the tenant
    and exports them as CSV files. Uses Microsoft Graph API via Microsoft.Graph.Authentication.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

#Requires -Modules Microsoft.Graph.Authentication

function Connect-MgGraphIfNeeded {
    $context = Get-MgContext
    if (-not $context) {
        Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All,DeviceManagementApps.Read.All" -NoWelcome
    }
}

function Get-GraphCall {
    param(
        [Parameter(Mandatory)]
        $url
    )
    try {
        return Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/$url" -Method GET
    } catch {
        Write-Error "Graph API call failed: $_"
        return $null
    }
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
    return $result | Select-Object deviceName, userPrincipalName, installState, lastSyncDateTime | Where-Object {($_.installState -ne 'installed')}
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################
Connect-MgGraphIfNeeded

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
