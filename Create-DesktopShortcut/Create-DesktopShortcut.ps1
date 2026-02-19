<#
.SYNOPSIS
    Create desktop shortcut for web page
.DESCRIPTION
    Intune Win32 app install script. Copies the .lnk shortcut file and icon to the public desktop.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

$shortcutName = "Intranet Shortcut"
$iconPath = "C:\ProgramData\WebpageShortcut\"

try {
    $ScriptPath = $PSScriptRoot
    New-Item -ItemType Directory -Path $iconPath -ErrorAction SilentlyContinue | Out-Null
    Copy-Item -Path "$ScriptPath\webPage.ico" -Destination $iconPath -Force -Recurse
    Copy-Item -Path "$ScriptPath\$shortcutName.lnk" -Destination "$Env:Public\Desktop" -Force
    exit 0
} catch {
    Write-Error "Failed to create shortcut: $_"
    exit 1
}
