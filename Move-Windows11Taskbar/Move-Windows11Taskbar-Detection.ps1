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


if(-not (Get-CimInstance Win32_OperatingSystem -Property *).Caption -like "*Windows 11*"){
    Exit 0
}


if((Test-RegistryValue -Path $path -Value $value)){
    if((Get-ItemProperty -path $path -name $value).TaskbarAl -eq "0"){
        Exit 0
    }
}else {
    Exit 1
}


