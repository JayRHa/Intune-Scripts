<#
.SYNOPSIS
    Export device app inventory to JSON
.DESCRIPTION
    Retrieves all discovered apps from Intune managed devices and writes them
    to a JSON file. Uses Microsoft Graph PowerShell SDK.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
#>

################################################################################################################
############################################# Variables ########################################################
################################################################################################################
function Get-GraphAuthentication{
    if (-not (Get-Module -ListAvailable -Name 'Microsoft.Graph')) {
        Write-Error "Microsoft.Graph module is not installed. See: https://docs.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0"
        return $false
    }

    try {
      Connect-MgGraph -Scopes "Device.Read.All"
    } catch {
      Write-Error "Failed to connect to MgGraph"
      return $false
    }

    return $true
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################

Get-GraphAuthentication | Out-Null

$deviceList = @()
Get-MgDeviceManagementManagedDevice | ForEach-Object {
    $deviceHostname = $_.deviceName
    $device = Get-MgDeviceManagementManagedDevice -Expand detectedApps -ManagedDeviceId $_.id
    $device.detectedApps | ForEach-Object {
        $properties = [Ordered] @{
            "Hostname"      = $deviceHostname
            "AppName"       = $_.DisplayName
            "Version"       = $_.Version
        }

        $deviceAppInventory = (New-Object -TypeName "PSObject" -Property $properties) | ConvertTo-Json
    $deviceList += $deviceAppInventory
    }
}

$deviceList | Out-File -FilePath "./DeviceAppInventory.json" -Force
