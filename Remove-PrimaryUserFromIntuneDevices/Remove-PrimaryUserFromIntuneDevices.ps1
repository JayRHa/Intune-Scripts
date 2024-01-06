<#
Version: 2.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Remove-PrimaryUserFromIntuneDevices
Description:
Remove the rimary user fro all devices
Release notes:
Version 1.0: Init
#> 

######## Variables ########
$filter = "contains(operatingSystem,'Windows')"
# $filter = "contains(operatingSystem,'Windows') and contains(deviceName,'DESKTOP-')"
# $filter = "contains(operatingSystem,'Windows') and (deviceName eq 'DESKTOP-XXXXXXX' or deviceName eq 'DESKTOP-XXXXXXX')"

# Check if Microsoft Graph module is installed
$module = Get-Module -Name Microsoft.Graph -ListAvailable
if ($module -eq $null) {
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
    Import-Module -Name Microsoft.Graph
} else {
    Write-Host "Microsoft Graph module is already installed."
}

# Authentication
Connect-MgGraph

# Get all Windows devices
$devices = Get-MgDeviceManagementManagedDevice -all -Filter $filter # You can adapt this filter also to select a other device group

foreach ($device in $devices) {
    # Check if device has a primary user
    if ($device.userId -eq "") {
        Write-Host "No primary user found for device $($device.deviceName)"
        continue
    }
    Write-Host "Remove primary user $($device.userId) from device $($device.deviceName)"
    #Remove primary user from device
    Invoke-MgGraphRequest -Uri "deviceManagement/managedDevices/$($device.id)/users/$($device.userId)/`$ref" -Method Delete
}