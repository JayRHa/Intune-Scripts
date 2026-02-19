<#
.SYNOPSIS
    Move Windows 11 taskbar alignment to left
.DESCRIPTION
    Sets the TaskbarAl registry value to 0, aligning the Windows 11 taskbar to the left.
    Includes an OS check to ensure it only runs on Windows 11.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

function Test-RegistryValue {
    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Value
    )

    try {
        Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

$path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$value = "TaskbarAl"

$osCaption = (Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption).Caption
if ($osCaption -notlike "*Windows 11*") {
    Write-Host "Not Windows 11, skipping"
    exit 0
}

if (Test-Path $path) {
    try {
        Set-ItemProperty -Path $path -Name $value -Value 0 -Force
        exit 0
    } catch {
        Write-Error "Failed to set taskbar alignment: $_"
        exit 1
    }
} else {
    Write-Error "Registry path not found: $path"
    exit 1
}
