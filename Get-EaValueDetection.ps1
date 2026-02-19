<#
.SYNOPSIS
    Collect a value with Endpoint Analytics
.DESCRIPTION
    Retrieves the device manufacturer via CIM and outputs it for Endpoint Analytics custom attribute collection.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

try {
    $manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    Write-Output $manufacturer
    exit 0
} catch {
    Write-Error "Failed to retrieve manufacturer: $_"
    exit 1
}
