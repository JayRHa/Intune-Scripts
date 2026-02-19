<#PSScriptInfo
.SYNOPSIS
    Remove applicability rules from all Intune device configuration profiles.
.DESCRIPTION
    Connects to Microsoft Graph, enumerates all device configuration profiles,
    and patches any profile that has an OS-edition or OS-version applicability
    rule to remove that rule.
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
    Release: v1.0 - Init
             v1.1 - Bug fixes, code-quality improvements
#>

Param()


function Get-GraphAuthentication{
    if (-not (Get-Module -ListAvailable -Name 'Microsoft.Graph')) {
        Write-Error "Microsoft.Graph module is not installed. See: https://docs.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0"
        return $false
    }

    try {
      Connect-MgGraph -Scopes "User.Read.All","Group.ReadWrite.All","DeviceManagementApps.Read.All", "Device.Read.All", "DeviceManagementApps.ReadWrite.All"
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

Get-MgDeviceManagementDeviceConfiguration -All | ForEach-Object {
    if(-not ($null -eq $_.DeviceManagementApplicabilityRuleOSEdition.RuleType)){
      $bodyJson = '{ "deviceManagementApplicabilityRuleOsEdition": null}' | ConvertFrom-Json
      $bodyJson | Add-Member -NotePropertyName "@odata.type" -NotePropertyValue $_.AdditionalProperties.'@odata.type'
      Write-Host "Applicability rule deleted from: $($_.displayname) ($($_.id))"
      try {
          Invoke-MgGraphRequest -Method PATCH -Uri ("https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($_.id)") -Body ($bodyJson  | ConvertTo-Json)
      } catch {
          Write-Error "Failed to patch OS edition rule for $($_.displayname): $_"
      }

    }
    if(-not ($null -eq $_.DeviceManagementApplicabilityRuleOSVersion.RuleType)){
      $bodyJson = '{"deviceManagementApplicabilityRuleOsVersion" : null }' | ConvertFrom-Json
      $bodyJson | Add-Member -NotePropertyName "@odata.type" -NotePropertyValue $_.AdditionalProperties.'@odata.type'
      Write-Host "Applicability rule deleted from: $($_.displayname) ($($_.id))"
      try {
          Invoke-MgGraphRequest -Method PATCH -Uri ("https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($_.id)") -Body ($bodyJson  | ConvertTo-Json)
      } catch {
          Write-Error "Failed to patch OS version rule for $($_.displayname): $_"
      }
    }
}
