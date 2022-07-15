<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-CleanUpDiskDetection
Description:
Cleanup disk when utilization <15GB
Release notes:
Version 1.0: Init
#> 
$storageThreshold = 15

$utilization = (Get-PSDrive | Where {$_.name -eq "C"}).free

if(($storageThreshold *1GB) -lt $utilization){exit 0}
else{exit 1}

