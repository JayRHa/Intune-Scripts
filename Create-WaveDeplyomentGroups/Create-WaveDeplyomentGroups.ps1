<#
.SYNOPSIS
    Create wave deployment groups for Intune config rollouts
.DESCRIPTION
    Automatically create assignment groups for configuration rollouts by distributing
    devices across multiple groups based on percentage-based wave definitions.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.0
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
    try {
        return Invoke-RestMethod -Uri https://graph.microsoft.com/beta/$apiUri -Headers $authToken -Method GET
    } catch {
        Write-Error "Graph API call failed: $_"
        return $null
    }
}

function Get-GraphCallPaging {
    param(
        [Parameter(Mandatory)]
        $apiUri
    )

    $url = "https://graph.microsoft.com/beta/$apiUri"
    $results = @()

    do {
        try {
            $response = Invoke-RestMethod -Uri $url -Headers $authToken -Method GET
        } catch {
            Write-Error "Graph API paging call failed: $_"
            return $results
        }
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

    try {
        return (Invoke-RestMethod -Uri https://graph.microsoft.com/beta/groups -Headers $authToken -Method POST -Body ($body | ConvertTo-Json)).id
    } catch {
        Write-Error "Failed to create group '$groupName': $_"
        return $null
    }
}

function Add-Member {
    param(
        [Parameter(Mandatory)]$groupId,
        [Parameter(Mandatory)]$memberId
    )

    $body = '{ "@odata.id": "https://graph.microsoft.com/v1.0/directoryObjects/' + $memberId + '" }'

    try {
        $member = Invoke-RestMethod -Uri ("https://graph.microsoft.com/beta/groups/$groupId/members/" + '$ref') -Headers $authToken -Method POST -Body $body
    } catch {
        Write-Error "Failed to add member '$memberId' to group '$groupId': $_"
    }
}

function Add-Members {
    param(
        [Parameter(Mandatory)]$groupId,
        [Parameter(Mandatory)]$members
    )
    if($members.count -le 0){return}
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

if ([string]::IsNullOrEmpty($tenantId) -or [string]::IsNullOrEmpty($clientId) -or [string]::IsNullOrEmpty($clientSecret)) {
    Write-Error "Please configure tenantId, clientId and clientSecret"
    return
}

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
$devices = Get-GraphCallPaging -apiUri ("devices" + $filter)



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
