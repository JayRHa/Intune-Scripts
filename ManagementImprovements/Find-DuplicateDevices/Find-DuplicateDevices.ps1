<#
.SYNOPSIS
    Find duplicate Intune-managed device records.
.DESCRIPTION
    Detects devices that share the same serial number (typical for re-enrolled or
    re-imaged endpoints). For each duplicate group, keeps the most-recently
    synced record and exports the older duplicates to CSV. Optionally removes
    the older duplicates from Intune.
.PARAMETER OutputPath
    CSV output path. Default: .\duplicate-devices.csv
.PARAMETER RemoveOld
    When set, deletes the older duplicate records via Graph. Requires
    DeviceManagementManagedDevices.PrivilegedOperations.All scope.
.EXAMPLE
    .\Find-DuplicateDevices.ps1
.EXAMPLE
    .\Find-DuplicateDevices.ps1 -RemoveOld
.NOTES
    Author : Jannik Reinhard
    Version: 1.0
    Note   : Devices with empty / null serial numbers are excluded so VMs that
             share the literal "0" or "SystemSerialNumber" do not match.
#>

#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
Param(
    [string]$OutputPath = ".\duplicate-devices.csv",
    [switch]$RemoveOld
)

function Connect-MgGraphIfNeeded {
    if (-not (Get-MgContext)) {
        $scope = if ($RemoveOld) {
            "DeviceManagementManagedDevices.PrivilegedOperations.All"
        } else {
            "DeviceManagementManagedDevices.Read.All"
        }
        Connect-MgGraph -Scopes $scope -NoWelcome
    }
}

function Get-AllManagedDevices {
    $devices = [System.Collections.Generic.List[object]]::new()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=id,deviceName,userPrincipalName,serialNumber,model,manufacturer,operatingSystem,lastSyncDateTime,enrolledDateTime"
    while ($uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $uri
        foreach ($d in $page.value) { $devices.Add($d) }
        $uri = $page.'@odata.nextLink'
    }
    return $devices
}

$invalidSerials = @('', '0', 'Default string', 'SystemSerialNumber', 'To be filled by O.E.M.', 'None')

try {
    Connect-MgGraphIfNeeded
    $all = Get-AllManagedDevices
    Write-Host "Retrieved $($all.Count) managed devices." -ForegroundColor Cyan

    $usable = $all | Where-Object {
        $_.serialNumber -and ($invalidSerials -notcontains $_.serialNumber.Trim())
    }

    $groups = $usable | Group-Object serialNumber | Where-Object { $_.Count -gt 1 }
    Write-Host "Duplicate serial-number groups: $($groups.Count)" -ForegroundColor Yellow

    $toRemove = [System.Collections.Generic.List[object]]::new()
    foreach ($g in $groups) {
        $sorted = $g.Group | Sort-Object { [datetime]$_.lastSyncDateTime } -Descending
        $keep = $sorted | Select-Object -First 1
        $duplicates = $sorted | Select-Object -Skip 1
        foreach ($d in $duplicates) {
            $toRemove.Add([pscustomobject]@{
                serialNumber       = $g.Name
                duplicateName      = $d.deviceName
                duplicateId        = $d.id
                duplicateLastSync  = $d.lastSyncDateTime
                duplicateUpn       = $d.userPrincipalName
                duplicateOs        = $d.operatingSystem
                keepName           = $keep.deviceName
                keepId             = $keep.id
                keepLastSync       = $keep.lastSyncDateTime
            })
        }
    }

    $toRemove | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "Older duplicate records: $($toRemove.Count) -> $OutputPath" -ForegroundColor Green

    if ($RemoveOld -and $toRemove.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess("$($toRemove.Count) duplicate device records", 'Delete')) {
            foreach ($r in $toRemove) {
                try {
                    Invoke-MgGraphRequest -Method DELETE `
                        -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($r.duplicateId)"
                    Write-Host "Deleted: $($r.duplicateName)" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to delete $($r.duplicateName): $_"
                }
            }
        }
    }
    exit 0
} catch {
    Write-Error "Find-DuplicateDevices failed: $_"
    exit 1
}
