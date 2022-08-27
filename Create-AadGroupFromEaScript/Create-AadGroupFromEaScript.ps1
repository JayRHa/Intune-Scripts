<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Create-AadGroupFromEaScript
Description:
Create AAD groups based on local attribute
Release notes:
Version 1.0: Init
#> 

function Get-AuthHeader{
    param (
        [parameter(Mandatory=$true)]$tenantId,
        [parameter(Mandatory=$true)]$clientId,
        [parameter(Mandatory=$true)]$clientSecret
       )
    
    $authBody=@{
        client_id=$clientId
        client_secret=$clientSecret
        scope="https://graph.microsoft.com/.default"
        grant_type="client_credentials"
    }

    $uri="https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $accessToken=Invoke-WebRequest -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $authBody -Method Post -ErrorAction Stop -UseBasicParsing
    $accessToken=$accessToken.content | ConvertFrom-Json

    $authHeader = @{
        'Content-Type'='application/json'
        'Authorization'="Bearer " + $accessToken.access_token
        'ExpiresOn'=$accessToken.expires_in
    }
    
    return $authHeader
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

    $group = Invoke-RestMethod -Uri  'https://graph.microsoft.com/v1.0/groups' -ContentType 'application/json' -Headers $authToken -Method POST -Body $bodyJson
    return $group
}

function Add-MemberToGroup{
    param(
        [Parameter(Mandatory = $true)]  
        $groupId,
        [Parameter(Mandatory = $true)]  
        $deviceId
      )

    $body = '{"@odata.id": "https://graph.microsoft.com/v1.0/directoryObjects/' + $deviceId + '"}'
    Invoke-RestMethod -Uri  ('https://graph.microsoft.com/v1.0/groups/'+ $groupId + '/members/$ref') -ContentType 'application/json' -Headers $authToken -Method POST -Body $body
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################
$scriptName = "WIN_Det_GetManufacture"
$groupPrefix = "Windows_All_Devices_"

# Variables
$tenantId = Get-AutomationVariable -Name 'TenantId'
$clientId = Get-AutomationVariable -Name 'AppId'
$clientSecret = Get-AutomationVariable -Name 'AppSecret'

# Authentication
$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

$uri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts?" + '$filter=' + "startswith(displayName,'$scriptName')"
$result = Invoke-RestMethod -Uri $uri -Headers $authToken -Method GET

$scriptId= $result.value[0].id

$uri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts" + "/$scriptId/deviceRunStates/" + '?$expand=*'
$result = Invoke-RestMethod -Uri $uri -Headers $authToken -Method GET

$result.value | ForEach-Object {
    $groupName = $groupPrefix + $_.preRemediationDetectionScriptOutput
    $deviceId = $_.managedDevice.id
    $deviceName = $_.managedDevice.deviceName 

    #Check if group exist
    $uri = "https://graph.microsoft.com/beta/groups?" + '$filter=' +"startswith(displayName,'$groupName')"
    $result = Invoke-RestMethod -Uri $uri -Headers $authToken -Method GET
    if($result.value){$groupId = $result.value[0].id}
    else{
        $result = Add-MgtGroup -groupName $groupName -groupDescription "All $($_.preRemediationDetectionScriptOutput) devices (auto created via azure automation)"
        $groupId = $result.id
    }
    $uri = "https://graph.microsoft.com/beta/devices?" + '$filter=' + "startswith(displayName,'$deviceName')"
    $result = Invoke-RestMethod -Uri $uri -Headers $authToken -Method GET
    $deviceId = $($result.value[0].id)
    
    $uri = 'https://graph.microsoft.com/v1.0/groups/' + $groupId + '/members'
    $result = ((Invoke-RestMethod -Uri $uri -Headers $authToken -Method GET).value | Where-Object {$_.id -eq $deviceId})

    if(-not $result){
        Add-MemberToGroup -groupId $groupId -deviceId $deviceId
    }
}

