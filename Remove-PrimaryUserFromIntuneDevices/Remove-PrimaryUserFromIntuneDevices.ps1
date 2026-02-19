<#
.SYNOPSIS
    Remove the primary user from all Intune managed Windows devices.
.DESCRIPTION
    Connects to Microsoft Graph, retrieves Windows devices matching a filter,
    and removes the primary user association via the beta API endpoint.
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 2.1
    Release: v1.0 - Init
             v2.0 - Rewrite with Connect-MgGraph
             v2.1 - Improved null/empty check, conditional module install, try/catch
#>

######## Variables ########
$filter = "contains(operatingSystem,'Windows')"
# $filter = "contains(operatingSystem,'Windows') and contains(deviceName,'DESKTOP-')"
# $filter = "contains(operatingSystem,'Windows') and (deviceName eq 'DESKTOP-XXXXXXX' or deviceName eq 'DESKTOP-XXXXXXX')"

# Check if Microsoft Graph module is installed
$module = Get-Module -Name Microsoft.Graph -ListAvailable
if ($null -eq $module) {
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
    Import-Module -Name Microsoft.Graph
} else {
    Write-Host "Microsoft Graph module is already installed."
}

# Authentication
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All"

# Get all Windows devices
$devices = Get-MgDeviceManagementManagedDevice -All -Filter $filter # You can adapt this filter also to select a other device group

foreach ($device in $devices) {
    # Check if device has a primary user
    if ([string]::IsNullOrEmpty($device.userId)) {
        Write-Host "No primary user found for device $($device.deviceName)"
        continue
    }
    Write-Host "Remove primary user $($device.userId) from device $($device.deviceName)"
    # Remove primary user from device
    try {
        Invoke-MgGraphRequest -Uri "beta/deviceManagement/managedDevices('$($device.id)')/users/`$ref" -Method Delete
    }
    catch {
        Write-Warning "Failed to remove primary user from device $($device.deviceName): $_"
    }
}
