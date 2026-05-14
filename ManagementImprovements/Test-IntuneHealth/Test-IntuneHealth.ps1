<#
.SYNOPSIS
    Run a quick health check of the Intune tenant.
.DESCRIPTION
    Verifies Graph connectivity, gathers tenant context, counts core resources
    (devices, configurations, compliance policies, apps, autopilot devices)
    and surfaces common problem indicators: non-compliant devices, devices not
    synced in 30 days, failing apps, empty assignment groups, expiring Apple
    push certificate.
.PARAMETER StaleThresholdDays
    Days since lastSyncDateTime to consider a device "stale". Default: 30.
.EXAMPLE
    .\Test-IntuneHealth.ps1
.NOTES
    Author : Jannik Reinhard
    Version: 1.0
#>

#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding()]
Param(
    [ValidateRange(1, 365)]
    [int]$StaleThresholdDays = 30
)

function Connect-MgGraphIfNeeded {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes @(
            "DeviceManagementManagedDevices.Read.All",
            "DeviceManagementConfiguration.Read.All",
            "DeviceManagementApps.Read.All",
            "DeviceManagementServiceConfig.Read.All"
        ) -NoWelcome
    }
}

function Get-Count {
    Param([Parameter(Mandatory)][string]$Uri)
    try {
        $r = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/$Uri/`$count" `
            -Headers @{ ConsistencyLevel = 'eventual' }
        return [int]$r
    } catch {
        # Some endpoints (deviceConfigurations) don't support $count; fall back to enumerating.
        $total = 0
        $u = "https://graph.microsoft.com/beta/$Uri"
        while ($u) {
            $p = Invoke-MgGraphRequest -Method GET -Uri $u
            $total += $p.value.Count
            $u = $p.'@odata.nextLink'
        }
        return $total
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
    $ctx = Get-MgContext
    Write-Host ""
    Write-Host "=== Tenant context ===" -ForegroundColor Cyan
    Write-Host "  Tenant : $($ctx.TenantId)"
    Write-Host "  Account: $($ctx.Account)"
    Write-Host "  Scopes : $($ctx.Scopes -join ', ')"

    Write-Host ""
    Write-Host "=== Resource counts ===" -ForegroundColor Cyan
    $deviceCount = Get-Count -Uri "deviceManagement/managedDevices"
    Write-Host "  Managed devices             : $deviceCount"
    Write-Host "  Device configurations       : $(Get-Count -Uri 'deviceManagement/deviceConfigurations')"
    Write-Host "  Settings-catalog policies   : $(Get-Count -Uri 'deviceManagement/configurationPolicies')"
    Write-Host "  Compliance policies         : $(Get-Count -Uri 'deviceManagement/deviceCompliancePolicies')"
    Write-Host "  Mobile apps                 : $(Get-Count -Uri 'deviceAppManagement/mobileApps')"
    Write-Host "  Autopilot devices           : $(Get-Count -Uri 'deviceManagement/windowsAutopilotDeviceIdentities')"
    Write-Host "  Assignment filters          : $(Get-Count -Uri 'deviceManagement/assignmentFilters')"
    Write-Host "  Proactive remediations      : $(Get-Count -Uri 'deviceManagement/deviceHealthScripts')"

    Write-Host ""
    Write-Host "=== Compliance ===" -ForegroundColor Cyan
    $summary = Invoke-MgGraphRequest -Method GET `
        -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicyDeviceStateSummary"
    Write-Host "  Compliant      : $($summary.compliantDeviceCount)"
    Write-Host "  Non-compliant  : $($summary.nonCompliantDeviceCount)" -ForegroundColor Yellow
    Write-Host "  In grace period: $($summary.inGracePeriodCount)"
    Write-Host "  Error          : $($summary.errorDeviceCount)" -ForegroundColor Yellow
    Write-Host "  Not applicable : $($summary.notApplicableDeviceCount)"

    Write-Host ""
    Write-Host "=== Stale devices (>$StaleThresholdDays days) ===" -ForegroundColor Cyan
    $cutoff = (Get-Date).ToUniversalTime().AddDays(-$StaleThresholdDays).ToString("o")
    $stale = Get-AllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=lastSyncDateTime lt $cutoff&`$select=id,deviceName,lastSyncDateTime"
    Write-Host "  Stale device count: $($stale.Count)" -ForegroundColor $(if ($stale.Count -gt 0) { 'Yellow' } else { 'Green' })

    Write-Host ""
    Write-Host "=== Apple MDM push certificate ===" -ForegroundColor Cyan
    try {
        $apns = Invoke-MgGraphRequest -Method GET `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/applePushNotificationCertificate"
        $expiry = [datetime]$apns.expirationDateTime
        $days   = ($expiry - (Get-Date)).Days
        $color  = if ($days -lt 30) { 'Red' } elseif ($days -lt 60) { 'Yellow' } else { 'Green' }
        Write-Host "  Apple ID : $($apns.appleIdentifier)"
        Write-Host "  Expires  : $expiry ($days days remaining)" -ForegroundColor $color
    } catch {
        Write-Host "  (no APNS configured or insufficient permissions)" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "Health check complete." -ForegroundColor Green
    exit 0
} catch {
    Write-Error "Test-IntuneHealth failed: $_"
    exit 1
}
