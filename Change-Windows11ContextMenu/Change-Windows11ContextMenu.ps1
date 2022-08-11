<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Change-Windows11ContextMenu
Description:
Change the Windows 11 context menu to the windows 10
Release notes:
Version 1.1: Use native PowerShell cmdlet instead of external executable (reg.exe)
#> 

$rc = New-Item -Path 'REGISTRY::HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' -Force
