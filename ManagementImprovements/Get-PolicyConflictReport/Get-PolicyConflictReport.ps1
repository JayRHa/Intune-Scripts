<#
.SYNOPSIS
    Report all device-configuration policies in a conflict state.
.DESCRIPTION
    Pulls the per-device, per-policy reporting status via Graph and surfaces
    every entry whose state is "conflict" or "error". Optionally narrows the
    report to a single device.
.PARAMETER DeviceName
    Limit the report to a single managed device by display name (optional).
.PARAMETER OutputPath
    CSV output path. Default: .\policy-conflicts.csv
.EXAMPLE
    .\Get-PolicyConflictReport.ps1
.EXAMPLE
    .\Get-PolicyConflictReport.ps1 -DeviceName "DESKTOP-AB1234"
.NOTES
    Author : Jannik Reinhard
    Version: 1.0
#>

#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding()]
Param(
    [string]$DeviceName,
    [string]$OutputPath = ".\policy-conflicts.csv"
)

function Connect-MgGraphIfNeeded {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes @(
            "DeviceManagementManagedDevices.Read.All",
            "DeviceManagementConfiguration.Read.All"
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

    $filter = if ($DeviceName) {
        "?`$filter=deviceName eq '$($DeviceName.Replace("'","''"))'&`$select=id,deviceName,userPrincipalName"
    } else {
        "?`$select=id,deviceName,userPrincipalName"
    }
    $devices = Get-AllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices$filter"
    Write-Host "Devices in scope: $($devices.Count)" -ForegroundColor Cyan

    $conflicts = [System.Collections.Generic.List[object]]::new()

    foreach ($d in $devices) {
        try {
            $states = Get-AllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($d.id)/deviceConfigurationStates"
        } catch {
            Write-Verbose "deviceConfigurationStates failed for $($d.deviceName): $_"
            continue
        }
        foreach ($s in $states) {
            if ($s.state -in @('conflict', 'error')) {
                $conflicts.Add([pscustomobject]@{
                    deviceName        = $d.deviceName
                    userPrincipalName = $d.userPrincipalName
                    policyName        = $s.displayName
                    state             = $s.state
                    settingCount      = $s.settingCount
                    platformType      = $s.platformType
                    version           = $s.version
                })
            }
        }
    }

    Write-Host "Conflict / error entries: $($conflicts.Count)" -ForegroundColor Yellow
    $conflicts | Sort-Object deviceName, policyName |
        Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "Report written to $OutputPath" -ForegroundColor Green
    exit 0
} catch {
    Write-Error "Get-PolicyConflictReport failed: $_"
    exit 1
}
