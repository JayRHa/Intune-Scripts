<#
.SYNOPSIS
    Remove built-in Microsoft Teams client
.DESCRIPTION
    Removes the AppX package for the built-in Windows 11 Teams client.
    Use as an Intune Proactive Remediation script.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

try {
    $teamsPackage = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*MicrosoftTeams*" }
    if ($teamsPackage) {
        $teamsPackage | Remove-AppxPackage -AllUsers -ErrorAction Stop
        Write-Host "Microsoft Teams client removed"
    } else {
        Write-Host "Microsoft Teams client not found"
    }
    exit 0
} catch {
    Write-Error "Failed to remove Microsoft Teams: $_"
    exit 1
}
