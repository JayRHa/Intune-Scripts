<#
.SYNOPSIS
    Detect if device is in ESP (Enrollment Status Page)
.DESCRIPTION
    Checks whether the device is currently in the Enrollment Status Page by inspecting
    the owner of the explorer.exe process. Exits with code 1 if ESP is detected.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

try {
    $processesExplorer = @(Get-CimInstance -ClassName 'Win32_Process' -Filter "Name like 'explorer.exe'" -ErrorAction 'Ignore')
    $esp = $false
    foreach ($processExplorer in $processesExplorer) {
        $user = (Invoke-CimMethod -InputObject $processExplorer -MethodName GetOwner).User
        if ($user -eq 'defaultuser0' -or $user -eq 'defaultuser1') { $esp = $true }
    }

    if ($esp) {
        Write-Host "ESP detected"
        exit 1
    } else {
        Write-Host "ESP not detected"
        exit 0
    }
} catch {
    Write-Error "Failed to detect ESP status: $_"
    exit 1
}
