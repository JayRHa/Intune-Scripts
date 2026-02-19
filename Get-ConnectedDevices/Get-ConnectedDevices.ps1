<#
.SYNOPSIS
    Detect connected devices by device ID prefix
.DESCRIPTION
    Checks if any PnP devices matching the specified device ID prefixes are connected
    to the PC. Intended for use as an Intune detection script.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

$deviceIds = @('')

if ($deviceIds.Count -eq 0 -or ($deviceIds.Count -eq 1 -and $deviceIds[0] -eq '')) {
    Write-Error "Please configure deviceIds array with valid device ID prefixes"
    Exit 1
}

foreach($device in Get-PnpDevice){
    if(($deviceIds | ForEach-Object {$device.DeviceID -like "$_*"}) -contains $true){
        Write-Host "Device found"
        Exit 1
    }
}

Write-Host "Device not found"
Exit 0
