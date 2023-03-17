<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Create-WaveDeplyomentGroups
Description:
Automatically create assignment groups for config rollouts
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

function Get-GraphCall {
    param(
        [Parameter(Mandatory)]
        $apiUri
    )
    return Invoke-RestMethod -Uri https://graph.microsoft.com/beta/$apiUri -Headers $authToken -Method GET
}

function Get-GraphCallPaging {
    param(
        [Parameter(Mandatory)]
        $apiUri
    )

    $url = "https://graph.microsoft.com/beta/$apiUri"
    $results = @()

    do {
        $response = Invoke-RestMethod -Uri $url -Headers $authToken -Method GET
        $results += $response.value
        $url = $response.'@odata.nextLink'
    } while ($url)

    return $results
}


function Invoke-GroupCreation {
    param(
        [Parameter(Mandatory)]$groupName
    )
    $body = '{"description": "", "displayName": "", "groupTypes": [], "mailEnabled": false, "mailNickname": "",  "securityEnabled": true}' | ConvertFrom-Json
    $body.description = $groupName
    $body.displayName = $groupName
    $body.mailNickname = $groupName.replace(" ","")

    return (Invoke-RestMethod -Uri https://graph.microsoft.com/beta/groups -Headers $authToken -Method POST -Body ($body | ConvertTo-Json)).id
}

function Add-Member {
    param(
        [Parameter(Mandatory)]$groupId,
        [Parameter(Mandatory)]$memberId
    )

    $body = '{ "@odata.id": "https://graph.microsoft.com/v1.0/directoryObjects/' + $memberId + '" }'

    $member = Invoke-RestMethod -Uri ("https://graph.microsoft.com/beta/groups/$groupId/members/" + '$ref') -Headers $authToken -Method POST -Body $body
}

function Add-Members {
    param(
        [Parameter(Mandatory)]$groupId,
        [Parameter(Mandatory)]$members
    )
    if($devices.count -le 0){return}
    $members | ForEach-Object{
        Add-Member -groupId $groupId -memberId $_.id
    }
}
#################################################################################################
########################################### Start ###############################################
#################################################################################################
# Group.ReadWrite.All, Device.Read.All
####### Variables ###############################################################################
# Add values for tenantId, clientId and clientSecret
$tenantId = ''
$clientId = ''
$clientSecret = ''

# Distribution
$groups = @()
$groups += '{"GroupName" : "WIN-Apps-GroupFirstWave","Percent" : "20"}' | ConvertFrom-Json
$groups += '{"GroupName" : "WIN-Apps-GroupMidWave","Percent" : "30"}' | ConvertFrom-Json
$groups += '{"GroupName" : "WIN-Apps-GroupLastWave","Percent" : "50"}' | ConvertFrom-Json

# Filter
$filter = ''
#$filter = ('?$filter=operatingSystem eq ' + "'Windows'")
#################################################################################################

# Check Input
$sum = 0
$groups | ForEach-Object { $sum += $_.Percent}
if($sum -ne 100){
    Write-Error "The sum of the percentages are not 100"
    return
}

# Authentication
$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

# Get All devices
#$devices = (Get-GraphCall -apiUri ("devices" + $filter)).value
$devices = (Get-GraphCallPaging -apiUri ("devices" + $filter)).value



$memberCount = 0
foreach ($group in $groups) 
{
    if((Get-GraphCall -apiUri ('groups?$filter=startswith(displayName, ' +"'$($group.GroupName)')")).value){
        Write-Error "The defined group already exist"
        return
    }
    $groupId = Invoke-GroupCreation -groupName $($group.GroupName)

    if ($group -eq $groups[-1]){
        $count = $devices.count - $memberCount
        Add-Members -groupId $groupId -members $devices[$memberCount..($memberCount+$count-1)]
        return
    }
    $count = [math]::Round($devices.count * ($group.Percent/100))
    Add-Members -groupId $groupId -members $devices[$memberCount..($memberCount+$count-1)]
    $memberCount = $memberCount + $count
}
