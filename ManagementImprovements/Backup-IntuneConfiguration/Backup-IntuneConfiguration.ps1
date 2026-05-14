<#
.SYNOPSIS
    Export Intune configuration objects to JSON for backup / source control.
.DESCRIPTION
    Exports configuration profiles (classic + settings catalog), compliance
    policies, platform scripts, proactive remediations, app protection policies,
    Autopilot deployment profiles, assignment filters and mobileApps as JSON
    files into a dated folder. Each object is written separately so the output
    can be committed to git and diffed across runs.
.PARAMETER OutputPath
    Root output folder. A timestamped subfolder is created inside. Default: .\backup
.PARAMETER IncludeAssignments
    If set, also exports the assignments collection for each object.
.EXAMPLE
    .\Backup-IntuneConfiguration.ps1 -IncludeAssignments
.NOTES
    Author : Jannik Reinhard
    Version: 1.0
#>

#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding()]
Param(
    [string]$OutputPath = ".\backup",
    [switch]$IncludeAssignments
)

$endpoints = @(
    @{ Name = 'deviceConfigurations';                Uri = 'deviceManagement/deviceConfigurations' }
    @{ Name = 'configurationPolicies';               Uri = 'deviceManagement/configurationPolicies' }
    @{ Name = 'deviceCompliancePolicies';            Uri = 'deviceManagement/deviceCompliancePolicies' }
    @{ Name = 'deviceManagementScripts';             Uri = 'deviceManagement/deviceManagementScripts' }
    @{ Name = 'deviceShellScripts';                  Uri = 'deviceManagement/deviceShellScripts' }
    @{ Name = 'deviceHealthScripts';                 Uri = 'deviceManagement/deviceHealthScripts' }
    @{ Name = 'windowsAutopilotDeploymentProfiles';  Uri = 'deviceManagement/windowsAutopilotDeploymentProfiles' }
    @{ Name = 'assignmentFilters';                   Uri = 'deviceManagement/assignmentFilters' }
    @{ Name = 'mobileApps';                          Uri = 'deviceAppManagement/mobileApps' }
    @{ Name = 'managedAppPolicies';                  Uri = 'deviceAppManagement/managedAppPolicies' }
    @{ Name = 'mobileAppConfigurations';             Uri = 'deviceAppManagement/mobileAppConfigurations' }
)

function Connect-MgGraphIfNeeded {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes @(
            "DeviceManagementConfiguration.Read.All",
            "DeviceManagementApps.Read.All",
            "DeviceManagementServiceConfig.Read.All"
        ) -NoWelcome
    }
}

function Get-AllPages {
    Param([Parameter(Mandatory)][string]$RelativeUri)
    $items = [System.Collections.Generic.List[object]]::new()
    $uri = "https://graph.microsoft.com/beta/$RelativeUri"
    while ($uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $uri
        foreach ($v in $page.value) { $items.Add($v) }
        $uri = $page.'@odata.nextLink'
    }
    return $items
}

function Save-Object {
    Param(
        [Parameter(Mandatory)] [object]$Object,
        [Parameter(Mandatory)] [string]$Folder
    )
    $name = if ($Object.displayName) { $Object.displayName } elseif ($Object.name) { $Object.name } else { $Object.id }
    $safe = ($name -replace '[\\/:*?"<>|]', '_') + '_' + $Object.id + '.json'
    $path = Join-Path $Folder $safe
    ($Object | ConvertTo-Json -Depth 25) | Out-File -FilePath $path -Encoding UTF8
}

try {
    Connect-MgGraphIfNeeded
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $root  = Join-Path -Path $OutputPath -ChildPath $stamp
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    foreach ($e in $endpoints) {
        Write-Host "Exporting $($e.Name)..." -ForegroundColor Cyan
        $folder = Join-Path $root $e.Name
        New-Item -ItemType Directory -Path $folder -Force | Out-Null

        $items = Get-AllPages -RelativeUri $e.Uri
        Write-Host "  $($items.Count) items"
        foreach ($item in $items) {
            if ($IncludeAssignments) {
                try {
                    $a = Invoke-MgGraphRequest -Method GET `
                        -Uri "https://graph.microsoft.com/beta/$($e.Uri)/$($item.id)/assignments"
                    $item | Add-Member -NotePropertyName '_assignments' -NotePropertyValue $a.value -Force
                } catch {
                    Write-Verbose "No assignments for $($item.id): $_"
                }
            }
            Save-Object -Object $item -Folder $folder
        }
    }

    Write-Host "Backup completed: $root" -ForegroundColor Green
    exit 0
} catch {
    Write-Error "Backup-IntuneConfiguration failed: $_"
    exit 1
}
