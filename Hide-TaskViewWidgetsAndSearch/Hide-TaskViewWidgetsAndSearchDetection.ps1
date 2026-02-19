<#
.SYNOPSIS
    Detect if Task View, Widgets, or Search are visible
.DESCRIPTION
    Checks registry values to determine whether the Task View button, Widgets, or
    Search box are enabled in the taskbar. Exits with code 1 if any are active.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

function Test-RegistryValue {
    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Value
    )

    try {
        Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion"
$showTaskViewButton = "ShowTaskViewButton"
$showWidgets = "TaskbarDa"
$showSearch = "SearchboxTaskbarMode"

if (Test-RegistryValue -Path "$regPath\Explorer\Advanced" -Value $showTaskViewButton) {
    $taskViewValue = (Get-ItemProperty -Path "$regPath\Explorer\Advanced").$showTaskViewButton
    if ($taskViewValue -ne 0) {
        Write-Host "Show Task View Button is active"
        exit 1
    }
}

if (Test-RegistryValue -Path "$regPath\Explorer\Advanced" -Value $showWidgets) {
    $widgetsValue = (Get-ItemProperty -Path "$regPath\Explorer\Advanced").$showWidgets
    if ($widgetsValue -ne 0) {
        Write-Host "Show Widgets is active"
        exit 1
    }
}

if (Test-RegistryValue -Path "$regPath\Search" -Value $showSearch) {
    $searchValue = (Get-ItemProperty -Path "$regPath\Search").$showSearch
    if ($searchValue -ne 0) {
        Write-Host "Show Search Button is active"
        exit 1
    }
}

exit 0
