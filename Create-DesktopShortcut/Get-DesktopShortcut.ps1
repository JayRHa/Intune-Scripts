<#
.SYNOPSIS
    Detect if desktop shortcut exists
.DESCRIPTION
    Intune Win32 app detection script. Checks if the shortcut file exists on the public desktop.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

$shortcutName = "Intranet Shortcut"

if (Test-Path -Path "$Env:Public\Desktop\$shortcutName.lnk") {
    Write-Host "Shortcut found"
    exit 0
} else {
    Write-Host "Shortcut not found"
    exit 1
}
