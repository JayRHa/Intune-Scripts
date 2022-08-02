
<#PSScriptInfo
.VERSION 1.0
.GUID a74f64cf-dbd4-45fe-a8f4-c43e23394d45
.AUTHOR Jannik Reinhard
.COMPANYNAME
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI https://github.com/JayRHa/Intune-Scripts/blob/main/Get-AllAadGroupAssignments/Get-AllAadGroupAssignments.ps1
.ICONURI
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Get all intune assignments from an aad group
.INPUTS
 None required
.OUTPUTS
 Assignmments of an specific AAD Group
.NOTES
 Author: Jannik Reinhard (jannikreinhard.com)
 Twitter: @jannik_reinhard
 Release notes:
  Version 1.0: Init
#> 
Param()

function Get-AuthToken {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $User
    )

    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    $tenant = $userUpn.Host
    $AadModule = Get-Module -Name "AzureAD" -ListAvailable
    if ($AadModule -eq $null) {
        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    }

    $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    Add-Type -Path $adal
    Add-Type -Path $adalforms
    # [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    # [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$Tenant"

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
    $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
    $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result

      
    $authHeader = @{
        'Content-Type'='application/json'
        'Authorization'="Bearer " + $authResult.AccessToken
        'ExpiresOn'=$authResult.ExpiresOn
        }

    return $authHeader
}

function Get-GraphCall {
    param(
        [Parameter(Mandatory)]
        $apiUri,
        [Parameter(Mandatory)]
        $method
    )
    return Invoke-RestMethod -Uri https://graph.microsoft.com/beta/$apiUri -Headers $authToken -Method $method
}

function Get-AllAadGroup{
    $return = Get-GraphCall -apiUri "groups" -method "GET"
    $groups = $return.value
    while($return.'@odata.nextLink')
    {
        $return = Invoke-RestMethod -Uri $return.'@odata.nextLink' -Headers $authToken -Method "GET"
        $groups += $return.value
    }
    
    return $groups
}

function Check-GroupName{
    param(
        [Parameter(Mandatory)]
        $groupName,
        [Parameter(Mandatory)]
        $allGroups
    )

    if($groupName -eq "All users"){return $true}
    if($groupName -eq "All devices"){return $true}

    foreach ($group in $allGroups) {
        if($group.displayName -eq $aadGroupName) {
            return $true
        }
    }
    return $false
}

function Get-GroupId{
    param(
        [Parameter(Mandatory)]
        $groupName,
        [Parameter(Mandatory)]
        $allGroups
    )
    if($groupName -eq "All users"){return "acacacac-9df4-4c7d-9d50-4ef0226f57a9"}
    if($groupName -eq "All devices"){return "adadadad-808e-44e2-905a-0b7873a8a531"}

    foreach ($group in $groups) {
        if($group.displayName -eq $aadGroupName) {
            return $group.id
        }
    }
    return $null
}

function Get-GroupAssignments{
    param(
        [Parameter(Mandatory)]
        $groupId,
        [Parameter(Mandatory)]
        $uri,
        [Parameter(Mandatory)]
        $uriAssignment,
        [Parameter(Mandatory)]
        $type
        )
    #Device Configuration
    $configurations = (Get-GraphCall -apiUri "$uri/$type" -method "GET").value 
    $hasAssignment = $false
    
    foreach ($configuration in $configurations){
        $assignmentsInfo = (Get-GraphCall -apiUri ("$uri/$type/" + $configuration.id + "/$uriAssignment") -method "GET")

        if($uriAssignment -eq "groupAssignments"){$assignments = $assignmentsInfo.value}
        elseif($uriAssignment -eq "assignments"){$assignments = $assignmentsInfo.value.target }


        foreach($assignment in $assignments){
            # Include
            if($uriAssignment -eq "groupAssignments" -and $assignment.targetGroupId -eq $groupId -and (-not $assignment.excludeGroup)){
                Write-Host "+" $configuration.displayName
                $hasAssignment = $true
            }elseif($uriAssignment -eq "assignments" -and $assignment.groupId -eq $groupId -and $assignment.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget'){
                Write-Host "+" $configuration.displayName
                $hasAssignment = $true
            }elseif($uriAssignment -eq "assignments" -and $groupId -eq "acacacac-9df4-4c7d-9d50-4ef0226f57a9" -and $assignment.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget'){
                Write-Host "+" $configuration.displayName
                $hasAssignment = $true
            }elseif($uriAssignment -eq "assignments" -and $groupId -eq "adadadad-808e-44e2-905a-0b7873a8a531" -and $assignment.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget'){
                Write-Host "+" $configuration.displayName
                $hasAssignment = $true
            }
            
            # Exclude 
            if($uriAssignment -eq "groupAssignments" -and $assignment.targetGroupId -eq $groupId -and $assignment.excludeGroup){
                Write-Host "-" $configuration.displayName
                $hasAssignment = $true
            }elseif($uriAssignment -eq "assignments" -and $assignment.groupId -eq $groupId -and $assignment.'@odata.type' -eq '#microsoft.graph.exclusionGroupAssignmentTarget'){
                Write-Host "-" $configuration.displayName
                $hasAssignment = $true
            }
        }
    }
    return $hasAssignment
}


#########################################################################################################
############################################ Start ######################################################
#########################################################################################################
$countListGroups = 20

#Auth
if(-not $global:authToken){
    if($User -eq $null -or $User -eq ""){
    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host
    }
    $global:authToken = Get-AuthToken -User $User
}

# Get an check aad group
$aadGroupName = Read-Host "Enter the name of the AAD Group"
$groups = Get-AllAadGroup
$checkGroupName = Check-GroupName -groupName $aadGroupName -allGroups $groups


if(-not $checkGroupName){
    Write-Warning "Group $aadGroupName not found"
    Write-Host "------------------------------"
    Write-Host "Available Groups:" -ForegroundColor Yellow
    Write-Host " -  All users"
    Write-Host " -  All devices"

    $i = 0
    foreach ($group in $groups) {
        Write-Host " - " $group.displayName
        $i++
        if($i -gt $countListGroups -or $i -gt 100){
            Write-Warning "Open the Azure Ad Portal to see all group: https://portal.azure.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/AllGroups"
            break
        }
    }
    Write-Host "------------------------------"
    while(-not $checkGroupName)
    {
        $aadGroupName = Read-Host "Enter the name of the AAD Group"
        $checkGroupName = Check-GroupName -groupName $aadGroupName -allGroups $groups
    }
}
Write-Host "------------------------------"
$groupId = Get-GroupId -groupName $aadGroupName -allGroups $groups
Write-Host "Group name:" $aadGroupName -ForegroundColor Yellow
Write-Host "Group Id:" $groupId -ForegroundColor Yellow
Write-Host "------------------------------"

# Device Configuration
Write-Host "Device Configuration" -ForegroundColor Yellow
Write-Host "------------------------------"
$hasAssignment = Get-GroupAssignments -groupId $groupId -uri "deviceManagement" -type "deviceConfigurations" -uriAssignment "groupAssignments"
if(-not $hasAssignment) {Write-Host "No Assignment" -ForegroundColor green}
Write-Host "------------------------------"

# Administrative templates
Write-Host "Administrative Templates" -ForegroundColor Yellow
Write-Host "------------------------------"
$hasAssignment = Get-GroupAssignments -groupId $groupId -uri "deviceManagement" -type "groupPolicyConfigurations" -uriAssignment "assignments"
if(-not $hasAssignment) {Write-Host "No Assignment" -ForegroundColor green}
Write-Host "------------------------------"

# Device Compliance Policies
Write-Host "Device Compliance Policies" -ForegroundColor Yellow
Write-Host "------------------------------"
$hasAssignment = Get-GroupAssignments -groupId $groupId -uri "deviceManagement" -type "deviceCompliancePolicies" -uriAssignment "assignments"
if(-not $hasAssignment) {Write-Host "No Assignment" -ForegroundColor green}
Write-Host "------------------------------"

# Apps
Write-Host "Mobile Applications" -ForegroundColor Yellow
Write-Host "------------------------------"
$hasAssignment = Get-GroupAssignments -groupId $groupId -uri "deviceappmanagement" -type "mobileApps" -uriAssignment "assignments"
if(-not $hasAssignment) {Write-Host "No Assignment" -ForegroundColor green}
Write-Host "------------------------------"

# Scripts
Write-Host "Scripts" -ForegroundColor Yellow
Write-Host "------------------------------"
$hasAssignment = Get-GroupAssignments -groupId $groupId -uri "deviceManagement" -type "deviceManagementScripts" -uriAssignment "assignments"
if(-not $hasAssignment) {Write-Host "No Assignment" -ForegroundColor green}
Write-Host "------------------------------"
