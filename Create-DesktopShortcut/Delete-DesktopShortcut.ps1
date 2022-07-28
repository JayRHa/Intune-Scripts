<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Delete-DesktopShortcut
Description:
Remove the lnk file from the desktop
Release notes:
Version 1.0: Init
#> 

#Name of the shortcut
$shortcutName = "Intranet Shortcut" 
$iconPath = "C:\ProgramData\WebpageShortcut\"

Remove-Item -Path "$Env:Public\Desktop\$shortcutName.lnk"
Remove-Item -Path $iconPath