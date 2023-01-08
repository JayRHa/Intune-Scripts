param (
  [parameter(HelpMessage = "Collect new logs")]
  [ValidateNotNullOrEmpty()]
  [switch]$collectNew=$false,
  [parameter(Mandatory=$true, HelpMessage = "Typle of logs")]
  [ValidateSet('all','systemInformation', 'enrollment', 'devMgmtAccount', 'policies')]
  [string[]]$output="all"
)

#################################################################################################
######################################## Function ###############################################
#################################################################################################
Function Get-CheckIfLogExist{
  param([string]$path)
  return Test-Path -Path $path
}

Function Write-InitHeader {
    param(
      [string]$header,
    )
  $lenght = $header.Length + 33
  
  for($i=0; $i -le $lenght;$i++){Write-Host "#" -NoNewline -ForegroundColor Yellow}
  Write-Host
  Write-Host "################ $header ################" -ForegroundColor Yellow
  for($i=0; $i -le $lenght;$i++){Write-Host "#" -NoNewline -ForegroundColor Yellow}
  Write-Host
}

Function Write-ValueOutFromObject{
  param(
    [string]$header,
    [PSCustomObject]$object
  )

  Write-InitHeader -header $header
  
  $object.PSObject.Properties | ForEach-Object {
    Write-Host "- $($_.Name): " -NoNewline -ForegroundColor Black
    Write-Host $_.Value
  } 
}

Function Get-MdmSystemInformation{
  param([xml]$xmlLog)

  return = [PSCustomObject]@{
    "Report Creation Time" = $xmlLog.MDMEnterpriseDiagnosticsReport.SystemInformation.ReportCreationTime
    "OS Version" =  $xmlLog.MDMEnterpriseDiagnosticsReport.SystemInformation.OSVersion
    "Serial number" = $xmlLog.MDMEnterpriseDiagnosticsReport.SystemInformation.SerialNumber
    "Build Branch" = $xmlLog.MDMEnterpriseDiagnosticsReport.SystemInformation.BuildBranch
  }
}

Function Get-MdmEnrollmentInfo{
  param([xml]$xmlLog)
  $enrollment = ($xmlLog.MDMEnterpriseDiagnosticsReport.Enrollments | Where-Object {$_.DMServerCertificateThumbprint})[0]

  return = [PSCustomObject]@{
    "Enrollment Id" = $enrollment.EnrollmentId
    "Enrollment Syste" = $enrollment.EnrollmentState
    "Enrollment Type" = $enrollment.EnrollmentType
    "Cur Crypto Provider" = $enrollment.CurCryptoProvider
    "Discovery Service FullURL" = $enrollment.DiscoveryServiceFullURL
    "DM Server Certificate Thumbprint" = $enrollment.DMServerCertificateThumbprint
    "Is Federated" = $enrollment.IsFederated
    "Provider ID" = $enrollment.ProviderID
    "Renewal Period" = $enrollment.RenewalPeriod
    "Renewal Error Code" = $enrollment.RenewalErrorCode
    "Renewal ROBO Support" = $enrollment.RenewalROBOSupport
    "Renewal Status" = $enrollment.RenewalStatus
    "Retry Interval" = $enrollment.RetryInterval
    "Root Certificate ThumbPrint" = $enrollment.RootCertificateThumbPrint

    "DM Client Servername" = $enrollment.DMClient.DMClientServerName
    "Cert Renew Timestamp" = $enrollment.DMClient.CertRenewTimeStamp
    "Enterprise Devicename" = $enrollment.DMClient.EnterpriseDeviceName
    "Enterprise DeviceManagement ID" = $enrollment.DMClient.EnterpriseDeviceManagementID
    "Signed Enterprise DeviceManagement ID" = $enrollment.DMClient.SignedEnterpriseDeviceManagementID

    "Poll Settings" = $enrollment.Poll.PollSettings
    "Aux Retry Interval" = $enrollment.Poll.AuxRetryInterval
    "Aux Num Retries" = $enrollment.Poll.AuxNumRetries
    "Retry Interval" = $enrollment.Poll.RetryInterval
    "Num Retries" = $enrollment.Poll.NumRetries
    "Aux2 Retry Interval" = $enrollment.Poll.Aux2RetryInterval
    "Aux2 Num Retries" = $enrollment.Poll.Aux2NumRetries
    "Poll On Login" = $enrollment.Poll.PollOnLogin
    "All Users Poll On First Login" = $enrollment.Poll.AllUsersPollOnFirstLogin

    "Device First Sync Status" = $enrollment.FirstSync.DeviceFirstSyncStatus
    "Sync Failure Timeout" = $enrollment.FirstSync.SyncFailureTimeout
    "Block In Status Page" = $enrollment.FirstSync.BlockInStatusPage
    "Skip Device Status Page" = $enrollment.FirstSync.SkipDeviceStatusPage
    "Skip User Status Page" = $enrollment.FirstSync.SkipUserStatusPage
    "Allow Collect Logs Button" = $enrollment.FirstSync.AllowCollectLogsButton
    "Timestamp" = $enrollment.FirstSync.Timestamp
    "Policy Duration" = $enrollment.FirstSync.PolicyDuration
    "Certificates Duration" = $enrollment.FirstSync.CertificatesDuration
    "Applications Duration" = $enrollment.FirstSync.ApplicationsDuration
    "Networking Duration" = $enrollment.FirstSync.NetworkingDuration
    "Is Server Provisioning Done" = $enrollment.FirstSync.IsServerProvisioningDone
    "Provisioning Status" = $enrollment.FirstSync.ProvisioningStatus
    "Is Sync Done" = $enrollment.FirstSync.IsSyncDone

    "User SID" = $enrollment.UserFirstSync.UserSID

    "Push" = $enrollment.Push.Push
    "PFN" = $enrollment.Push.PFN
    "Channel URI" = $enrollment.Push.ChannelURI
    "Status" = $enrollment.Push.Status
    "Device Channel" = $enrollment.Push.DeviceChannel
    "Retry Count" = $enrollment.Push.RetryCount
  }
}

Function Get-MdmDeviceManagementAccount{
  param([xml]$xmlLog)
  $deviceManagementAccount = $xmlLog.MDMEnterpriseDiagnosticsReport.DeviceManagementAccount.Enrollment

  return = [PSCustomObject]@{
    "Enrollment Id" = $deviceManagementAccount.EnrollmentId
    "Account UID" = $deviceManagementAccount.AccountUID
    "Flags" = $deviceManagementAccount.Flags
    "OMADM Protocol Version" = $deviceManagementAccount.OMADMProtocolVersion
    "Roaming Count" = $deviceManagementAccount.RoamingCount
    "MDM Server Version" = $deviceManagementAccount.MDMServerVersion
    "Ssl Client Cert Reference" = $deviceManagementAccount.SslClientCertReference

    "Protected Data" = $deviceManagementAccount.ProtectedInformation.ProtectedData
    "DMAccount Root Name" = $deviceManagementAccount.ProtectedInformation.DMAccountRootName
    "Application ID" = $deviceManagementAccount.ProtectedInformation.ApplicationID
    "Authentication Preference" = $deviceManagementAccount.ProtectedInformation.AuthenticationPreference
    "Default Encoding" = $deviceManagementAccount.ProtectedInformation.DefaultEncoding
    "Mode" = $deviceManagementAccount.ProtectedInformation.Mode
    "MDM Server Name" = $deviceManagementAccount.ProtectedInformation.MDMServerName
    "Roles" = $deviceManagementAccount.ProtectedInformation.Roles
    "Provider ID" = $deviceManagementAccount.ProtectedInformation.ProviderID
    "Ssl Client Cert Search Criteria" = $deviceManagementAccount.ProtectedInformation.SslClientCertSearchCriteria

    "Address Information" = $deviceManagementAccount.ProtectedInformation.AddressInformation.AddressInformation
    "Address" = $deviceManagementAccount.ProtectedInformation.AddressInformation.Address
    "Address Root Name" = $deviceManagementAccount.ProtectedInformation.AddressInformation.AddressRootName
    "Address Type" = $deviceManagementAccount.ProtectedInformation.AddressInformation.AddressType
    "Flags" = $deviceManagementAccount.ProtectedInformation.AddressInformation.Flags

    "AuthInfo ID" = $deviceManagementAccount.ProtectedInformation.AuthenticationInformation.AuthInfoID
    "Authentication Level" = $deviceManagementAccount.ProtectedInformation.AuthenticationInformation.AuthenticationLevel
    "Authentication Root Name" = $deviceManagementAccount.ProtectedInformation.AuthenticationInformation.AuthenticationRootName
    "Authentication Secret" = $deviceManagementAccount.ProtectedInformation.AuthenticationInformation.AuthenticationSecret
    "Authentication Type" = $deviceManagementAccount.ProtectedInformation.AuthenticationInformation.AuthenticationType
    
    "ConnectionInfo ID" = $deviceManagementAccount.ProtectedInformation.ConnectionInformation.ConnectionInfoID
    "Back Compat Retry Disabled" = $deviceManagementAccount.ProtectedInformation.ConnectionInformation.BackCompatRetryDisabled
    "Conn Retry Freq" = $deviceManagementAccount.ProtectedInformation.ConnectionInformation.ConnRetryFreq
    "Flags" = $deviceManagementAccount.ProtectedInformation.ConnectionInformation.Flags
    "Initial Back Off Time" = $deviceManagementAccount.ProtectedInformation.ConnectionInformation.InitialBackOffTime
    "Last Session Result" = $deviceManagementAccount.ProtectedInformation.ConnectionInformation.LastSessionResult
    "Max Back Off Time" = $deviceManagementAccount.ProtectedInformation.ConnectionInformation.MaxBackOffTime
    "Server Last Access Time" = $deviceManagementAccount.ProtectedInformation.ConnectionInformation.ServerLastAccessTime
    "Server Last Failure Time" = $deviceManagementAccount.ProtectedInformation.ConnectionInformation.ServerLastFailureTime
    "Server Last Success Time" = $deviceManagementAccount.ProtectedInformation.ConnectionInformation.ServerLastSuccessTime
  }
}


Function Get-MdmPolicies{
  param([xml]$xmlLog)
  $policies = $xmlLog.MDMEnterpriseDiagnosticsReport.PolicyManager

  $allPolicies =  @()
  $policies | ForEach {
    $allPolicies += [PSCustomObject]@{
      "Enrollment Id" = $_.ConfigSource.EnrollmentId
      "Scope" = $_.ConfigSource.PolicyScope.PolicyScope
      "Area" = $_.ConfigSource.PolicyScope.Area
      #ToDo: Split area
    }
  }
  return $allPolicies
}

Function Get-MdmRessources{
  param([xml]$xmlLog)s
  #? For each scope
  $ressources = $xmlLog.MDMEnterpriseDiagnosticsReport.Resources.Enrollment.Scope.Resources
  #ToDo: For each 

}

Function Get-MdmEas{
  param([xml]$xmlLog)
  $eas = $xmlLog.MDMEnterpriseDiagnosticsReport.EAS.EASPolicies

  return = [PSCustomObject]@{
    "Type" = $eas.Type
    "Min Device Password Complex Characters" = $eas.MinDevicePasswordComplexCharacters
    "Min Device Password Length" = $eas.MinDevicePasswordLength
    "Max Device Password Failed Attempts" = $eas.MaxDevicePasswordFailedAttempts
  }
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
#### System Information ###
if($output -contains "all" -or $output -contains "systemInformation") {
  Write-ValueOutFromObject -header "System Information" -object $(Get-MdmSystemInformation -xmlLog $logFile)
}

if($output -contains "all" -or $output -contains "enrollment") {
  Write-ValueOutFromObject -header "Enrollment" -object $(Get-MdmEnrollmentInfo -xmlLog $logFile)
}


if($output -contains "all" -or $output -contains "devMgmtAccount") {
  Write-ValueOutFromObject -header "Device Management Account" -object $(Get-MdmDeviceManagementAccount -xmlLog $logFile)
}

if($output -contains "all" -or $output -contains "policies") {
  Write-InitHeader -header "Policies"

}

