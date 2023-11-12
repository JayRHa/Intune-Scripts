<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-IMEChange
Description:
Get information if a new version of IME changed the default IME.
Release notes:
Version 1.0: Init
#>
# Create C:\temp directory if it doesn't exist
If (-not (Test-Path C:\temp)) {
  New-Item -Path C:\temp -ItemType Directory
}

If (-not (Test-Path C:\temp\IMEChangeChecker)) {
  New-Item -Path C:\temp\IMEChangeChecker -ItemType Directory
}

# Save the provided script in C:\temp
$scriptContent = @'
# Environment
$path = "C:\Program Files (x86)\Microsoft Intune Management Extension\*"
$type = @("*.dll", "*.exe")  # Use an array to specify multiple extensions

# Specify the path for the JSON file
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$jsonFilePath = Join-Path -Path $scriptDir -ChildPath "IMEChange.json"

# Get the files
$files = Get-ChildItem -Path $path -Include $type

# Function to compare two JSON files
function Compare-JsonFiles {
  param (
    [string]$jsonFilePath1,
    [string]$jsonContent2
  )

  $json1 = Get-Content -Path $jsonFilePath1 | ConvertFrom-Json
  $json2 = $jsonContent2 | ConvertFrom-Json

  # Compare the two JSON objects
  $jsonString1 = $json1 | ConvertTo-Json -Compress
  $jsonString2 = $json2 | ConvertTo-Json -Compress

  return $jsonString1 -eq $jsonString2
}

# Calculate the current file information
$currentJson = $files | ForEach-Object {
  $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256
  $lastWriteTime = $_.LastWriteTime
  $file = $_.Name
  [PSCustomObject]@{
    File          = $file
    Hash          = $hash.Hash
    LastWriteTime = $lastWriteTime
    Path          = $_.FullName
  }
} | ConvertTo-Json


if (Test-Path -Path $jsonFilePath) {
  $changeDetected = -not (Compare-JsonFiles -jsonFilePath1 $jsonFilePath -jsonContent2 $currentJson)

  if ($changeDetected) {
    Write-Host "Change detected!"

    $changedFilesListPath = Join-Path -Path $PSScriptRoot -ChildPath "ChangedFiles.html"
    $previousJson = Get-Content -Path $jsonFilePath | ConvertFrom-Json

    $changedFiles = Compare-Object -ReferenceObject $previousJson -DifferenceObject $($currentJson | ConvertFrom-Json) -Property Hash | Where-Object { $_.SideIndicator -eq '=>' } 
    $changedFiles = $($currentJson | ConvertFrom-Json) | Where-Object { $changedFiles.Hash -contains $_.Hash }

    # Styling for the HTML table
    $style = @"
<style>
  body {
      font-family: Arial, sans-serif;
      margin: 40px;
  }

  h1 {
      color: #444;
      margin-bottom: 20px;
  }

  table {
      border-collapse: collapse;
      width: 100%;
      margin-top: 20px;
      border: 1px solid #ddd;
  }

  th, td {
      text-align: left;
      padding: 8px;
      border-bottom: 1px solid #ddd;
  }

  tr:hover {
      background-color: #f5f5f5;
  }

  th {
      background-color: #4CAF50;
      color: white;
  }
</style>
"@

    # Convert the changed files to an HTML table
    $html = $changedFiles | ConvertTo-Html -Title "Changed Files" -PreContent "<h1>Changed Files</h1>" -PostContent $style -Property File, Hash, LastWriteTime, Path
    $html | Set-Content $changedFilesListPath


    $xml = @"
  <toast>
    <visual>
      <binding template="ToastGeneric">
        <text>New version of the IME was detected</text>
        <text>Click here to see the changed files.</text>
      </binding>
    </visual>
    <actions>
      <action content="Open Changes" activationType="protocol" arguments="file://$changedFilesListPath" />
    </actions>
  </toast>
"@
    $XmlDocument = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]::New()
    $XmlDocument.loadXml($xml)
    $AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::CreateToastNotifier($AppId).Show($XmlDocument)
  }
}
# Save the current JSON to the file
$currentJson | Set-Content -Path $jsonFilePath
'@

$scriptPath = "C:\temp\IMEChangeChecker\IMEChangeScript.ps1"
$scriptContent | Out-File -FilePath $scriptPath

# Create a scheduled task to run the saved script at every login
$TaskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File $scriptPath"
$TaskTrigger = New-ScheduledTaskTrigger -AtLogon
$TaskPrincipal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
$TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName "IMEChangeChecker" -Action $TaskAction -Trigger $TaskTrigger -Principal $TaskPrincipal -Settings $TaskSettings