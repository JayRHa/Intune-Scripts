<#
.SYNOPSIS
    Find Intune assignment filters that are not referenced by any assignment.
.DESCRIPTION
    Lists all assignment filters in the tenant and cross-checks them against
    every assignment across configuration profiles, compliance policies,
    scripts, autopilot profiles and mobile apps. Filters that appear in zero
    assignments are reported.
.PARAMETER OutputPath
    CSV output path. Default: .\unused-filters.csv
.PARAMETER Delete
    If set, deletes the unused filters after a confirmation prompt.
.EXAMPLE
    .\Find-UnusedFilters.ps1
.NOTES
    Author : Jannik Reinhard
    Version: 1.0
#>

#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
Param(
    [string]$OutputPath = ".\unused-filters.csv",
    [switch]$Delete
)

$assignmentSources = @(
    'deviceManagement/deviceConfigurations',
    'deviceManagement/configurationPolicies',
    'deviceManagement/deviceCompliancePolicies',
    'deviceManagement/deviceManagementScripts',
    'deviceManagement/deviceShellScripts',
    'deviceManagement/deviceHealthScripts',
    'deviceManagement/windowsAutopilotDeploymentProfiles',
    'deviceAppManagement/mobileApps',
    'deviceAppManagement/mobileAppConfigurations'
)

function Connect-MgGraphIfNeeded {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes @(
            "DeviceManagementConfiguration.ReadWrite.All",
            "DeviceManagementApps.Read.All"
        ) -NoWelcome
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

try {
    Connect-MgGraphIfNeeded

    $filters = Get-AllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters"
    Write-Host "Filters in tenant: $($filters.Count)" -ForegroundColor Cyan

    $usedIds = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($source in $assignmentSources) {
        Write-Host "Scanning $source ..." -ForegroundColor Cyan
        try {
            $items = Get-AllPages -Uri "https://graph.microsoft.com/beta/$source?`$expand=assignments"
        } catch {
            Write-Warning "Skipping $source -> $_"
            continue
        }
        foreach ($item in $items) {
            foreach ($a in @($item.assignments)) {
                if ($a.target.deviceAndAppManagementAssignmentFilterId) {
                    [void]$usedIds.Add($a.target.deviceAndAppManagementAssignmentFilterId)
                }
            }
        }
    }

    $unused = $filters | Where-Object { -not $usedIds.Contains($_.id) }
    Write-Host "Unused filters: $($unused.Count)" -ForegroundColor Yellow

    $unused | Select-Object id, displayName, platform, rule, createdDateTime, lastModifiedDateTime |
        Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "Report written to $OutputPath" -ForegroundColor Green

    if ($Delete -and $unused.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess("$($unused.Count) unused filters", 'Delete')) {
            foreach ($f in $unused) {
                try {
                    Invoke-MgGraphRequest -Method DELETE `
                        -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/$($f.id)"
                    Write-Host "Deleted: $($f.displayName)" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to delete $($f.displayName): $_"
                }
            }
        }
    }
    exit 0
} catch {
    Write-Error "Find-UnusedFilters failed: $_"
    exit 1
}
