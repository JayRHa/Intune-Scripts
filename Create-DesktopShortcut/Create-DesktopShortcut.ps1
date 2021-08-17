<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Create-DesktopShortcut
Description:
Copy the lnk file to the desktop
Release notes:
Version 1.0: Init
#> 

#Name of the shortcut
$shortcutName = "Intranet Shortcut" 

$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

Copy-Item -Path "$ScriptPath\$shortcutName.lnk" -Destination "$Env:Public\Desktop"