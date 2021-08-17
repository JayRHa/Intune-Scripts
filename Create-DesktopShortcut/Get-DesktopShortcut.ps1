<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-DesktopShortcut
Description:
Check if the shortcut exist
Release notes:
Version 1.0: Init
#> 

#Name of the shortcut
$shortcutName = "Intranet Shortcut"  

if (Test-Path -Path "$Env:Public\Desktop\$shortcutName.lnk"){
    Write-Output "0"
}