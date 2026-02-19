<#PSScriptInfo
.SYNOPSIS
    Generate and email a Windows 11 adoption report for Intune-managed devices.
.DESCRIPTION
    Connects to Microsoft Graph, retrieves all managed Windows devices, calculates
    Windows 11 adoption percentages, builds an HTML report with a pie chart and
    device table, and sends it as an email attachment.
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
    Release: v1.0 - Init
             v1.1 - Bug fixes, security improvements
#>

Add-Type -AssemblyName System.Web

# Variables
$MailTo = ""
$MailSender = ""

#################################################################################################
########################################### Start ###############################################
#################################################################################################

# Authenticate and connect to Microsoft Graph
Connect-AzAccount -Identity
$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"

Connect-MgGraph -AccessToken $token.Token


$devices = Get-MgDeviceManagementManagedDevice -All -Filter "contains(operatingSystem,'Windows')"
$windows11Devices = $devices | Where-Object { [System.Version]$_.OsVersion -ge [System.Version]"10.0.22000" }

# Calculate device counts
$totalDevices = $devices.Count
if ($totalDevices -eq 0) {
    Write-Error "No Windows devices found"
    return
}
$windows11DevicesCount = $windows11Devices.Count

# Calculate pie chart percentages
$windows11Percentage = ($windows11DevicesCount / $totalDevices) * 100
$otherWindowsPercentage = 100 - $windows11Percentage


# Create HTML report
$html = @"
<style>
    body {
        font-family: Arial, sans-serif;
    }
    h1 {
        font-size: 28px;
        color: #0078d4;
        margin-top: 0;
        text-align: center;
    }
    .chart-container {
        display: flex;
        flex-wrap: wrap;
        justify-content: center;
    }
    .pie-chart {
        width: 300px;
        height: 300px;
        margin: 20px;
    }
    .device-list {
        margin-top: 40px;
    }
    table {
        border-collapse: collapse;
        width: 100%;
    }
    th {
        background-color: #0078d4;
        color: #fff;
        font-weight: bold;
        padding: 8px;
        text-align: left;
    }
    td {
        border: 1px solid #ddd;
        padding: 8px;
    }
    tr:nth-child(even) {
        background-color: #f2f2f2;
    }
</style>
<h1>Windows 11 Adoption Report</h1>
<div class="chart-container">
    <div class="pie-chart">
        <canvas id="chart"></canvas>
    </div>
</div>
<div class="device-list">
    <table>
        <thead>
            <tr>
                <th>Device Name</th>
                <th>User</th>
                <th>Last Sync DateTime</th>
                <th>OSVersion</th>
            </tr>
        </thead>
        <tbody>
"@
foreach ($device in $devices) {
    $escapedName = [System.Web.HttpUtility]::HtmlEncode($device.DeviceName)
    $escapedEmail = [System.Web.HttpUtility]::HtmlEncode($device.EmailAddress)
    $html += "<tr><td>$escapedName</td><td>$escapedEmail</td><td>$($device.LastSyncDateTime)</td><td>$($device.OSVersion)</td></tr>"
}
$html += @"
        </tbody>
    </table>
</div>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
    var ctx = document.getElementById('chart').getContext('2d');
    var chart = new Chart(ctx, {
        type: 'pie',
    data: {
            labels: ['Windows 11', 'Other Windows'],
            datasets: [{
            backgroundColor: ['#0078d4', '#f2f2f2'],
            data: [$windows11Percentage, $otherWindowsPercentage]
            }]
            },
            options: {
            legend: {
            display: true,
            position: 'bottom',
            labels: {
            fontColor: '#333',
            fontSize: 14,
            padding: 16
            }
            }
            }
            });
            </script>
"@

$html | Out-File -FilePath "Windows11AdoptionReport.html"
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes(".\Windows11AdoptionReport.html"))

#Send Mail
$URLsend = "https://graph.microsoft.com/v1.0/users/$MailSender/sendMail"
$BodyJsonsend = @"
{
    "message": {
      "subject": "Intune error report",
      "body": {
        "contentType": "Text",
        "content": "Dear Admin, this Mail contains the Windows 11 Adoption report"
      },
      "toRecipients": [
        {
          "emailAddress": {
            "address": "$MailTo"
          }
        }
      ],
      "attachments": [
        {
          "@odata.type": "#microsoft.graph.fileAttachment",
          "name": "Windows11AdoptionReport.html",
          "contentType": "text/plain",
          "contentBytes": "$base64"
        }
      ]
    }
  }
"@

try {
    Invoke-MgRestMethod -Method POST -Uri $URLsend -Body $BodyJsonsend
} catch {
    Write-Error "Failed to send email report: $_"
}
