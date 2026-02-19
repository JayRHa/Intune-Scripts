<#
.SYNOPSIS
    Remove the primary user from all Intune managed devices.
.DESCRIPTION
    Retrieves all managed devices (optionally filtered by device name) and removes
    the primary user assignment, effectively converting them to shared devices.
.NOTES
    Author : Jannik Reinhard
    Version: 1.1
#>

#Requires -Modules Microsoft.Graph.Authentication

function Connect-MgGraphIfNeeded {
    $context = Get-MgContext
    if (-not $context) {
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All" -NoWelcome
    }
}

####################################################

function Get-Win10IntuneManagedDevices {

<#
.SYNOPSIS
This gets information on Intune managed devices
.DESCRIPTION
This gets information on Intune managed devices
.EXAMPLE
Get-Win10IntuneManagedDevices
.NOTES
NAME: Get-Win10IntuneManagedDevices
#>

[cmdletbinding()]

param
(
[parameter(Mandatory=$false)]
[ValidateNotNullOrEmpty()]
[string]$deviceName
)

    $devices = @()
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
    try {
        if ($deviceName) {
            $uri = "$uri?" + '$filter' + "=deviceName eq '$deviceName'"
            $response = Invoke-MgGraphRequest -Uri $uri -Method GET
            $devices += $response.value
        } else {
            while ($uri) {
                $response = Invoke-MgGraphRequest -Uri $uri -Method GET
                $devices += $response.value
                $uri = $response.'@odata.nextLink'
            }
        }
    }
    catch {
        Write-Error "Failed to retrieve managed devices: $_"
        throw
    }
    return $devices
}

####################################################

function Get-IntuneDevicePrimaryUser {

<#
.SYNOPSIS
This lists the Intune device primary user
.DESCRIPTION
This lists the Intune device primary user
.EXAMPLE
Get-IntuneDevicePrimaryUser
.NOTES
NAME: Get-IntuneDevicePrimaryUser
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    [string] $deviceId
)
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" + "/" + $deviceId + "/users"

    try {
        $primaryUser = Invoke-MgGraphRequest -Uri $uri -Method GET
        return $primaryUser.value."id"
    }
    catch {
        Write-Error "Failed to get primary user for device $deviceId : $_"
        throw "Get-IntuneDevicePrimaryUser error"
    }
}

####################################################

function Remove-IntuneDevicePrimaryUser {

<#
.SYNOPSIS
This deletes the Intune device primary user
.DESCRIPTION
This deletes the Intune device primary user
.EXAMPLE
Remove-IntuneDevicePrimaryUser
.NOTES
NAME: Remove-IntuneDevicePrimaryUser
#>

[cmdletbinding()]

param
(
[parameter(Mandatory=$true)]
[ValidateNotNullOrEmpty()]
$IntuneDeviceId
)

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices('$IntuneDeviceId')/users/`$ref"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method DELETE
    }
    catch {
        Write-Error "Failed to remove primary user for device $IntuneDeviceId : $_"
        throw "Remove-IntuneDevicePrimaryUser error"
    }
}

# Auth
Connect-MgGraphIfNeeded

$allDevices = Get-Win10IntuneManagedDevices
$filter = "*" # If nothing specified then all devices. Use wildcard e.g. *

if (-not ($filter -eq '*')) {
    $allDevices = $allDevices | Where-Object {$_.deviceName -like $filter}
}

foreach ($allDevice in $allDevices) {
    Write-Host "Change $($allDevice.devicename) to a shared device"
    Remove-IntuneDevicePrimaryUser -IntuneDeviceId $allDevice.id -ErrorAction Continue
}
