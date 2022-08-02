
<#PSScriptInfo
.VERSION 1.0
.GUID 73e3aa75-340f-4f52-99ec-cfbb55a2e2d1
.AUTHOR Jannik Reinhard
.COMPANYNAME
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI https://github.com/JayRHa/Intune-Scripts/tree/main/Deploy-DefaultFilter
.ICONURI
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Default set on intune filter 
.INPUTS
 None required
.OUTPUTS
 None
.NOTES
 Author: Jannik Reinhard (jannikreinhard.com)
 Twitter: @jannik_reinhard
 Release notes:
    Version 1.0: Init
    Version 1.1: Add Windows365
    Version 1.2: Add description
#> 
Param()

function Get-GraphAuthentication{
    try {
        Import-Module Microsoft.Graph.DeviceManagement
      } catch {
        Install-Module Microsoft.Graph -Scope CurrentUser
        Import-Module Microsoft.Graph.DeviceManagement
      }


    try {
      Connect-MgGraph -Scopes "DeviceManagementServiceConfig.Read.All"
    } catch {
      Write-Error "Failed to connect to MgGraph"
    }
    
    Select-MgProfile -Name "beta"
}
function Add-IntuneFilter{
    param (
        [parameter(Mandatory=$true)]$Name,
        [parameter(Mandatory=$true)]$Platform,
        [parameter(Mandatory=$true)]$Description,
        [parameter(Mandatory=$true)]$Rule
    )

    Get-MgDeviceManagementAssignmentFilter -Search $Name | ForEach-Object {
            Remove-MgDeviceManagementAssignmentFilter -DeviceAndAppManagementAssignmentFilterId $_.Id
    }
    $params = @{
        DisplayName = $filterPreFix + $Name
        Description = $Description
        Platform = $Platform
        Rule = $Rule
        RoleScopeTags = @()
    }
    
    New-MgDeviceManagementAssignmentFilter -BodyParameter $params
}

#########################################################################################################
############################################ Start ######################################################
#########################################################################################################
$global:filterPreFix = "MDM"
Get-GraphAuthentication


###### Windows 10 ######
# Ownership
Add-IntuneFilter -Name "AllPersonalDevices" -Platform "Windows10AndLater" -Description "All personal W10 and later devices" -Rule '(device.deviceOwnership -eq "Personal")'
Add-IntuneFilter -Name "AllCorporateDevices" -Platform "Windows10AndLater" -Description "All corporate W10 and later devices" -Rule '(device.deviceOwnership -eq "Corporate")'

# Enrollment Profile
Get-MgDeviceManagementWindowAutopilotDeploymentProfile | ForEach-Object {
    Add-IntuneFilter -Name ("Enrollment"+($($_.DisplayName).Trim())) -Platform "Windows10AndLater" -Description ("All devcies with enrollment profile"+($($_.DisplayName).Trim())) -Rule ('(device.enrollmentProfileName -eq "'+$($_.DisplayName)+'")' )
}

# Operating System SKU
$sku = @("Education", "Enterprise", "IoTEnterprise", "Professional", "Holographic")  
$sku | ForEach-Object {
    Add-IntuneFilter -Name "AllSku$_" -Platform "Windows10AndLater" -Description "All devices with SKU $_" -Rule ('(device.operatingSystemSKU  -eq "'+$_+'")')
}

# Operating System Version
Add-IntuneFilter -Name "AllWindows11" -Platform "Windows10AndLater" -Description "All Windows 11 devices" -Rule '(device.osVersion -startsWith "10.0.22")'
Add-IntuneFilter -Name "AllWindows10" -Platform "Windows10AndLater" -Description "All Windows 10 devices" -Rule '(device.osVersion -startsWith "10.0.1")'
Add-IntuneFilter -Name "AllWindows8.1" -Platform "Windows10AndLater" -Description "All Windows 8.1 devices" -Rule '(device.osVersion -startsWith "6.3")'

# Device Category
Get-MgDeviceManagementDeviceCategory | ForEach-Object {
    Add-IntuneFilter -Name ("Category"+($($_.DisplayName).Trim())) -Description ("All device with category "+($($_.DisplayName).Trim())) -Platform "Windows10AndLater" -Rule ('(device.deviceCategory  -eq "'+$($_.DisplayName)+'")' )
}

# Model
Add-IntuneFilter -Name "AllCloudPCs" -Platform "Windows10AndLater" -Description "All Microsoft365 devices" -Rule '(device.model -contains "CloudPC") or (device.model -contains "Cloud PC")'

