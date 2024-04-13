<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-DeviceAppInventory
Description:
Write all discovered app in an log analytics workspace
Release notes:
Version 1.0: Init
#>

################################################################################################################
############################################# Variables ########################################################
################################################################################################################
function Get-GraphAuthentication{
    $GraphPowershellModulePath = "$global:Path/Microsoft.Graph.psd1"
    if (-not (Get-Module -ListAvailable -Name 'Microsoft.Graph')) {
  
        if (-Not (Test-Path $GraphPowershellModulePath)) {
            Write-Error "Microsoft.Graph.Intune.psd1 is not installed on the system check: https://docs.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0"
            Return
        }
        else {
            Import-Module "$GraphPowershellModulePath"
            $Success = $?
  
            if (-not ($Success)) {
                Write-Error "Microsoft.Graph.Intune.psd1 is not installed on the system check: https://docs.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0"
                Return
            }
        }
    }
  

    try {
      Connect-MgGraph -Scopes "Device.Read.All"
    } catch {
      Write-Error "Failed to connect to MgGraph"
      return $false
    }
    
    Select-MgProfile -Name "beta"
    return $true
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################

Get-GraphAuthentication | Out-Null

$deviceList = []
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

$deviceList | Out-File -FilePath "$global:Path/DeviceAppInventory.json" -Force
