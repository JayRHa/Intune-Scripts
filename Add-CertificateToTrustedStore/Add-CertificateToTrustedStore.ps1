<#
.SYNOPSIS
    Import a certificate into the Intune Trusted Publisher certificate store.
.DESCRIPTION
    Creates an Intune custom configuration profile that imports a selected .cer
    certificate into the Trusted Publisher certificate store on Windows devices.
.NOTES
    Author : Jannik Reinhard
    Version: 1.3
#>

#Requires -Modules Microsoft.Graph.Authentication

Param()

function Connect-MgGraphIfNeeded {
    $context = Get-MgContext
    if (-not $context) {
        Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All" -NoWelcome
    }
}

function Get-Certificate {
    Add-Type -AssemblyName System.Windows.Forms
    $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $fileBrowser.filter = "Certificate (*.cer)| *.cer"
    [void]$fileBrowser.ShowDialog()
    return $fileBrowser.FileName
}

function Import-ConfigurationProfile {
    param(
        [Parameter(Mandatory)]
        $ConfigProfile
    )
    try {
        Write-Host $ConfigProfile
        Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations" -Method POST -Body $ConfigProfile -ContentType "application/json"
    }
    catch {
        Write-Error "Failed to import configuration profile: $_"
        throw
    }
}

# Auth
Connect-MgGraphIfNeeded

# Get certificate
$certificatePath = Get-Certificate
if ([string]::IsNullOrEmpty($certificatePath)) {
    Write-Error "No certificate file selected. Exiting."
    return
}

# Clean CR/LF from certificate content using a temp copy
$certContent = (Get-Content $certificatePath -Raw).Replace("`r","").Replace("`n","")
$tempCertPath = Join-Path $env:TEMP (Split-Path $certificatePath -Leaf)
$certContent | Set-Content $tempCertPath -NoNewline -Force

# Get name of the policy
$confProfileName = Read-Host "Enter a name for the configuration profile"

# Get needed information - create certificate object once
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($tempCertPath)
$certThumbprint = $cert.Thumbprint
$encodeCertificate = [System.Convert]::ToBase64String($cert.Export('Cert'), 'InsertLineBreaks')
$fileName = Split-Path $certificatePath -Leaf
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

Import-ConfigurationProfile -ConfigProfile $customConfigProfile
