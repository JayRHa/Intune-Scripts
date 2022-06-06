<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Change-ImeLogLevel
Description:
Change the loglevel from the Intune management extension
Release notes:
Version 1.0: Init
#> 

# Check if Admin
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
	Write-Warning "Please execute the script with admin rights"
    exit
}

Function Change-ImeLoglevel($logLevelValue){
    $imeConfFile = "C:\Program Files (x86)\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe.config"

    $configFile = New-Object System.XML.XMLDocument
    $configFile.Load($imeConfFile)

    $logLevel = $configFile.configuration.'system.diagnostics'.sources.source
    $logLevel.switchValue = "$logLevelValue"
    $configFile.Save($imeConfFile)
    Write-Warning "IME Log level changed to $logLevelValue"
}

Function Restart-Ime{
    Restart-Service -DisplayName "Microsoft Intune Management Extension"
    Write-Warning "IME Service was restarted"    
}

# Select Logging level
$logLevelSelection = Read-Host "Enter the log level [Critical, Error, Warning, Information, Verbose]"
while("Critical", "Error", "Warning", "Information", "Verbose" -notcontains $logLevelSelection )
{
    $logLevelSelection = Read-Host "Enter the log level [Critical, Error, Warning, Information, Verbose]"
}

# Change logging level
Change-ImeLoglevel($logLevelSelection)

# Restart IME Service
Restart-Ime


# Open Ime log folder
$openLogs = Read-Host "Open Log file folder [Y/N]"
while("Y", "N", "Yes", "No", "y", "n" -notcontains $openLogs )
{
    $openLogs = Read-Host "Open Log file folder [Y/N]"
}
If("Y", "Yes", "y" -contains $openLogs){
    explorer c:\ProgramData\Microsoft\IntuneManagementExtension\Logs
}