<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Move-Windows11Taskbar
Description:
Change the tastkbar alignment
Release notes:
Version 1.0: Init
#> 

if((Get-CimInstance Win32_OperatingSystem -Property *).Caption -like "*Windows 11*"){
    Set-ItemProperty -Path “HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced” TaskbarAl -Value 0 –Force
}


