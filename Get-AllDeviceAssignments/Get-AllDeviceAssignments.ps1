<#
.SYNOPSIS
    Get all assignments from an Intune device
.DESCRIPTION
    Retrieves all assignments (group memberships, configuration profiles, and applications)
    for a specific Intune managed device. Uses Microsoft Graph API via Microsoft.Graph.Authentication.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

#Requires -Modules Microsoft.Graph.Authentication

Param([string]$User)

function Connect-MgGraphIfNeeded {
    $context = Get-MgContext
    if (-not $context) {
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All,Device.Read.All,DeviceManagementConfiguration.Read.All,DeviceManagementApps.Read.All" -NoWelcome
    }
}

function Get-GraphCall {
    param(
        [Parameter(Mandatory)]
        $apiUri,
        [Parameter(Mandatory)]
        $method
    )
    try {
        return Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/$apiUri" -Method $method
    } catch {
        Write-Error "Graph API call failed: $_"
        return $null
    }
}

function Get-Device {
    param(
        [Parameter(Mandatory)]
        $deviceName
    )
    $result = Get-GraphCall -method GET -apiUri  ("deviceManagement/managedDevices?"+'$filter' + "=startswith(deviceName,'$deviceName')")
    return $result.value[0]
}


function Get-GroupMembership {
    param(
        [Parameter(Mandatory)]
        $deviceId
    )
    $groups = @()
    $deviceId = (Get-GraphCall -method GET -apiUri ("/devices?" + '$filter' + "=deviceId%20eq%20%27$deviceId%27")).value[0].id

    $result = Get-GraphCall -method GET -apiUri ("devices/$deviceId/memberOf")
    $result.value | ForEach-Object {$groups += " - $($_.displayName) ($($_.id))"}

    $result = Get-GraphCall -method GET -apiUri ("devices/$deviceId/transitiveMemberOf")
    $result.value | ForEach-Object {$groups += " - $($_.displayName) ($($_.id))"}

    ($groups | Sort-Object | Get-Unique) | ForEach-Object {Write-Host $_}
}

function Get-ConfigProfiles {
    param(
        [Parameter(Mandatory)]
        $deviceId
    )
    $body = @'
    {
        "select": [
            "PolicyName"
        ],
        "filter": "((PolicyBaseTypeName eq 'Microsoft.Management.Services.Api.DeviceConfiguration') or (PolicyBaseTypeName eq 'DeviceManagementConfigurationPolicy') or (PolicyBaseTypeName eq 'DeviceConfigurationAdmxPolicy') or (PolicyBaseTypeName eq 'Microsoft.Management.Services.Api.DeviceManagementIntent')) and (IntuneDeviceId eq '
'@ + $deviceId + @'
')",
        "skip": 0,
        "top": 50,
        "orderBy": [
            "PolicyName"
        ]
    }
'@
    try {
        $result = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/getConfigurationPoliciesReportForDevice" -Method POST -Body $body -ContentType "application/json"
    } catch {
        Write-Error "Failed to retrieve configuration profiles: $_"
        return
    }
    $profiles = @()
    $result.Values | ForEach-Object {$profiles += " - $($_[0])"
    }
    ($profiles | Sort-Object | Get-Unique) | ForEach-Object {Write-Host $_}
}

function Get-Applications {
    param(
        [Parameter(Mandatory)]
        $deviceId
    )
    $result = Get-GraphCall -method GET -apiUri ("/users('00000000-0000-0000-0000-000000000000')/mobileAppIntentAndStates('$deviceId')")
    $result.mobileAppList | ForEach-Object {
        Write-Host " - $($_.displayName)"
    }

}

function Get-DeviceInfo {
    param(
        [Parameter(Mandatory)]
        $device
    )

    Write-Host "  Hostname:                 $($device.deviceName)"
    Write-Host "  Deviceid:                 $($device.id)"
    Write-Host "  Ownertype:                $($device.ownerType)"
    Write-Host "  Enrollmenttime:           $($device.enrolledDateTime)"
    Write-Host "  OS version:               $($device.osVersion)"
    Write-Host "  User:                     $($device.emailAddress)"
    Write-Host "  EnrollmentProfile:        $($device.enrollmentProfileName)"
}

#########################################################################################################
############################################ Start ######################################################
#########################################################################################################

#Auth
Connect-MgGraphIfNeeded

# Get an device id
$deviceId = ""
while(-not $deviceId)
{
    $deviceName = Read-Host "Enter the name of the device"
    $device = Get-Device -deviceName $deviceName
    if($device) { $deviceId = $device.id}
}


Write-Host -ForegroundColor Yellow "######################################"
Write-Host -ForegroundColor Yellow "#      Get Device Informations       #"
Write-Host -ForegroundColor Yellow "######################################"
Write-Host
Write-Host -ForegroundColor Yellow "---------------------------------"
Write-Host -ForegroundColor Yellow "|      Device information       |"
Write-Host -ForegroundColor Yellow "---------------------------------"
Get-DeviceInfo -device $device
Write-Host
Write-Host -ForegroundColor Yellow "---------------------------------"
Write-Host -ForegroundColor Yellow "|       Group memebership       |"
Write-Host -ForegroundColor Yellow "---------------------------------"
Get-GroupMembership -deviceId $($device.azureActiveDirectoryDeviceId)
Write-Host
Write-Host -ForegroundColor Yellow "---------------------------------"
Write-Host -ForegroundColor Yellow "|        Config profiles        |"
Write-Host -ForegroundColor Yellow "---------------------------------"
Get-ConfigProfiles -deviceId $deviceId
Write-Host
Write-Host -ForegroundColor Yellow "---------------------------------"
Write-Host -ForegroundColor Yellow "|          Applications         |"
Write-Host -ForegroundColor Yellow "---------------------------------"
Get-Applications -deviceId $deviceId
Write-Host

