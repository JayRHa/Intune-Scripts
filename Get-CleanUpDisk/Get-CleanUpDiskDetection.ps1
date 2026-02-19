<#
.SYNOPSIS
    Detect if disk cleanup is needed
.DESCRIPTION
    Checks free space on the C: drive. If free space is below the threshold (15 GB),
    exits with code 1 to trigger remediation.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

$storageThreshold = 15

$utilization = (Get-PSDrive | Where-Object { $_.Name -eq "C" }).Free

if (($storageThreshold * 1GB) -lt $utilization) {
    exit 0
} else {
    exit 1
}
