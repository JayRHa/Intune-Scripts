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
$iconPath = "C:\ProgramData\WebpageShortcut\"

$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
md $iconPath -ErrorAction SilentlyContinue
Copy-Item .\webPage.ico $iconPath -force -Recurse 

Copy-Item -Path "$ScriptPath\$shortcutName.lnk" -Destination "$Env:Public\Desktop"