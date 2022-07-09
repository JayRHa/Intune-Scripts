<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Create-AssignmentGroupsForApps
Description:
Automatically  create assignment groups when a app is created
Release notes:
Version 1.0: Init
#> 
Function Get-AuthHeader{
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

function Get-GraphCall {
    param(
        [Parameter(Mandatory)]
        $apiUri,
        [Parameter(Mandatory)]
        $method
    )
    return Invoke-RestMethod -Uri https://graph.microsoft.com/beta/$apiUri -Headers $authToken -Method $method
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

function Add-GroupToApp {
    param(
        [Parameter(Mandatory = $true)]  
        $groupId,
        [Parameter(Mandatory = $true)]  
        $appId,
        [parameter(Mandatory=$true)]
        [string]$assignment,
        [parameter(Mandatory=$true)]
        [string]$intent
      )
    $bodyJson = @'
      {
        "@odata.type": "#microsoft.graph.mobileAppAssignment",
        "intent": "",
        "target": {
            "@odata.type" :"#microsoft.graph.groupAssignmentTarget",
            "groupId": ""
        }
      }
'@ | ConvertFrom-Json

    $bodyJson.target.groupId = $groupId
    $bodyJson.intent = $intent
    Invoke-RestMethod -Uri ("https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/assignments") -ContentType 'application/json' -Headers $authToken -Method POST -Body ($bodyJson | ConvertTo-Json)
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################
# Variables
$tenantId = Get-AutomationVariable -Name 'TenantId'
$clientId = Get-AutomationVariable -Name 'AppId'
$clientSecret = Get-AutomationVariable -Name 'AppSecret'
$groupsPost = @("Available", "Required", "Uninstall")
$groupPrefix = "App"

# Authentication
$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

# Get logs form the last hour
$time = ((Get-Date).ToUniversalTime()).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ssZ")
$logs = Invoke-RestMethod -Uri  ('https://graph.microsoft.com/beta/deviceManagement/auditEvents?$filter=%20activityDateTime%20gt%20'+$time)  -Headers $authToken -Method GET

# Create groups and add to app
$logs.value | ForEach-Object {
    if($_.activityType -eq 'Create MobileApp' -and $_.activityResult -eq 'Success'){
        $appId = $_.resources.resourceId
        $appName = $_.resources.displayName
        $groups = @()
        foreach($groupPost in $groupsPost){
            $groups += Add-MgtGroup -groupName ("$groupPrefix-$appName-$groupPost")
        }
        foreach($group in $groups){
            $intent = $null
            if($group.displayName -like "*Available"){$intent = 'available'}
            elseif($group.displayName -like "*Required"){$intent = 'required'}
            elseif($group.displayName -like "*Uninstall"){$intent = 'uninstall'}

            Add-GroupToApp -groupId $group.id -appId $appId -assignment 'Include' -intent $intent 
        }
    }
}