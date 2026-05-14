<#
.SYNOPSIS
    Find Intune-managed devices that haven't synced for a given number of days.
.DESCRIPTION
    Queries Microsoft Graph for all managed devices, filters by lastSyncDateTime
    older than the supplied threshold and exports the result to CSV. Optionally
    triggers a remote-wipe of stale, retired-eligible devices when -Action Retire
    is specified (requires confirmation).
.PARAMETER DaysStale
    Number of days since lastSyncDateTime that marks a device as stale. Default: 90.
.PARAMETER OutputPath
    CSV output path. Default: .\stale-devices.csv
.PARAMETER Action
    Report (default) or Retire. Retire performs Invoke-MgRetireManagedDevice on
    each stale device after a confirmation prompt.
.EXAMPLE
    .\Find-StaleDevices.ps1 -DaysStale 60
.EXAMPLE
    .\Find-StaleDevices.ps1 -DaysStale 180 -Action Retire
.NOTES
    Author : Jannik Reinhard
    Version: 1.0
#>

#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
Param(
    [ValidateRange(1, 3650)]
    [int]$DaysStale = 90,

    [string]$OutputPath = ".\stale-devices.csv",

    [ValidateSet('Report', 'Retire')]
    [string]$Action = 'Report'
)

function Connect-MgGraphIfNeeded {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All" -NoWelcome
    }
}

function Get-AllManagedDevices {
    $devices = [System.Collections.Generic.List[object]]::new()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,deviceName,userPrincipalName,operatingSystem,osVersion,complianceState,managementAgent,lastSyncDateTime,serialNumber,model,manufacturer"
    while ($uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $uri
        foreach ($d in $page.value) { $devices.Add($d) }
        $uri = $page.'@odata.nextLink'
    }
    return $devices
}

try {
    Connect-MgGraphIfNeeded
    $cutoff = (Get-Date).ToUniversalTime().AddDays(-$DaysStale)
    Write-Host "Cutoff date (UTC): $cutoff" -ForegroundColor Cyan

    $all = Get-AllManagedDevices
    Write-Host "Retrieved $($all.Count) managed devices." -ForegroundColor Cyan

    $stale = $all | Where-Object {
        $_.lastSyncDateTime -and ([datetime]$_.lastSyncDateTime) -lt $cutoff
    } | Sort-Object lastSyncDateTime

    Write-Host "Stale devices: $($stale.Count)" -ForegroundColor Yellow

    $stale | Select-Object deviceName, userPrincipalName, operatingSystem, osVersion,
        complianceState, managementAgent, lastSyncDateTime, serialNumber, model, id |
        Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

    Write-Host "Report written to $OutputPath" -ForegroundColor Green

    if ($Action -eq 'Retire' -and $stale.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess("$($stale.Count) stale devices", 'Retire')) {
            foreach ($d in $stale) {
                try {
                    Invoke-MgGraphRequest -Method POST `
                        -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($d.id)/retire"
                    Write-Host "Retired: $($d.deviceName)" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to retire $($d.deviceName): $_"
                }
            }
        }
    }

    exit 0
} catch {
    Write-Error "Find-StaleDevices failed: $_"
    exit 1
}
