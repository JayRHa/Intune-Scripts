param (
  [parameter(HelpMessage = "Collect new logs")]
  [ValidateNotNullOrEmpty()]
  [switch]$collectNew=$false,
  [parameter(Mandatory=$true, HelpMessage = "Typle of logs")]
  [ValidateSet('all','systemInformation', 'enrollment')]
  [string[]]$output="all"
)

#################################################################################################
######################################## Function ###############################################
#################################################################################################
Function Get-CheckIfLogExist{
  param([string]$path)
  return Test-Path -Path $path
}

Function Write-ValueOutFromObject{
  param(
    [string]$header,
    [PSCustomObject]$object
  )

  $lenght = $header.Length + 33
  
  for($i=0; $i -le $lenght;$i++){Write-Host "#" -NoNewline -ForegroundColor Yellow}
  Write-Host
  Write-Host "################ $header ################" -ForegroundColor Yellow
  for($i=0; $i -le $lenght;$i++){Write-Host "#" -NoNewline -ForegroundColor Yellow}
  Write-Host

  $object.PSObject.Properties | ForEach-Object {
    Write-Host "- $($_.Name): " -NoNewline -ForegroundColor Black
    Write-Host $_.Value
  } 
}

Function Get-MdmSystemInformation{
  param([xml]$xmlLog)

  $object = [PSCustomObject]@{
    "Report Creation Time" = $xmlLog.MDMEnterpriseDiagnosticsReport.SystemInformation.ReportCreationTime
    "OS Version" =  $xmlLog.MDMEnterpriseDiagnosticsReport.SystemInformation.OSVersion
    "Serial number" = $xmlLog.MDMEnterpriseDiagnosticsReport.SystemInformation.SerialNumber
    "Build Branch" = $xmlLog.MDMEnterpriseDiagnosticsReport.SystemInformation.BuildBranch
  }

  return  $object
}

Function Get-MdmEnrollmentInfo{

}

#################################################################################################
########################################### Start ###############################################
#################################################################################################
$logPath = "c:\temp\diagnostic"
if(-not ((Get-CheckIfLogExist -path $logPath) -or $collectNew)){
  MdmDiagnosticsTool.exe -out $logPath
}

[xml]$logFile = Get-Content -Path "$logPath/MDMDiagReport.xml"

# Write output
if($output -contains "all" -or $output -contains "systemInformation") {
  Write-ValueOutFromObject -header "System Information" -object $(Get-MdmSystemInformation -xmlLog $logFile)
}

