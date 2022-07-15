<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Move-Windows11Taskbar
Description:
Change the tastkbar alignment
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

$path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$value = "TaskbarAl"

if(Test-Path $path){
    try{
        Set-ItemProperty -Path $path -Name $value -Value 0 -Force
        Exit 0
    }catch{
        Exit 1
    }
}else{
    Exit 1
}
