<#PSScriptInfo
.VERSION 1.1
.GUID 32017cad-9484-41d1-9f1c-93044955f3e5
.AUTHOR Jannik Reinhard
.COMPANYNAME
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI https://github.com/JayRHa/Intune-Scripts/tree/main/Change-ImeLogLevel
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA

#>

<#
.SYNOPSIS
    Change the log level of the Intune Management Extension (IME).
.DESCRIPTION
    Modifies the IME configuration XML to set the desired log verbosity,
    restarts the IME service, and optionally opens the log folder.
.INPUTS
    None required
.OUTPUTS
    None
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
    Release: v1.0 - Init
             v1.1 - Renamed to Set-ImeLoglevel, added Test-Path, try/catch
#>
Param()

# Check if Admin
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
	Write-Warning "Please execute the script with admin rights"
    exit
}

Function Set-ImeLoglevel($logLevelValue){
    $imeConfFile = "C:\Program Files (x86)\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe.config"

    if (-not (Test-Path $imeConfFile)) {
        Write-Error "IME configuration file not found: $imeConfFile"
        return
    }

    try {
        $configFile = New-Object System.XML.XMLDocument
        $configFile.Load($imeConfFile)

        $logLevel = $configFile.configuration.'system.diagnostics'.sources.source
        $logLevel.switchValue = "$logLevelValue"
        $configFile.Save($imeConfFile)
        Write-Host "IME Log level changed to $logLevelValue"
    }
    catch {
        Write-Error "Failed to update IME log level: $_"
    }
}

Function Restart-Ime{
    Restart-Service -DisplayName "Microsoft Intune Management Extension"
    Write-Host "IME Service was restarted"
}

# Select Logging level
$logLevelSelection = Read-Host "Enter the log level [Critical, Error, Warning, Information, Verbose]"
while("Critical", "Error", "Warning", "Information", "Verbose" -notcontains $logLevelSelection )
{
    $logLevelSelection = Read-Host "Enter the log level [Critical, Error, Warning, Information, Verbose]"
}

# Change logging level
Set-ImeLoglevel($logLevelSelection)

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
