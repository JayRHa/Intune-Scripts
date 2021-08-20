<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Set-MapNetworkDrive
Description:
Map an Networkdrive with Intune
Release notes:
Version 1.0: Init
#> 

New-PSDrive -Name "K" -PSProvider FileSystem -Root "ADDRESSOFTHEFILESHARE" -Persist