<#PSScriptInfo
.VERSION 1.6
.GUID 566b21e4-6fd1-457a-bdf0-7e082a7fb5c8
.AUTHOR Jannik Reinhard
.COMPANYNAME
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI https://github.com/JayRHa/Intune-Scripts/tree/main/Check-AutopilotPrerequisites
.ICONURI
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA
#>

<# 
.DESCRIPTION 
 Checking if all prerequisites are fullfiled befor starting the enrollment process 
.INPUTS
 None required
.OUTPUTS
 None
.NOTES
 Author: Jannik Reinhard (jannikreinhard.com)
 Twitter: @jannik_reinhard
 Release notes:
  Version 1.0: Init
  Version 1.1: Windows 10 Enterprise LTSC 
  Version 1.2: Add TPM info
  Version 1.3: Minor fixes
  Version 1.4: Minor fixes
  Version 1.5: Add Autopilot profile info and dhcp bug fix
  Version 1.6: Bug fix time.windows.com
#> 
$ProgressPreference = "SilentlyContinue"
function Get-NetworkInformation {
    $networkAdapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -namespace "root\CIMV2" -computername "." -Filter "IPEnabled = 'True' AND DHCPEnabled ='True'" 
    foreach ($networkAdapter in $networkAdapters) 
    {  
        Write-Host -ForegroundColor green "$($networkAdapter.Caption):"

        $ipAddress = ((Get-ItemProperty -Path ("HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters\Interfaces\{0}" -f $networkAdapter.SettingID) -Name DhcpIPAddress).DhcpIPAddress)
        $dhcpServer = ((Get-ItemProperty -ErrorAction SilentlyContinue -Path ("HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters\Interfaces\{0}" -f $networkAdapter.SettingID) -Name DhcpServer).DhcpServer)
        Write-Host "  IP address : $ipAddress"
        Write-Host "  DHCP server: $dhcpServer"
    }
}

function Get-ComputerInformation {
    $AutopilotCache = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Provisioning\AutopilotPolicyCache" -Name "PolicyJsonCache"
    $AutopilotCache = $AutopilotCache | ConvertFrom-Json
    $APProfileName = $AutopilotCache.DeploymentProfileName
  	$OSEdition = (Get-CimInstance win32_operatingsystem).Caption.Replace("Microsoft ","")
    $computerInfo = get-computerinfo
    $tpmInfo = get-tpm
    
    $windowsVersion = @(
        "Windows 10 Enterprise", "Windows 10 Education", "Windows 10 Pro for Workstations", "Windows 10 Pro Education", "Windows 10 Pro", "Windows 10 Enterprise LTSC" ,"Windows 11 Enterprise", "Windows 11 Education", "Windows 11 Pro for Workstations", "Windows 11 Pro Education", "Windows 11 Pro", "Windows 11 Enterprise LTSC"
    )
    
    Write-Host -NoNewline "  Windows Edition :     "
    if($windowsVersion.Contains($($OSEdition))){
        Write-Host -ForegroundColor green $OSEdition
    }else{
        Write-Host -ForegroundColor red $OSEdition
    }
    Write-Host "  Windows Version :     $($computerInfo.WindowsVersion) $($computerInfo.OSDisplayVersion)"
    Write-Host "  Windows InstallDate : $($computerInfo.OsInstallDate)"
    Write-Host "  Bios Version :        $($computerInfo.BiosBIOSVersion)"
    Write-Host "  Bios Status :         $($computerInfo.BiosStatus)"
    Write-Host "  Bios Serialnumber :   $($computerInfo.BiosSeralNumber)"
    Write-Host "  Os Serialnumber :     $($computerInfo.OsSerialNumber)"
    Write-Host "  Hostname :            $($computerInfo.CsName)"
    Write-Host "  Keyboardlayout :      $($computerInfo.KeyboardLayout)"
    Write-Host "  Timezone :            $($computerInfo.TimeZone)"
    Write-Host "  Tpm present :         $($tpmInfo.TpmPresent)"
    Write-Host "  Tpm ready :           $($tpmInfo.TpmReady)"
    Write-Host "  Tpm enabled :         $($tpmInfo.TpmEnabled)"
    if (-not $AutopilotCache.DeploymentProfileName) {
        Write-Host "  Cached AP Profile :   Not Present"
        
    }else{
        Write-Host "  Cached AP Profile :   Assigned" 
        Write-Host "  Autopilot Profile :   $APProfileName"   
    }

}

Function Get-NtpTime ( [String]$NTPServer )
# credits to https://madwithpowershell.blogspot.com/2016/06/getting-current-time-from-ntp-service.html
{
	# Build NTP request packet. We'll reuse this variable for the response packet
	$NTPData    = New-Object byte[] 48  # Array of 48 bytes set to zero
	$NTPData[0] = 27                    # Request header: 00 = No Leap Warning; 011 = Version 3; 011 = Client Mode; 00011011 = 27

	try {
		# Open a connection to the NTP service
		$Socket = New-Object Net.Sockets.Socket ( 'InterNetwork', 'Dgram', 'Udp' )
		$Socket.SendTimeOut    = 2000  # ms
		$Socket.ReceiveTimeOut = 2000  # ms
		$Socket.Connect( $NTPServer, 123 )

		# Make the request
		$Null = $Socket.Send(    $NTPData )
		$Null = $Socket.Receive( $NTPData )

		# Clean up the connection
		$Socket.Shutdown( 'Both' )
		$Socket.Close()
	}

	catch {
		return $null
	}

	# Extract relevant portion of first date in result (Number of seconds since "Start of Epoch")
	$Seconds = [BitConverter]::ToUInt32( $NTPData[43..40], 0 )

	# Add them to the "Start of Epoch", convert to local time zone, and return
	( [datetime]'1/1/1900' ).AddSeconds( $Seconds ).ToLocalTime()
}

function Get-ConnectionTest {
    @("www.msftconnecttest.com", "ztd.dds.microsoft.com", "cs.dds.microsoft.com", "login.live.com", "login.microsoftonline.com", "aadcdn.msauth.net",
    "licensing.mp.microsoft.com", "EnterpriseEnrollment.manage.microsoft.com", "EnterpriseEnrollment-s.manage.microsoft.com", "EnterpriseRegistration.windows.net", 
    "portal.manage.microsoft.com", "enrollment.manage.microsoft.com", "fe2cr.update.microsoft.com", "euprodimedatapri.azureedge.net", "euprodimedatasec.azureedge.net", 
    "euprodimedatahotfix.azureedge.net", "ztd.dds.microsoft.com", "cs.dds.microsoft.com", "config.office.com", "graph.windows.net", "manage.microsoft.com") | ForEach-Object {
        $result = (Test-NetConnection -Port 443 -ComputerName $_)    
        Write-Host -NoNewline "  $($result.ComputerName) ($($result.RemoteAddress)): "
        if($result.TcpTestSucceeded) {
            Write-Host -ForegroundColor Green $result.TcpTestSucceeded
        }else{
            Write-Host -ForegroundColor Red $result.TcpTestSucceeded
        }
    }

		Write-Host -ForegroundColor Yellow "  - now checking timeserver connection (ntp/udp:123)"

    $timeserver = "time.windows.com"
		$timeserverip = (Resolve-DnsName -Name $timeserver -ErrorAction SilentlyContinue).IP4Address
		if( $timeserverip -eq $null ) {
	    Write-Host -NoNewline "  $timeserver (not resolved): "
      Write-Host -ForegroundColor Red $false
		} else {
	    $result = Get-NtpTime($timeserver)

	    Write-Host -NoNewline "  $timeserver ($timeserverip): "

			if( $result -ne $null) {
        Write-Host -ForegroundColor Green $true
			} else {
	      Write-Host -ForegroundColor Red $false
			}
		}

    Write-Host
}

Write-Host -ForegroundColor Yellow "######################################"
Write-Host -ForegroundColor Yellow "# Start Autopilot prerequisite check #"
Write-Host -ForegroundColor Yellow "######################################"
Write-Host
Write-Host -ForegroundColor Yellow "---------------------------------"
Write-Host -ForegroundColor Yellow "|      Device information       |"
Write-Host -ForegroundColor Yellow "---------------------------------"
Get-ComputerInformation
Write-Host
Write-Host -ForegroundColor Yellow "---------------------------------"
Write-Host -ForegroundColor Yellow "| Network interface information |"
Write-Host -ForegroundColor Yellow "---------------------------------"
Get-NetworkInformation
Write-Host
Write-Host -ForegroundColor Yellow "---------------------------------"
Write-Host -ForegroundColor Yellow "|        Connection Test        |"
Write-Host -ForegroundColor Yellow "---------------------------------"
Get-ConnectionTest
Write-Host
Write-Host -ForegroundColor Yellow "######################################"
Write-Host -ForegroundColor Yellow "#  Autopilot prerequisite check Done #"
Write-Host -ForegroundColor Yellow "######################################"
