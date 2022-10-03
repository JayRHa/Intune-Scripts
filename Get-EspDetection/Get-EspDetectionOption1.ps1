<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-EspDetection
Description:
Skip the ESP for app installation
Release notes:
Version 1.0: Init
#> 

$processesExplorer = @(Get-CimInstance -ClassName 'Win32_Process' -Filter "Name like 'explorer.exe'" -ErrorAction 'Ignore')
$esp = $false
foreach ($processExplorer in $processesExplorer) {
    $user = (Invoke-CimMethod -InputObject $processExplorer -MethodName GetOwner).User
    if ($user -eq 'defaultuser0' -or $user -eq 'defaultuser1') {$esp = $true}
}

Write-Host $esp 