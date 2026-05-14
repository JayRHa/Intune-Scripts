<#
.SYNOPSIS
    Find Entra ID groups used in Intune assignments that have zero members.
.DESCRIPTION
    Empty assignment groups are a common source of "ghost" assignments that look
    targeted but never reach a device. This script enumerates every group ID
    referenced by an Intune assignment (configuration profiles, compliance
    policies, scripts, apps, app config, autopilot profiles, filters) and
    reports those whose membership count is zero.
.PARAMETER OutputPath
    CSV output path. Default: .\empty-assignment-groups.csv
.EXAMPLE
    .\Find-EmptyAssignmentGroups.ps1
.NOTES
    Author : Jannik Reinhard
    Version: 1.0
#>

#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding()]
Param(
    [string]$OutputPath = ".\empty-assignment-groups.csv"
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
    'deviceAppManagement/managedAppPolicies',
    'deviceAppManagement/mobileAppConfigurations'
)

function Connect-MgGraphIfNeeded {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes @(
            "DeviceManagementConfiguration.Read.All",
            "DeviceManagementApps.Read.All",
            "Group.Read.All"
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
    $groupIds = [System.Collections.Generic.HashSet[string]]::new()
    $usage    = @{}

    foreach ($source in $assignmentSources) {
        Write-Host "Collecting assignments from $source ..." -ForegroundColor Cyan
        try {
            $items = Get-AllPages -Uri "https://graph.microsoft.com/beta/$source?`$expand=assignments"
        } catch {
            Write-Warning "Skipping $source -> $_"
            continue
        }
        foreach ($item in $items) {
            foreach ($a in @($item.assignments)) {
                $targetType = $a.target.'@odata.type'
                if ($targetType -eq '#microsoft.graph.groupAssignmentTarget' -or
                    $targetType -eq '#microsoft.graph.exclusionGroupAssignmentTarget') {
                    $gid = $a.target.groupId
                    [void]$groupIds.Add($gid)
                    if (-not $usage.ContainsKey($gid)) { $usage[$gid] = [System.Collections.Generic.List[string]]::new() }
                    $name = if ($item.displayName) { $item.displayName } else { $item.name }
                    $usage[$gid].Add("$source/$name")
                }
            }
        }
    }

    Write-Host "Unique groups referenced: $($groupIds.Count)" -ForegroundColor Cyan
    $empty = [System.Collections.Generic.List[object]]::new()

    foreach ($gid in $groupIds) {
        try {
            $count = Invoke-MgGraphRequest -Method GET `
                -Uri "https://graph.microsoft.com/beta/groups/$gid/members/`$count" `
                -Headers @{ ConsistencyLevel = 'eventual' }
            if ([int]$count -eq 0) {
                $g = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/groups/$gid"
                $empty.Add([pscustomobject]@{
                    groupId    = $gid
                    groupName  = $g.displayName
                    usageCount = $usage[$gid].Count
                    usedBy     = ($usage[$gid] -join '; ')
                })
            }
        } catch {
            Write-Verbose "Group $gid lookup failed: $_"
        }
    }

    Write-Host "Empty assignment groups: $($empty.Count)" -ForegroundColor Yellow
    $empty | Sort-Object usageCount -Descending |
        Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "Report written to $OutputPath" -ForegroundColor Green
    exit 0
} catch {
    Write-Error "Find-EmptyAssignmentGroups failed: $_"
    exit 1
}
