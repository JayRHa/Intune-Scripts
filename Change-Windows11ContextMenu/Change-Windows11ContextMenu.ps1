<#
.SYNOPSIS
    Restore Windows 10 context menu on Windows 11
.DESCRIPTION
    Creates a registry key to disable the Windows 11 modern context menu and restore
    the classic Windows 10 right-click context menu.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
#>

try {
    $null = New-Item -Path 'REGISTRY::HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' -Force -ErrorAction Stop
    exit 0
} catch {
    Write-Error "Failed to restore classic context menu: $_"
    exit 1
}
