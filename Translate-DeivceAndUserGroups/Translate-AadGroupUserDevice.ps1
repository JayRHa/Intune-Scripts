
<#PSScriptInfo
.VERSION 1.0
.GUID e58f9c57-2652-4e17-9676-d6aa4e78cd8b
.AUTHOR Jannik Reinhard
.COMPANYNAME
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI https://github.com/JayRHa/Intune-Scripts/blob/main/Translate-DeivceAndUserGroups/Translate-AadGroupUserDevice.ps1
.ICONURI
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Change a user group to a device group based on the device primary contact 
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

function Get-AllGroupMember {
    param(
      [Parameter(Mandatory = $true)]  
      $groupName
    )
    $groupId = (Get-MgGroup -Filter "displayname eq '$groupName'").id
    $groupMembers = Get-MgGroupMember -GroupId $groupId
    $groupMembers = $groupMembers | Sort-Object -Property AdditionalProperties.displayName
    $items = @()
  
    $groupMembers | ForEach-Object {
        if($_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.user'){
            $param = [PSCustomObject]@{
                ItemName                        = $_.AdditionalProperties.displayName
                ItemType                        = "User"
                Id                              = $_.Id
                Uri                             = "https://graph.microsoft.com/v1.0/directoryObjects/" + $_.Id
            }
            $items += $param
        } elseif ($_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.device') {
            $param = [PSCustomObject]@{
                ItemName                        = $_.AdditionalProperties.displayName 
                ItemType                        = "Device"
                Id                              = $_.Id
                Uri                             = "https://graph.microsoft.com/v1.0/directoryObjects/" + $_.Id
            }
            $items += $param
        } elseif ($_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group') {
            $colornumber= Get-Random -Maximum 9
            $param = [PSCustomObject]@{
                ItemName                        =  $_.AdditionalProperties.displayName
                ItemType                        = "Group"
                Id                              = $_.Id
                Uri                             = "https://graph.microsoft.com/v1.0/directoryObjects/" + $_.Id
            }
            $items += $param
        }
      }
    return @($items)
}


function Get-MigrateGroupMember{
    param (
        [String]$migrationType,
        [array]$groupMember = $null,
        $windows = $true,
        $ios = $true,
        $macos = $true,
        $android = $true
    )

    $os = @()
    if($windows){$os += 'Windows'}
    if($macos){$os += 'MacMDM'}
    if($android){$os += 'Android'}
    if($ios){$os += 'IOS'}
    
    $newGroupMember = @()

    if($migrationType -eq 'User'){
        $groupMember | Where-Object {$_.ItemType -eq 'Device'} | Foreach-Object {
            $userId = (Get-MgDeviceRegisteredOwner -DeviceId $_.Id).Id
            if($userId){
                $newGroupMember += [PSCustomObject]@{
                    Uri = "https://graph.microsoft.com/v1.0/directoryObjects/" + $userId 
                }  
            }
        }
        $groupMember  | Where-Object {$_.ItemType -eq 'User'} | Foreach-Object {
            $newGroupMember += [PSCustomObject]@{
                Uri             = $_.Uri
            }
        }
    }elseif($migrationType -eq 'Device'){
        $groupMember  | Where-Object {$_.ItemType -eq 'User'} | Foreach-Object {

            (Get-MgUserOwnedDevice -UserId $_.Id) | ForEach-Object {
                $newGroupMember += [PSCustomObject]@{
                    Uri             = "https://graph.microsoft.com/v1.0/directoryObjects/" + $_.Id
                    OperatinSystem  = $_.AdditionalProperties.operatingSystem
                }
            }                        
        }
        $groupMember  | Where-Object {$_.ItemType -eq 'Device'} | Foreach-Object {
            $newGroupMember += [PSCustomObject]@{
                Uri             = $_.Uri
                OperatinSystem  = $_.OperatinSystem
            }
        }
        $newGroupMember = $newGroupMember | Where-Object {$_.OperatinSystem -in $os}
    }
    $newGroupMember = $newGroupMember | Sort-Object -Property uri -Uniqu 
    return $newGroupMember
}

function Get-AllAadGroup{
    return Get-MgGroup -All
}

function Check-GroupName{
    param(
        [Parameter(Mandatory)]
        $groupName,
        [Parameter(Mandatory)]
        $allGroups
    )

    foreach ($group in $allGroups) {
        if($group.displayName -eq $groupName) {
            return $true
        }
    }
    return $false
}

function Add-MgtGroup{
    param (
        [Parameter(Mandatory = $true)]
        [String]$groupName,
        [String]$groupDescription = $null,
        [array]$groupMember = $null
    )
    $bodyJson = @'
    {
        "displayName": "",
        "groupTypes": [],
        "mailEnabled": false,
        "mailNickname": "NotSet",
        "securityEnabled": true
    }
'@ | ConvertFrom-Json

    $bodyJson.displayName = $groupName

    if($groupDescription){
        $bodyJson | Add-Member -NotePropertyName description -NotePropertyValue $groupDescription
    } 
    
    if($groupMember.Length -gt 0){
        $bodyJson | Add-Member -NotePropertyName 'members@odata.bind' -NotePropertyValue @($groupMember.uri)
    }

    $bodyJson = $bodyJson | ConvertTo-Json
    New-MgGroup -BodyParameter $bodyJson
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################
$countListGroups = 20

Get-GraphAuthentication | Out-Null

# Get an check aad group
$aadGroupName = Read-Host "Enter the name of the AAD Group"
$groups = Get-AllAadGroup
$checkGroupName = Check-GroupName -groupName $aadGroupName -allGroups $groups

if(-not $checkGroupName){
    Write-Warning "Group $aadGroupName not found"
    Write-Host "------------------------------"
    Write-Host "Available Groups:" -ForegroundColor Yellow

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

$migrationType = Read-Host -Prompt "Enter the migration type. Do you want to move the group to a user group or device group? [Device, User]"
while("device", "Device", "user", "User" -notcontains $migrationType )
{
    $migrationType = Read-Host -Prompt "Enter the migration type. Do you want to move the group to a user group or device group? [Device, User]"
}
$groupName = Read-Host -Prompt "Enter the name of the new group"


$windows = $false
$android = $false
$iOS = $false
$macOs = $false
if($migrationType -eq "Device"){
    $answer = Read-Host -Prompt "Do you want to migrate Windows Devices? [Y/N]"
    while("Y", "N", "Yes", "No", "y", "n" -notcontains $answer )
    {
        $answer = Read-Host -Prompt "Do you want to migrate Windows Devices? [Y/N]"
    }
    if("Y", "Yes", "y" -contains $answer){$windows = $true}

    $answer = Read-Host -Prompt "Do you want to migrate Android Devices? [Y/N]"
    while("Y", "N", "Yes", "No", "y", "n" -notcontains $answer )
    {
        $answer = Read-Host -Prompt "Do you want to migrate Android Devices? [Y/N]"
    }
    if("Y", "Yes", "y" -contains $answer){$android = $true}

    $answer = Read-Host -Prompt "Do you want to migrate iOS Devices? [Y/N]"
    while("Y", "N", "Yes", "No", "y", "n" -notcontains $answer )
    {
        $answer = Read-Host -Prompt "Do you want to migrate iOS Devices? [Y/N]"
    }
    if("Y", "Yes", "y" -contains $answer){$iOS = $true}

    $answer = Read-Host -Prompt "Do you want to migrate MacOs Devices? [Y/N]"
    while("Y", "N", "Yes", "No", "y", "n" -notcontains $answer )
    {
        $answer = Read-Host -Prompt "Do you want to migrate MacOs Devices? [Y/N]"
    }
    if("Y", "Yes", "y" -contains $answer){$macOs = $true}
}

$allGroupMember = Get-AllGroupMember -groupName $aadGroupName

$groupMember = Get-MigrateGroupMember -migrationType $migrationType -groupMember $allGroupMember -windows $windows -ios $iOS -macos $macOs -android $android
Add-MgtGroup -groupName $groupName -groupDescription " " -groupMember $groupMember