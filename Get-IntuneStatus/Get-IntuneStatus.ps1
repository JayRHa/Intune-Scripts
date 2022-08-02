
<#PSScriptInfo
.VERSION 1.0
.GUID a71cb63b-4428-471b-9c13-dfa29d6b40f6
.AUTHOR Jannik Reinhard
.COMPANYNAME
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI https://github.com/JayRHa/Intune-Scripts/tree/main/Change-ImeLogLevel
.ICONURI
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Get an Intune status overview 
.INPUTS
 None required
.OUTPUTS
 None
.NOTES
 Author: Jannik Reinhard (jannikreinhard.com)
 Twitter: @jannik_reinhard
 Release notes:
  Version 1.0: Init
#> 

Param()


function Get-AuthToken {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $User
    )

    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    $tenant = $userUpn.Host
    $AadModule = Get-Module -Name "AzureAD" -ListAvailable
    if ($AadModule -eq $null) {
        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    }

    $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$Tenant"

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
    $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
    $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result

      
    $authHeader = @{
        'Content-Type'='application/json'
        'Authorization'="Bearer " + $authResult.AccessToken
        'ExpiresOn'=$authResult.ExpiresOn
        }

    return $authHeader

}

function Get-GraphCall {
    param(
             [Parameter(Mandatory)]
             $apiUri,
             [Parameter(Mandatory)]
             $method
       )
    return Invoke-RestMethod -Uri https://graph.microsoft.com/beta/$apiUri -Headers $authToken -Method $method
}


#Auth
if(-not $global:authToken){
    if($User -eq $null -or $User -eq ""){
    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host
    }
    $global:authToken = Get-AuthToken -User $User
}

$complianceState    = Get-GraphCall -method 'GET' -apiUri 'deviceManagement/deviceCompliancePolicyDeviceStateSummary'
$managedDevices     = Get-GraphCall -method 'GET' -apiUri 'deviceManagement/managedDeviceOverview'
$appManagement      = Get-GraphCall -method 'GET' -apiUri 'deviceAppManagement'
$autopilotState     = Get-GraphCall -method 'GET' -apiUri 'deviceManagement/windowsAutoPilotSettings'
$defenderState      = Get-GraphCall -method 'GET' -apiUri 'deviceManagement/mobileThreatDefenseConnectors'

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
"+++++++++++++++++++++++++ Operating Systems +++++++++++++++++++++++++" + "`r`n" +  
"Windows: " + $managedDevices.deviceOperatingSystemSummary.windowsCount + "`r`n" +
"Android: " + $managedDevices.deviceOperatingSystemSummary.androidCount + "`r`n" +  
"IOS: " + $managedDevices.deviceOperatingSystemSummary.iosCount + "`r`n" +  
"MacOS: " + $managedDevices.deviceOperatingSystemSummary.macOSCount + "`r`n" +  
"Windows Mobile: " + $managedDevices.deviceOperatingSystemSummary.windowsMobileCount + "`r`n" +
"`r`n" + 
"+++++++++++++++++++++++++ Compliance State +++++++++++++++++++++++++" + "`r`n" + 
"Compliant Device: " + $complianceState.compliantDeviceCount + "`r`n" +  
"Not Compliant Device: " + $complianceState.nonCompliantDeviceCount + "`r`n" +  
"In Grace Period: " + $complianceState.inGracePeriodCount + "`r`n" +  
"Not Applicable: " + $complianceState.notApplicableDeviceCount + "`r`n" +  
"Devices with error: " + $complianceState.errorDeviceCount + "`r`n" +  
"Devices with conflict : " + $complianceState.conflictDeviceCount + "`r`n" +  
"`r`n" +
"+++++++++++++++++++++++++ Tenant State +++++++++++++++++++++++++" + "`r`n" +
"Windows AutoPilot last sync date: " + $autopilotState.lastSyncDateTime + "`r`n" +
"Microsoft Store for Business last sync date: " + $appManagement.microsoftStoreForBusinessLastSuccessfulSyncDateTime + "`r`n" +
"Microsoft Defender for Endpoint Connector: " + $defenderState.value.lastHeartbeatDateTime + "`r`n"


Write-Host $result