<#
.SYNOPSIS
    Create test security groups in Entra ID (Azure AD)
.DESCRIPTION
    Connects to Microsoft Graph and creates a specified number of test security groups.
    Uses the Microsoft Graph PowerShell SDK (Connect-MgGraph / New-MgGroup) instead of
    the deprecated AzureAD module.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 2.0
#>

try {
    Connect-MgGraph -Scopes "Group.ReadWrite.All" -ErrorAction Stop

    $countOfTestGroups = 10

    for ($i = 0; $i -lt $countOfTestGroups; $i++) {
        New-MgGroup -DisplayName "zTestSecurityGroup$i" `
                    -SecurityEnabled `
                    -Description "Test group nr group $i" `
                    -MailEnabled:$false `
                    -MailNickname "NotSet" `
                    -ErrorAction Stop
    }

    Write-Host "Successfully created $countOfTestGroups test groups"
    exit 0
} catch {
    Write-Error "Failed to create test groups: $_"
    exit 1
}
