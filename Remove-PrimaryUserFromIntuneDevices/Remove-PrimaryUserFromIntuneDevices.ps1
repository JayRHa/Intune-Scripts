<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Remove-PrimaryUserFromIntuneDevices
Description:
Remove the rimary user fro all devices
Release notes:
Version 1.0: Init
#> 

######## Variables ########
$filter = "contains(operatingSystem,'Windows')"
# $filter = "contains(operatingSystem,'Windows') and contains(deviceName,'DESKTOP-')"
# $filter = "contains(operatingSystem,'Windows') and (deviceName eq 'DESKTOP-XXXXXXX' or deviceName eq 'DESKTOP-XXXXXXX')"

# Check if Microsoft Graph module is installed
$module = Get-Module -Name Microsoft.Graph -ListAvailable
if ($module -eq $null) {
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
    Import-Module -Name Microsoft.Graph
} else {
    Write-Host "Microsoft Graph module is already installed."
}

# Authentication
Connect-MgGraph

# Get all Windows devices
$devices = Get-MgDeviceManagementManagedDevice -all -Filter $filter # You can adapt this filter also to select a other device group

foreach ($device in $devices) {
    # Remove primary user from device
    #Invoke-MgGraphRequest -Uri "deviceManagement/managedDevices/$($device.id)/users/$($device.primaryUser.id)/`$ref" -Method Delete
}
Write-Host $devices


# ####################################################


# function Get-IntuneDevicePrimaryUser {

# <#
# .SYNOPSIS
# This lists the Intune device primary user
# .DESCRIPTION
# This lists the Intune device primary user
# .EXAMPLE
# Get-IntuneDevicePrimaryUser
# .NOTES
# NAME: Get-IntuneDevicePrimaryUser
# #>

# [cmdletbinding()]

# param
# (
#     [Parameter(Mandatory=$true)]
#     [string] $deviceId
# )
#     $graphApiVersion = "beta"
#     $Resource = "deviceManagement/managedDevices"
# 	$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" + "/" + $deviceId + "/users"

#     try {
        
#         $primaryUser = Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get

#         return $primaryUser.value."id"
        
# 	} catch {
# 		$ex = $_.Exception
# 		$errorResponse = $ex.Response.GetResponseStream()
# 		$reader = New-Object System.IO.StreamReader($errorResponse)
# 		$reader.BaseStream.Position = 0
# 		$reader.DiscardBufferedData()
# 		$responseBody = $reader.ReadToEnd();
# 		Write-Host "Response content:`n$responseBody" -f Red
# 		Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
# 		throw "Get-IntuneDevicePrimaryUser error"
# 	}
# }

# ####################################################

# function Delete-IntuneDevicePrimaryUser {

# <#
# .SYNOPSIS
# This deletes the Intune device primary user
# .DESCRIPTION
# This deletes the Intune device primary user
# .EXAMPLE
# Delete-IntuneDevicePrimaryUser
# .NOTES
# NAME: Delete-IntuneDevicePrimaryUser
# #>

# [cmdletbinding()]

# param
# (
# [parameter(Mandatory=$true)]
# [ValidateNotNullOrEmpty()]
# $IntuneDeviceId
# )
    
#     $graphApiVersion = "beta"
#     $Resource = "deviceManagement/managedDevices('$IntuneDeviceId')/users/`$ref"

#     try {

#         $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

#         Invoke-RestMethod -Uri $uri -Headers $authToken -Method Delete

# 	}

#     catch {

# 		$ex = $_.Exception
# 		$errorResponse = $ex.Response.GetResponseStream()
# 		$reader = New-Object System.IO.StreamReader($errorResponse)
# 		$reader.BaseStream.Position = 0
# 		$reader.DiscardBufferedData()
# 		$responseBody = $reader.ReadToEnd();
# 		Write-Host "Response content:`n$responseBody" -f Red
# 		Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
# 		throw "Delete-IntuneDevicePrimaryUser error"
	
#     }

# }

# #Auth
# if(-not $global:authToken){
#     if($User -eq $null -or $User -eq ""){
#     $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
#     Write-Host
#     }
#     $global:authToken = Get-AuthToken -User $User
# }


# $allDevices = Get-Win10IntuneManagedDevices
# $filter = "*" # If nothing specified then all devices. Use wildcard e.g. *
# #Example to filter based on the OS Version
# #$filter = "*10.0.19045*"
# #if(-not ($filter -eq '*')){
# #    $allDevices = $allDevices | Where-Object {$_.osVersion -like $filter}
# #}


# if(-not ($filter -eq '*')){
#     $allDevices = $allDevices | Where-Object {$_.deviceName -like $filter}
# }


# Foreach ($allDevice in $allDevices){
#     Write-Host "Change $($allDevice.devicename) to a shared device"
#     Delete-IntuneDevicePrimaryUser -IntuneDeviceId $allDevice.id -ErrorAction Continue
# }

