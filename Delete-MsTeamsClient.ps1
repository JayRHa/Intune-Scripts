<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Delete-TeamsClient
Description:
Delete the build-in Windows 11 teams client with help of intune
Release notes:
Version 1.0: Init
#>  


Get-AppxPackage | Where-Object Name -like "*MicrosoftTeams*" | Remove-AppxPackage