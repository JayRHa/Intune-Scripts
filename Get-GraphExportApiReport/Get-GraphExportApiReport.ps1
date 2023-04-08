<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-GraphExportApiReport
Description:
Get an CSV Report from the Graph API
Release notes:
Version 1.0: Init
#> 
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

#################################################################################################
########################################### Start ###############################################
#################################################################################################
$reportName = 'DetectedAppsRawData'


#Get auth toke
if(-not $global:authToken.Authorization){
    if($User -eq $null -or $User -eq ""){
    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host
    }
    $global:authToken = Get-AuthToken -User $User
}

$body = @"
{ 
    "reportName": "$reportName", 
    "localizationType": "LocalizedValuesAsAdditionalColumn"
} 
"@


$id = (Invoke-RestMethod -Uri https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs -Headers $authToken -Method POST -Body $body).id
$status = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('$id')" -Headers $authToken -Method GET).status

while (-not ($status -eq 'completed')) {
    $response = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('$id')" -Headers $authToken -Method Get
    $status = ($response).status
    Start-Sleep -Seconds 2
}

Invoke-WebRequest -Uri $response.url -OutFile "./intuneExport.zip"
Expand-Archive "./intuneExport.zip" -DestinationPath "./intuneExport" 

## Copy the file to an storage or do some actions
########
########
