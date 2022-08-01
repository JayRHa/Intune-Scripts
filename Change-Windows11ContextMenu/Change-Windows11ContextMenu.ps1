<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Change-Windows11ContextMenu
Description:
Change the Windows 11 context menue to the windows 10
Release notes:
Version 1.0: Init
#> 

REG.EXE add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve