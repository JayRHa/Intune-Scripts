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


function Set-DeviceCategory {
	param(
		[Parameter(Mandatory)]
		[string]$DeviceID,
		
		[Parameter(Mandatory)]
		[string]$DeviceCategory
	)

    
    $body = @{ "@odata.id" = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/$DeviceCategory" }
    Invoke-MSGraphRequest -HttpMethod PUT -Url "deviceManagement/managedDevices/$DeviceID/deviceCategory/`$ref" -Content $body
}

$devices = (Invoke-MSGraphRequest -HttpMethod GET -Url "deviceManagement/managedDevices").value
$devices | ForEach-Object {
	if($_.deviceName -like '*Test*'){
		$deviceCategory = 'DEVICE_CATEGORY_ID1'
		write-host "Set device category '$deviceCategory' for $($_.deviceName)"
		Set-DeviceCategory -DeviceID $_.id -DeviceCategory $deviceCategory
	}else{
		$deviceCategory = 'DEVICE_CATEGORY_ID2'
		write-host "Set device category '$deviceCategory' for $($_.deviceName)"
		Set-DeviceCategory -DeviceID $_.id -DeviceCategory $deviceCategory
	}
}
