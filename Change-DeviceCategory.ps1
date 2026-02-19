<#
.SYNOPSIS
    Change the device category of an Intune managed device.
.DESCRIPTION
    Sets the device category for a single Intune device using the Microsoft
    Graph beta endpoint via the Intune PowerShell SDK (Connect-MSGraph).
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
    Release: v1.0 - Init
             v1.1 - Renamed function to Set-DeviceCategory, added validation
#>

# NOTE: Connect-MSGraph is part of the deprecated Intune PowerShell SDK.
# Consider migrating to Microsoft.Graph module with Connect-MgGraph.
Connect-MSGraph
Update-MSGraphEnvironment -SchemaVersion 'beta'

function Set-DeviceCategory {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ $_ -ne 'ADD-DEVICE-ID' })]
        [string]$DeviceID,

        [Parameter(Mandatory)]
        [ValidateScript({ $_ -ne 'ADD-THE-DEVICE-CATEGORY-ID' })]
        [string]$DeviceCategory
    )

    try {
        $body = @{ "@odata.id" = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/$DeviceCategory" }
        Invoke-MSGraphRequest -HttpMethod PUT -Url "deviceManagement/managedDevices/$DeviceID/deviceCategory/`$ref" -Content $body
    }
    catch {
        Write-Error "Failed to set device category: $_"
    }
}

$DeviceID = 'ADD-DEVICE-ID'
$DeviceCategory = 'ADD-THE-DEVICE-CATEGORY-ID'

Set-DeviceCategory -DeviceID $DeviceID -DeviceCategory $DeviceCategory
