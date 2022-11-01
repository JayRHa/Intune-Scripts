<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Sync-DistributionGroupWithSecurityGroup
Description:
Sync a distribution group with an security group
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
        $apiUri
    )
    return Invoke-RestMethod -Uri https://graph.microsoft.com/beta/$apiUri -Headers $authToken -Method GET
}

#### Start#####
# Add the ExchangePowerShell automation functions

# Variables
$tenantId = Get-AutomationVariable -Name 'TenantId'
$clientId = Get-AutomationVariable -Name 'AppId'
$clientSecret = Get-AutomationVariable -Name 'AppSecret'

$certAppId = "CLIENTIDCERT"
$certThumprint = "THETHUMBPRINTOFTHE CERT"
$organisation = "YOURORGNAME.onmicrosoft.com"

$secGroupId = 'ID OF THE SEC GROUP'
$distGroupName = 'ABCTest'

# Authentication
$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

Connect-ExchangeOnline -CertificateThumbPrint $certThumprint -AppID $certAppId -Organization $organisation

(Get-GraphCall -apiUri "groups/$secGroupId/members").value | ForEach-Object {
    Add-DistributionGroupMember $distGroupName -Member $_.userPrincipalName
}