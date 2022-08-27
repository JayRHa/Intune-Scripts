<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-EaValueDetection
Description:
Collect an value with endpoint analytics
Release notes:
Version 1.0: Init
#> 

$manufacture= (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer

Write-Output $manufacture
Exit 0
