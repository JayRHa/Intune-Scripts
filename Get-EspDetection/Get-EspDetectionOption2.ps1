<#
.SYNOPSIS
    Detect if the Enrollment Status Page (ESP) is active
.DESCRIPTION
    Checks the Autopilot registry settings to determine whether the ESP phases
    (device preparation, device setup, account setup) have completed successfully.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

$regPath = 'HKLM:\SOFTWARE\Microsoft\Provisioning\AutopilotSettings'
$esp = $true

try{
    $devicePreperationCategory = (Get-ItemProperty -Path $regPath -Name 'DevicePreparationCategory.Status' -ErrorAction 'Stop').'DevicePreparationCategory.Status'
    $deviceSetupCategory = (Get-ItemProperty -Path $regPath -Name 'DeviceSetupCategory.Status' -ErrorAction 'Stop').'DeviceSetupCategory.Status'
    $accountSetupCategory = (Get-ItemProperty -Path $regPath -Name 'AccountSetupCategory.Status' -ErrorAction 'Stop').'AccountSetupCategory.Status'

}catch{
    $esp = $false
}

if (-not (($devicePreperationCategory.categorySucceeded -eq 'True') -or ($devicePreperationCategory.categoryState -eq 'succeeded'))) {$esp = $false}
if (-not (($deviceSetupCategory.categorySucceeded -eq 'True') -or ($deviceSetupCategory.categoryState -eq 'succeeded'))) {$esp = $false}
if (-not (($accountSetupCategory.categorySucceeded -eq 'True') -or ($accountSetupCategory.categoryState -eq 'succeeded'))) {$esp = $false}

if ($esp) {
    Write-Host "ESP is active"
    exit 0
} else {
    Write-Host "ESP is not active"
    exit 1
}
