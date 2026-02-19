<#
.SYNOPSIS
    Display an Intune tenant status overview.
.DESCRIPTION
    Retrieves device counts, OS distribution, compliance state, and tenant sync
    information from Microsoft Graph and prints a summary to the console.
.NOTES
    Author : Jannik Reinhard
    Version: 1.1
#>

#Requires -Modules Microsoft.Graph.Authentication

Param(
    [string]$User
)

function Connect-MgGraphIfNeeded {
    $context = Get-MgContext
    if (-not $context) {
        Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All","DeviceManagementApps.Read.All","DeviceManagementManagedDevices.Read.All" -NoWelcome
    }
}

function Get-GraphCall {
    param(
        [Parameter(Mandatory)]
        $apiUri,
        [Parameter(Mandatory)]
        $method
    )
    return Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/$apiUri" -Method $method
}

# Auth
Connect-MgGraphIfNeeded

try {
    $complianceState = Get-GraphCall -method 'GET' -apiUri 'deviceManagement/deviceCompliancePolicyDeviceStateSummary'
}
catch {
    Write-Error "Failed to retrieve compliance state: $_"
}

try {
    $managedDevices = Get-GraphCall -method 'GET' -apiUri 'deviceManagement/managedDeviceOverview'
}
catch {
    Write-Error "Failed to retrieve managed device overview: $_"
}

try {
    $appManagement = Get-GraphCall -method 'GET' -apiUri 'deviceAppManagement'
}
catch {
    Write-Error "Failed to retrieve app management info: $_"
}

try {
    $autopilotState = Get-GraphCall -method 'GET' -apiUri 'deviceManagement/windowsAutoPilotSettings'
}
catch {
    Write-Error "Failed to retrieve AutoPilot settings: $_"
}

try {
    $defenderState = Get-GraphCall -method 'GET' -apiUri 'deviceManagement/mobileThreatDefenseConnectors'
}
catch {
    Write-Error "Failed to retrieve Defender connector state: $_"
}

$result = @"
********************************************************************
********************** Status Intune Overview **********************
********************************************************************

+++++++++++++++++++++++++++ Device Count +++++++++++++++++++++++++++
"@ + "`r`n" +
"Total Devices: " + $managedDevices.enrolledDeviceCount + "`r`n" +
"Mdm only Devices: " + $managedDevices.mdmEnrolledCount + "`r`n" +
"Co-Managed Devices: " + $managedDevices.dualEnrolledDeviceCount + "`r`n" +
"`r`n" +
"++++++++++++++++++++++++++++ Operating Systems +++++++++++++++++++++++++" + "`r`n" +
"Windows: " + $managedDevices.deviceOperatingSystemSummary.windowsCount + "`r`n" +
"Android: " + $managedDevices.deviceOperatingSystemSummary.androidCount + "`r`n" +
"IOS: " + $managedDevices.deviceOperatingSystemSummary.iosCount + "`r`n" +
"MacOS: " + $managedDevices.deviceOperatingSystemSummary.macOSCount + "`r`n" +
"Windows Mobile: " + $managedDevices.deviceOperatingSystemSummary.windowsMobileCount + "`r`n" +
"`r`n" +
"++++++++++++++++++++++++++++ Compliance State +++++++++++++++++++++++++" + "`r`n" +
"Compliant Device: " + $complianceState.compliantDeviceCount + "`r`n" +
"Not Compliant Device: " + $complianceState.nonCompliantDeviceCount + "`r`n" +
"In Grace Period: " + $complianceState.inGracePeriodCount + "`r`n" +
"Not Applicable: " + $complianceState.notApplicableDeviceCount + "`r`n" +
"Devices with error: " + $complianceState.errorDeviceCount + "`r`n" +
"Devices with conflict : " + $complianceState.conflictDeviceCount + "`r`n" +
"`r`n" +
"++++++++++++++++++++++++++++ Tenant State +++++++++++++++++++++++++" + "`r`n" +
"Windows AutoPilot last sync date: " + $autopilotState.lastSyncDateTime + "`r`n" +
"Microsoft Store for Business last sync date: " + $appManagement.microsoftStoreForBusinessLastSuccessfulSyncDateTime + "`r`n" +
"Microsoft Defender for Endpoint Connector: " + $defenderState.value.lastHeartbeatDateTime + "`r`n"


Write-Host $result
