<#
.SYNOPSIS
    Report Windows devices that have no BitLocker recovery key escrowed to Entra ID.
.DESCRIPTION
    Joins the list of managed Windows devices with the BitLocker recoveryKeys
    resource in Microsoft Graph. Devices that have at least one key escrowed
    are reported as compliant; the rest are flagged in a CSV report so admins
    can chase down endpoints that are encrypted but lack a stored recovery key.
.PARAMETER OutputPath
    CSV output path. Default: .\bitlocker-escrow-report.csv
.PARAMETER IncludeCompliantDevices
    Also include compliant devices in the CSV (default: only non-compliant).
.EXAMPLE
    .\Get-BitLockerEscrowReport.ps1
.NOTES
    Author : Jannik Reinhard
    Version: 1.0
    Note   : Requires the BitLockerKey.ReadBasic.All scope.
#>

#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding()]
Param(
    [string]$OutputPath = ".\bitlocker-escrow-report.csv",
    [switch]$IncludeCompliantDevices
)

function Connect-MgGraphIfNeeded {
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes @(
            "DeviceManagementManagedDevices.Read.All",
            "BitLockerKey.ReadBasic.All",
            "Device.Read.All"
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

    Write-Host "Loading Windows managed devices..." -ForegroundColor Cyan
    $devices = Get-AllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id,deviceName,userPrincipalName,azureADDeviceId,model,osVersion,lastSyncDateTime,joinType"
    Write-Host "Windows devices: $($devices.Count)" -ForegroundColor Cyan

    Write-Host "Loading BitLocker recovery keys..." -ForegroundColor Cyan
    $keys = Get-AllPages -Uri "https://graph.microsoft.com/beta/informationProtection/bitlocker/recoveryKeys?`$select=id,deviceId,createdDateTime,volumeType"
    Write-Host "Recovery keys: $($keys.Count)" -ForegroundColor Cyan

    $byDevice = $keys | Group-Object deviceId -AsHashTable -AsString

    $report = foreach ($d in $devices) {
        $hasKey  = $byDevice -and $d.azureADDeviceId -and $byDevice.ContainsKey($d.azureADDeviceId)
        $keyList = if ($hasKey) { $byDevice[$d.azureADDeviceId] } else { @() }
        [pscustomobject]@{
            deviceName            = $d.deviceName
            userPrincipalName     = $d.userPrincipalName
            azureADDeviceId       = $d.azureADDeviceId
            joinType              = $d.joinType
            osVersion             = $d.osVersion
            lastSyncDateTime      = $d.lastSyncDateTime
            hasRecoveryKey        = [bool]$hasKey
            recoveryKeyCount      = $keyList.Count
            volumesProtected      = (($keyList | Select-Object -ExpandProperty volumeType -Unique) -join ',')
            mostRecentEscrow      = ($keyList | Sort-Object createdDateTime -Descending | Select-Object -First 1 -ExpandProperty createdDateTime)
        }
    }

    $output = if ($IncludeCompliantDevices) { $report } else { $report | Where-Object { -not $_.hasRecoveryKey } }

    $missing = ($report | Where-Object { -not $_.hasRecoveryKey }).Count
    Write-Host "Devices without escrowed recovery key: $missing" -ForegroundColor Yellow

    $output | Sort-Object hasRecoveryKey, deviceName |
        Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

    Write-Host "Report written to $OutputPath" -ForegroundColor Green
    exit 0
} catch {
    Write-Error "Get-BitLockerEscrowReport failed: $_"
    exit 1
}
