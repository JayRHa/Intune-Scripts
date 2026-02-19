<#
.SYNOPSIS
    Detect taskbar alignment on Windows 11
.DESCRIPTION
    Checks whether the Windows 11 taskbar is aligned to the left (value 0).
    Exits with code 0 if aligned left, code 1 otherwise.
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

if (Test-RegistryValue -Path $path -Value $value) {
    if ((Get-ItemProperty -Path $path -Name $value).TaskbarAl -eq "0") {
        exit 0
    }
}

exit 1
