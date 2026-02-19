<#
.SYNOPSIS
    Export an Intune report to CSV via the Graph Export API.
.DESCRIPTION
    Submits an export job for the specified report name, polls until complete,
    downloads the resulting ZIP and extracts it locally.
.NOTES
    Author : Jannik Reinhard
    Version: 1.1
#>

#Requires -Modules Microsoft.Graph.Authentication

function Connect-MgGraphIfNeeded {
    $context = Get-MgContext
    if (-not $context) {
        Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All" -NoWelcome
    }
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################
$reportName = 'DetectedAppsRawData'

# Auth
Connect-MgGraphIfNeeded

$body = @"
{
    "reportName": "$reportName",
    "localizationType": "LocalizedValuesAsAdditionalColumn"
}
"@

try {
    $id = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs" -Method POST -Body $body -ContentType "application/json").id
    $iteration = 0
    $maxIterations = 60
    $status = $null

    do {
        $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('$id')" -Method GET
        $status = $response.status
        if ($status -ne 'completed') {
            Start-Sleep -Seconds 2
            $iteration++
        }
    } while ($status -ne 'completed' -and $iteration -lt $maxIterations)

    if ($status -ne 'completed') {
        Write-Error "Export job timed out after $maxIterations polling attempts."
        return
    }

    Invoke-WebRequest -Uri $response.url -OutFile "./intuneExport.zip"
    Expand-Archive "./intuneExport.zip" -DestinationPath "./intuneExport"
}
catch {
    Write-Error "Failed to export report: $_"
    throw
}

## Copy the file to storage or do some actions
########
########
