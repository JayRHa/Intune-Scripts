<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Change-DeviceCategory
Description:
The script helps you to change the category of an intune device
Release notes:
Version 1.0: Init
#> 

Connect-MSGraph
Update-MSGraphEnvironment -SchemaVersion 'beta'


function Change-DeviceCategory {
	param(
		[Parameter(Mandatory)]
		[string]$DeviceID,
		
		[Parameter(Mandatory)]
		[string]$DeviceCategory
	)

    
    $body = @{ "@odata.id" = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/$DeviceCategory" }
    Invoke-MSGraphRequest -HttpMethod PUT -Url "deviceManagement/managedDevices/$DeviceID/deviceCategory/`$ref" -Content $body

}

$DeviceID = 'ADD-DEVICE-ID'
$DeviceCategory = 'ADD-THE-DEVICE-CATEGORY-ID'


Change-DeviceCategory -DeviceID $DeviceID -DeviceCategory $DeviceCategory