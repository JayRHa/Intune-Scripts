<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-ConnectedDevices
Description:
Get connected devices to a pc for a detection script
Release notes:
Version 1.0: Init
#> 

$deviceIds = @('')

foreach($device in Get-PnpDevice){
    if(($deviceIds | %{$device.DeviceID -like "$_*"}) -contains $true){
        Write-Host "Device found"
        Exit 1
    }
}

Write-Host "Device not found"
Exit 0
