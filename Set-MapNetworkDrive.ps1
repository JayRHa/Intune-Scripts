<#
.SYNOPSIS
    Map a network drive via Intune
.DESCRIPTION
    Maps a persistent network drive using New-PSDrive. Deploy as an Intune script
    to map a file share for users.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

try {
    New-PSDrive -Name "K" -PSProvider FileSystem -Root "ADDRESSOFTHEFILESHARE" -Persist -ErrorAction Stop
    exit 0
} catch {
    Write-Error "Failed to map network drive: $_"
    exit 1
}
