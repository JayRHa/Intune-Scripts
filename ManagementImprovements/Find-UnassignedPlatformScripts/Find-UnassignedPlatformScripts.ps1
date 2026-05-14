<#
.SYNOPSIS
    Find platform / shell / proactive-remediation scripts without assignments.
.DESCRIPTION
    Scans deviceManagementScripts (Windows), deviceShellScripts (macOS) and
    deviceHealthScripts (Proactive Remediations) and reports any items with no
    assignments. Helpful for catching "draft" scripts that were never rolled
    out.
.PARAMETER OutputPath
    CSV output path. Default: .\unassigned-scripts.csv
.EXAMPLE
    .\Find-UnassignedPlatformScripts.ps1
.NOTES
    Author : Jannik Reinhard
    Version: 1.0
#>

#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding()]
Param(
    [string]$OutputPath = ".\unassigned-scripts.csv"
)

$endpoints = @(
    @{ Type = 'Windows-PowerShell'; Uri = 'deviceManagement/deviceManagementScripts' }
    @{ Type = 'macOS-Shell';        Uri = 'deviceManagement/deviceShellScripts' }
    @{ Type = 'Proactive-Remediation'; Uri = 'deviceManagement/deviceHealthScripts' }
)

function Connect-MgGraphIfNeeded {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All" -NoWelcome
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
    $unassigned = [System.Collections.Generic.List[object]]::new()

    foreach ($e in $endpoints) {
        Write-Host "Scanning $($e.Type) ($($e.Uri))..." -ForegroundColor Cyan
        $items = Get-AllPages -Uri "https://graph.microsoft.com/beta/$($e.Uri)?`$expand=assignments"
        Write-Host "  $($items.Count) items"
        foreach ($i in $items) {
            if (-not $i.assignments -or $i.assignments.Count -eq 0) {
                $unassigned.Add([pscustomobject]@{
                    type                 = $e.Type
                    id                   = $i.id
                    displayName          = $i.displayName
                    publisher            = $i.publisher
                    createdDateTime      = $i.createdDateTime
                    lastModifiedDateTime = $i.lastModifiedDateTime
                })
            }
        }
    }

    Write-Host "Unassigned scripts: $($unassigned.Count)" -ForegroundColor Yellow
    $unassigned | Sort-Object type, lastModifiedDateTime |
        Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "Report written to $OutputPath" -ForegroundColor Green
    exit 0
} catch {
    Write-Error "Find-UnassignedPlatformScripts failed: $_"
    exit 1
}
