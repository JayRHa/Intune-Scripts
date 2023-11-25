<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Run-AssignPermissionsToManagedIdentity.ps1
Description:
Add permissions to an managed identity like azure function / automation
Release notes:
Version 1.0: Init
#> 

$managedIdentityId = ""
$roleName = "Device.Read.All" #Organization.Read.All

Install-Module Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes Application.Read.All, AppRoleAssignment.ReadWrite.All, RoleManagement.ReadWrite.Directory
$msgraph = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
$role = $Msgraph.AppRoles| Where-Object {$_.Value -eq $roleName} 
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityId -PrincipalId $managedIdentityId -ResourceId $msgraph.Id -AppRoleId $role.Id
Disconnect-MgGraph