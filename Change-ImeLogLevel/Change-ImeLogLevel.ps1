<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Change-ImeLogLevel
Description:
Change the loglevel from the Intune management extension
Release notes:
Version 1.0: Init
#> 

$logLevelSelection = Read-Host "Enter the log level [Critical, Error, Warning, Information, Verbose]"
while("Critical", "Error", "Warning", "Information", "Verbose" -notcontains $logLevelSelection )
{
    $logLevelSelection = Read-Host "Enter the log level [Critical, Error, Warning, Information, Verbose]"
}

$imeConfFile = "C:\Program Files (x86)\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe.config"

$configFile = New-Object System.XML.XMLDocument
$configFile.Load($imeConfFile)

$logLevel = $configFile.configuration.'system.diagnostics'.sources.source
$logLevel.switchValue = "$logLevelSelection"
$configFile.Save($imeConfFile)

Restart-Service -DisplayName "Microsoft Intune Management Extension"

Write-Host "IME Log level changed to $logLevelSelection"