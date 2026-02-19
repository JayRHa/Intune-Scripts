<#
.SYNOPSIS
    Detect if a reboot is pending
.DESCRIPTION
    Checks multiple registry keys to determine whether a system reboot is pending.
    Exits with code 1 if a reboot is required.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
    exit 1
}
elseif (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
    exit 1
}
elseif (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress") {
    exit 1
}

exit 0
