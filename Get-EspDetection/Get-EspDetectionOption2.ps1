<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-EspDetection
Description:
Skip the ESP for app installation
Release notes:
Version 1.0: Init
#> 


[bool]$DevicePrepComplete = $false
[bool]$DeviceSetupComplete = $false
[bool]$AccountSetupComplete = $false

$regPath = 'HKLM:\SOFTWARE\Microsoft\Provisioning\AutopilotSettings'
$esp = $true

try{
    $devicePreperationCategory = (Get-ItemProperty -Path $regPath -Name 'DevicePreparationCategory.Status' -ErrorAction 'Ignore').'DevicePreparationCategory.Status'
    $deviceSetupCategory = (Get-ItemProperty -Path $regPath -Name 'DeviceSetupCategory.Status' -ErrorAction 'Ignore').'DeviceSetupCategory.Status'
    $sccountSetupCategory = (Get-ItemProperty -Path $regPath -Name 'AccountSetupCategory.Status' -ErrorAction 'Ignore').'AccountSetupCategory.Status'

}catch{
    $esp = $false
}

if (-not (($devicePreperationCategory.categorySucceeded -eq 'True') -or ($devicePreperationCategory.categoryState -eq 'succeeded'))) {$esp = $false}
if (-not (($deviceSetupCategory.categorySucceeded -eq 'True') -or ($deviceSetupCategory.categoryState -eq 'succeeded'))) {$esp = $false}
if (-not (($sccountSetupCategory.categorySucceeded -eq 'True') -or ($sccountSetupCategory.categoryState -eq 'succeeded'))) {$esp = $false}


Write-Host $esp 