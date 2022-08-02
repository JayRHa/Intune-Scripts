
<#PSScriptInfo
.VERSION 1.0
.GUID 289544d2-0171-41b3-8dd3-8b37ca2c92d6
.AUTHOR Jannik Reinhard
.COMPANYNAME
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI https://github.com/JayRHa/Intune-Scripts/blob/main/Remove-ApplicabilityRule/Remove-ApplicabilityRule.ps1
.ICONURI
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Remove Applicability Rule via Graph 
.INPUTS
 None required
.OUTPUTS
 None
.NOTES
 Author: Jannik Reinhard (jannikreinhard.com)
 Twitter: @jannik_reinhard
 Release notes:
  Version 1.0: Init
#> 

Param()


function Get-GraphAuthentication{
    $GraphPowershellModulePath = "$global:Path/Microsoft.Graph.psd1"
    if (-not (Get-Module -ListAvailable -Name 'Microsoft.Graph')) {
  
        if (-Not (Test-Path $GraphPowershelModulePath)) {
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
