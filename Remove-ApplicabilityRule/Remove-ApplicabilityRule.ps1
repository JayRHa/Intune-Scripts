<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Remove-ApplicabilityRule
Description:
Remove Applicability Rule via Graph
Release notes:
Version 1.0: Init
#>

function Get-GraphAuthentication{
    $GraphPowershellModulePath = "$global:Path/Microsoft.Graph.psd1"
    if (-not (Get-Module -ListAvailable -Name 'Microsoft.Graph')) {
  
        if (-Not (lTest-Path $GraphPowershelModulePath)) {
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
  
    try
    { 
        Import-Module -Name Microsoft.Graph.Intune -ErrorAction Stop
    } 
    catch
    {
        Write-Output "Module Microsoft.Graph.Intune was not found, try to installing in for the current user..."
        Install-Module -Name Microsoft.Graph.Intune -Scope CurrentUser -Force
        Import-Module Microsoft.Graph.Intune -Force
    }
  
    try {
      Connect-MgGraph -Scopes "User.Read.All","Group.ReadWrite.All","DeviceManagementApps.Read.All", "Device.Read.All", "DeviceManagementApps.ReadWrite.All"
    } catch {
      Write-Error "Failed to connect to MgGraph"
      return $false
    }
    
    try {
      Connect-MSGraph -AdminConsent -ErrorAction Stop
    } catch {
      Write-Error "Failed to connect to MSGraph"
      return $false
    }
    Select-MgProfile -Name "beta"
    return $true
  }
#################################################################################################
########################################### Start ###############################################
#################################################################################################
Get-GraphAuthentication | Out-Null

Get-MgDeviceManagementDeviceConfiguration | ForEach-Object {
    if(-not ($_.DeviceManagementApplicabilityRuleOSEdition.RuleType -eq $null)){
      $bodyJson = '{ "deviceManagementApplicabilityRuleOsEdition": null}' | ConvertFrom-Json
      $bodyJson | Add-Member -NotePropertyName "@odata.type" -NotePropertyValue $_.AdditionalProperties.'@odata.type'
      Write-host "Applicability rule deleted form: $($_.displayname) ($($_.id))"
      Invoke-MgGraphRequest -Method PATCH -Uri ("https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($_.id)") -Body ($bodyJson  | ConvertTo-Json)

    }
    if(-not ($_.DeviceManagementApplicabilityRuleOSVersion.RuleType -eq $null)){
      $bodyJson = '{"deviceManagementApplicabilityRuleOsVersion" : null }' | ConvertFrom-Json
      $bodyJson | Add-Member -NotePropertyName "@odata.type" -NotePropertyValue $_.AdditionalProperties.'@odata.type'
      Write-host "Applicability rule deleted form: $($_.displayname) ($($_.id))"
      Invoke-MgGraphRequest -Method PATCH -Uri ("https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($_.id)") -Body ($bodyJson  | ConvertTo-Json)
    }
}
