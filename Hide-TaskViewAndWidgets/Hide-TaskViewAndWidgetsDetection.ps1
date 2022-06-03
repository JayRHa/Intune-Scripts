<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Hide-TaskViewAndWidgetsDetection
Description:
Hite the Task View and Widgets icons in the task bar
Release notes:
Version 1.0: Init
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
    }catch {
        return $false
    }
}

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$showTaskViewButton = "ShowTaskViewButton"
$showWidgets = "TaskbarDa"

If(Test-RegistryValue -Path $regPath -Value $showTaskViewButton){
    if((Get-ItemProperty -Path $regPath | Select-Object -ExpandProperty $showTaskViewButton) -ne 0){
        Write-Host "Show Task View Button is active"
        exit 1
    }
}

If(Test-RegistryValue -Path $regPath -Value $showTaskViewButton){
    if((Get-ItemProperty -Path $regPath | Select-Object -ExpandProperty $showWidgets) -ne 0){
        Write-Host "Show Widgets is active"
        exit 1
    }
}

exit 0