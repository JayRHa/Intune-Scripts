<#
.SYNOPSIS
    Compute the install success rate of every assigned Intune app.
.DESCRIPTION
    For each assigned mobileApp, fetches the installSummary and computes the
    success / failure / pending counts per scope (device + user). Apps below
    the configurable threshold are highlighted so admins can investigate the
    underlying packaging or detection-rule problems.
.PARAMETER WarnBelow
    Success-rate threshold (0-100) below which the app is highlighted in the
    console output. Default: 80.
.PARAMETER OutputPath
    CSV output path. Default: .\app-install-success.csv
.PARAMETER IncludeUnassigned
    Also include apps without assignments. Default: only assigned apps.
.EXAMPLE
    .\Get-AppInstallSuccessRate.ps1
.EXAMPLE
    .\Get-AppInstallSuccessRate.ps1 -WarnBelow 95 -OutputPath C:\temp\apps.csv
.NOTES
    Author : Jannik Reinhard
    Version: 1.0
#>

#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding()]
Param(
    [ValidateRange(0, 100)]
    [int]$WarnBelow = 80,
    [string]$OutputPath = ".\app-install-success.csv",
    [switch]$IncludeUnassigned
)

function Connect-MgGraphIfNeeded {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "DeviceManagementApps.Read.All" -NoWelcome
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
    Write-Host "Loading mobileApps..." -ForegroundColor Cyan
    $apps = Get-AllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$expand=assignments&`$select=id,displayName,publisher,assignments,'@odata.type'"
    Write-Host "Total apps: $($apps.Count)" -ForegroundColor Cyan

    if (-not $IncludeUnassigned) {
        $apps = $apps | Where-Object { $_.assignments.Count -gt 0 }
    }

    $rows = foreach ($app in $apps) {
        try {
            $s = Invoke-MgGraphRequest -Method GET `
                -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)/installSummary"
        } catch {
            Write-Verbose "InstallSummary not available for $($app.displayName)"
            continue
        }
        $devTotal  = [int]$s.installedDeviceCount + [int]$s.failedDeviceCount + [int]$s.notInstalledDeviceCount + [int]$s.notApplicableDeviceCount + [int]$s.pendingInstallDeviceCount
        $userTotal = [int]$s.installedUserCount + [int]$s.failedUserCount + [int]$s.notInstalledUserCount + [int]$s.notApplicableUserCount + [int]$s.pendingInstallUserCount

        $devSuccess  = if ($devTotal)  { [math]::Round((([int]$s.installedDeviceCount) / $devTotal)  * 100, 2) } else { $null }
        $userSuccess = if ($userTotal) { [math]::Round((([int]$s.installedUserCount)   / $userTotal) * 100, 2) } else { $null }

        [pscustomobject]@{
            appId                    = $app.id
            displayName              = $app.displayName
            publisher                = $app.publisher
            type                     = $app.'@odata.type'
            installedDeviceCount     = $s.installedDeviceCount
            failedDeviceCount        = $s.failedDeviceCount
            pendingInstallDeviceCount= $s.pendingInstallDeviceCount
            notInstalledDeviceCount  = $s.notInstalledDeviceCount
            notApplicableDeviceCount = $s.notApplicableDeviceCount
            installedUserCount       = $s.installedUserCount
            failedUserCount          = $s.failedUserCount
            deviceSuccessPercent     = $devSuccess
            userSuccessPercent       = $userSuccess
        }
    }

    $rows | Sort-Object deviceSuccessPercent |
        Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

    Write-Host "Report written to $OutputPath" -ForegroundColor Green

    $warn = $rows | Where-Object { $_.deviceSuccessPercent -ne $null -and $_.deviceSuccessPercent -lt $WarnBelow }
    if ($warn) {
        Write-Host "Apps below ${WarnBelow}% device install success:" -ForegroundColor Yellow
        $warn | Format-Table displayName, deviceSuccessPercent, failedDeviceCount, installedDeviceCount -AutoSize
    }

    exit 0
} catch {
    Write-Error "Get-AppInstallSuccessRate failed: $_"
    exit 1
}
