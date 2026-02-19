<#
.SYNOPSIS
    Assign Microsoft Graph app roles to a managed identity.
.DESCRIPTION
    Grants a specified Graph API permission (e.g. Device.Read.All) to an
    Azure managed identity such as an Azure Function or Automation Account.
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
    Release: v1.0 - Init
             v1.1 - Added guard for empty identity, conditional module install, try/catch
#>

$managedIdentityId = ""
$roleName = "Device.Read.All" #Organization.Read.All

if ([string]::IsNullOrEmpty($managedIdentityId)) {
    Write-Error "Managed identity ID is not configured. Set `$managedIdentityId before running."
    exit 1
}

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser
}

try {
    Connect-MgGraph -Scopes Application.Read.All, AppRoleAssignment.ReadWrite.All, RoleManagement.ReadWrite.Directory
    $msgraph = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
    $role = $Msgraph.AppRoles | Where-Object { $_.Value -eq $roleName }
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityId -PrincipalId $managedIdentityId -ResourceId $msgraph.Id -AppRoleId $role.Id
}
catch {
    Write-Error "Failed to assign permissions: $_"
}
finally {
    Disconnect-MgGraph
}
