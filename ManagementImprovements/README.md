# Management Improvements

Solutions and reports that surface common Intune housekeeping problems and make
day-to-day tenant administration easier. Every script connects via
`Connect-MgGraph`, paginates the response, exports a CSV (where applicable)
and exits with `0` (success) or `1` (error).

| Script | Purpose | Required Graph Scopes |
|---|---|---|
| [`Find-StaleDevices/`](Find-StaleDevices/Find-StaleDevices.ps1) | List managed devices that haven't synced for *N* days; optionally retire them. | `DeviceManagementManagedDevices.ReadWrite.All` |
| [`Find-DuplicateDevices/`](Find-DuplicateDevices/Find-DuplicateDevices.ps1) | Find duplicate device records by serial number, keep the most-recent sync, optionally delete the older record. | `DeviceManagementManagedDevices.Read.All` (+`PrivilegedOperations.All` when `-RemoveOld`) |
| [`Backup-IntuneConfiguration/`](Backup-IntuneConfiguration/Backup-IntuneConfiguration.ps1) | Export configuration profiles, compliance policies, scripts, apps, app config, Autopilot profiles and filters into a timestamped JSON tree — ready to commit to git. | `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`, `DeviceManagementServiceConfig.Read.All` |
| [`Find-EmptyAssignmentGroups/`](Find-EmptyAssignmentGroups/Find-EmptyAssignmentGroups.ps1) | Detect Entra ID groups used in Intune assignments that have zero members ("ghost" assignments). | `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`, `Group.Read.All` |
| [`Find-UnusedFilters/`](Find-UnusedFilters/Find-UnusedFilters.ps1) | Detect assignment filters that are not referenced by any assignment; optionally delete them. | `DeviceManagementConfiguration.ReadWrite.All`, `DeviceManagementApps.Read.All` |
| [`Get-BitLockerEscrowReport/`](Get-BitLockerEscrowReport/Get-BitLockerEscrowReport.ps1) | Cross-check managed Windows devices against escrowed BitLocker recovery keys; report devices missing a key. | `DeviceManagementManagedDevices.Read.All`, `BitLockerKey.ReadBasic.All`, `Device.Read.All` |
| [`Get-AppInstallSuccessRate/`](Get-AppInstallSuccessRate/Get-AppInstallSuccessRate.ps1) | Compute per-app install success rate from `installSummary`; highlight apps below a threshold. | `DeviceManagementApps.Read.All` |
| [`Find-UnassignedPlatformScripts/`](Find-UnassignedPlatformScripts/Find-UnassignedPlatformScripts.ps1) | Find Windows PowerShell scripts, macOS shell scripts and Proactive Remediations without assignments. | `DeviceManagementConfiguration.Read.All` |
| [`Test-IntuneHealth/`](Test-IntuneHealth/Test-IntuneHealth.ps1) | Quick tenant health summary: resource counts, compliance state, stale devices, APNS certificate expiry. | `DeviceManagementManagedDevices.Read.All`, `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`, `DeviceManagementServiceConfig.Read.All` |
| [`Get-PolicyConflictReport/`](Get-PolicyConflictReport/Get-PolicyConflictReport.ps1) | List device-configuration policies in `conflict` or `error` state, tenant-wide or for a single device. | `DeviceManagementManagedDevices.Read.All`, `DeviceManagementConfiguration.Read.All` |

## Common patterns

All scripts share the same idioms:

```powershell
function Connect-MgGraphIfNeeded {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "..." -NoWelcome
    }
}

function Get-AllPages {
    Param([Parameter(Mandatory)][string]$Uri)
    $items = [System.Collections.Generic.List[object]]::new()
    while ($Uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $Uri
        foreach ($v in $page.value) { $items.Add($v) }
        $Uri = $page.'@odata.nextLink'
    }
    return $items
}
```

- Pagination is always handled via `@odata.nextLink`.
- Destructive actions (retire devices, delete filters, delete duplicate
  records) are gated behind `SupportsShouldProcess` with `ConfirmImpact =
  'High'` so they prompt by default.
- All outputs are written as UTF-8 CSV for easy ingestion into Power BI, Excel,
  or follow-up automation.

## Running

```powershell
# Examples
.\Test-IntuneHealth\Test-IntuneHealth.ps1
.\Find-StaleDevices\Find-StaleDevices.ps1 -DaysStale 120
.\Backup-IntuneConfiguration\Backup-IntuneConfiguration.ps1 -IncludeAssignments
.\Find-EmptyAssignmentGroups\Find-EmptyAssignmentGroups.ps1
.\Get-BitLockerEscrowReport\Get-BitLockerEscrowReport.ps1
```
