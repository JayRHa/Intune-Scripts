
<#PSScriptInfo
.VERSION 1.2
.GUID 15eada01-a5b3-44c6-bfa7-ed4f466330bb
.AUTHOR Jannik Reinhard
.COMPANYNAME
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI https://github.com/JayRHa/Intune-Scripts/tree/main/Add-CertificateToTrustedStore
.ICONURI
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Create intune configuration profile to import certificate to the trusted publisher certificate store  
.INPUTS
 None required
.OUTPUTS
 Configuration Profile in Intune
.NOTES
 Author: Jannik Reinhard (jannikreinhard.com)
 Twitter: @jannik_reinhard
 Release notes:
  Version 1.0: Init
  Version 1.1: Fix bug with lf and cr
  Version 1.2: Minor fixes
#> 
Param()

function Get-Certificate {
    #Select the cer file
    Add-Type -AssemblyName System.Windows.Forms
    $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $fileBrowser.filter = "Certificate (*.cer)| *.cer"
    [void]$fileBrowser.ShowDialog()
    return $fileBrowser.FileName
}

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

    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
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

function Import-ConfigurationProfile {
    param(
             [Parameter(Mandatory)]
             $ConfigProfile
       )
    #$profile = $ConfigProfile | Select-Object -Property * -ExcludeProperty id,createdDateTime,lastModifiedDateTime,version,supportsScopeTags
    #$profile = $ConfigProfile | ConvertTo-Json
    Write-Host $ConfigProfile
    Invoke-RestMethod -Uri https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations -Headers $authToken -Method Post -Body $ConfigProfile -ContentType "application/json" 
}


#Auth
if(-not $global:authToken){
    if($User -eq $null -or $User -eq ""){
    $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    Write-Host
    }
    $global:authToken = Get-AuthToken -User $User
}

# Get certificate
$certificatePath = Get-Certificate
((Get-Content $certificatePath -Raw).Replace("`r","").Replace("`n","")) | Set-Content $certificatePath -NoNewline -Force

# Get name of the policy
$confProfileName = Read-Host "Enter a name for the configuration profile"


# Get needed informations
$certThumbprint = ([System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certificatePath)).thumbprint
$encodeCertificate = [System.Convert]::ToBase64String(([System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certificatePath)).Export('Cert'), 'InsertLineBreaks')
$fileName = Split-Path $certificatePath -leaf
$omaUri = "./Device/Vendor/MSFT/RootCATrustedCertificates/TrustedPublisher/$certThumbprint/EncodedCertificate"

$customConfigProfile = @"
{
    "@odata.type": "#microsoft.graph.windows10CustomConfiguration",
    "description": "",
    "displayName": "$confProfileName",
    "omaSettings": [
        {
            "@odata.type": "#microsoft.graph.omaSettingString",
            "displayName": "$fileName",
            "description": "",
            "omaUri": "$omaUri",
            "value":  "$encodeCertificate"
        }
    ]
}
"@

Import-ConfigurationProfile  -ConfigProfile $customConfigProfile
