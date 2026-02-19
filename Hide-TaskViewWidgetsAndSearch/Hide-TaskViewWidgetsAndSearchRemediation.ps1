<#
.SYNOPSIS
    Hide Task View, Widgets, and Search from the taskbar
.DESCRIPTION
    Sets registry values to disable the Task View button, Widgets, and Search box
    in the Windows 11 taskbar. Use as an Intune Proactive Remediation script.
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

try {
    if (Test-RegistryValue -Path "$regPath\Explorer\Advanced" -Value $showTaskViewButton) {
        if ((Get-ItemProperty -Path "$regPath\Explorer\Advanced" | Select-Object -ExpandProperty $showTaskViewButton) -ne 0) {
            Set-ItemProperty -Path "$regPath\Explorer\Advanced" -Name $showTaskViewButton -Value 0
        }
    }

    if (Test-RegistryValue -Path "$regPath\Explorer\Advanced" -Value $showWidgets) {
        if ((Get-ItemProperty -Path "$regPath\Explorer\Advanced" | Select-Object -ExpandProperty $showWidgets) -ne 0) {
            Set-ItemProperty -Path "$regPath\Explorer\Advanced" -Name $showWidgets -Value 0
        }
    }

    if (Test-RegistryValue -Path "$regPath\Search" -Value $showSearch) {
        if ((Get-ItemProperty -Path "$regPath\Search" | Select-Object -ExpandProperty $showSearch) -ne 0) {
            Set-ItemProperty -Path "$regPath\Search" -Name $showSearch -Value 0
        }
    }

    exit 0
} catch {
    Write-Error "Failed to update taskbar settings: $_"
    exit 1
}
