<#
.SYNOPSIS
    Remove desktop shortcut and icon files
.DESCRIPTION
    Intune Win32 app uninstall script. Removes the shortcut from the public desktop and cleans up icon files.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

$shortcutName = "Intranet Shortcut"
$iconPath = "C:\ProgramData\WebpageShortcut\"

try {
    if (Test-Path -Path "$Env:Public\Desktop\$shortcutName.lnk") {
        Remove-Item -Path "$Env:Public\Desktop\$shortcutName.lnk" -Force
    }
    if (Test-Path -Path $iconPath) {
        Remove-Item -Path $iconPath -Recurse -Force
    }
    exit 0
} catch {
    Write-Error "Failed to remove shortcut: $_"
    exit 1
}
