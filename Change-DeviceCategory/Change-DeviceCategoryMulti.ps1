<#
.SYNOPSIS
    Change the device category for multiple Intune devices based on name pattern.
.DESCRIPTION
    Iterates over all managed devices and assigns a device category depending
    on whether the device name matches a pattern. Uses the Intune PowerShell SDK.
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
    Release: v1.0 - Init
             v1.1 - Added header, try/catch
#>

# NOTE: Connect-MSGraph is part of the deprecated Intune PowerShell SDK.
# Consider migrating to Microsoft.Graph module with Connect-MgGraph.
Connect-MSGraph
Update-MSGraphEnvironment -SchemaVersion 'beta'

function Set-DeviceCategory {
    param(
        [Parameter(Mandatory)]
        [string]$DeviceID,

        [Parameter(Mandatory)]
        [string]$DeviceCategory
    )

    try {
        $body = @{ "@odata.id" = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/$DeviceCategory" }
        Invoke-MSGraphRequest -HttpMethod PUT -Url "deviceManagement/managedDevices/$DeviceID/deviceCategory/`$ref" -Content $body
    }
    catch {
        Write-Error "Failed to set device category for device $DeviceID : $_"
    }
}

try {
    $devices = (Invoke-MSGraphRequest -HttpMethod GET -Url "deviceManagement/managedDevices").value
    $devices | ForEach-Object {
        if ($_.deviceName -like '*Test*') {
            $deviceCategory = 'DEVICE_CATEGORY_ID1'
            Write-Host "Set device category '$deviceCategory' for $($_.deviceName)"
            Set-DeviceCategory -DeviceID $_.id -DeviceCategory $deviceCategory
        }
        else {
            $deviceCategory = 'DEVICE_CATEGORY_ID2'
            Write-Host "Set device category '$deviceCategory' for $($_.deviceName)"
            Set-DeviceCategory -DeviceID $_.id -DeviceCategory $deviceCategory
        }
    }
}
catch {
    Write-Error "Failed to retrieve or process managed devices: $_"
}
