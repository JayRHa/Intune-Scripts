<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Create-IntuneSystemtray
Description:
Create a system tray icon with some company portal functions
Release notes:
Version 1.0: Init
Inspiration:
- https://stackoverflow.com/questions/62892229/spawn-powershell-admin-consoles-from-windows-tray
- https://github.com/damienvanrobaeys/About_my_device
#> 

#################################################
##################### Start #####################
#################################################
$iconPath = (Split-Path -Parent $($global:MyInvocation.MyCommand.Definition)) + "\icons"

# Load Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Add Icon
$objTrayIcon = New-Object System.Windows.Forms.NotifyIcon
$objTrayIcon.Icon = $iconPath + "\companyPortal.ico"
$objTrayIcon.Text = "Company Portal"
$objTrayIcon.Visible = $true


# Create Primary form
$contextmenu = New-Object System.Windows.Forms.ContextMenuStrip

#############################
####### Sync Devices ########
#############################
$buttonSyncDevice = $contextmenu.Items.Add("Sync device");
$buttonSyncDevice.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sync.png")
#Sync Apps
$buttonSyncDeviceApps = New-Object System.Windows.Forms.ToolStripMenuItem
$buttonSyncDeviceApps.Text = "Sync Apps"
$buttonSyncDeviceApps.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sync.png")
$buttonSyncDeviceApps.add_Click({
  $syncIme = New-Object -ComObject Shell.Application
  $syncIme.open("intunemanagementextension://syncapp")
})
$buttonSyncDevice.DropDownItems.Add($buttonSyncDeviceApps)
# Sync Compliance
$buttonSyncDeviceCompliance = New-Object System.Windows.Forms.ToolStripMenuItem
$buttonSyncDeviceCompliance.Text = "Sync Compliance"
$buttonSyncDeviceCompliance.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sync.png")
$buttonSyncDeviceCompliance.add_Click({
  $syncIme = New-Object -ComObject Shell.Application
  $syncIme.open("intunemanagementextension://synccompliance")
})
$buttonSyncDevice.DropDownItems.Add($buttonSyncDeviceCompliance)


#############################
#### Open Company Portal ####
#############################
$buttonOpenCompanyPortal = $contextmenu.Items.Add("Open Company Portal");
$buttonOpenCompanyPortal.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\companyPortal.png")
$buttonOpenCompanyPortal.add_Click({
    explorer.exe shell:appsFolder\Microsoft.CompanyPortal_8wekyb3d8bbwe!App
})

#############################
##### Open Quick Assist #####
#############################
$buttonOpenQuickAssist = $contextmenu.Items.Add("Open Quick Assist");
$buttonOpenQuickAssist.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\remoteAssistance.png")
$buttonOpenQuickAssist.add_Click({
  & "$env:systemroot\system32\quickassist.exe"
})

#############################
######## Troubleshoot #######
#############################
$buttonTroubleshoot = $contextmenu.Items.Add("Troubleshoot");
$buttonTroubleshoot.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\troubleshoot.png")

# Create submenu for Ime restart
$buttonTroubleshootImeLogs = New-Object System.Windows.Forms.ToolStripMenuItem
$buttonTroubleshootImeLogs.Text = "Show IME Logs"
$buttonTroubleshootImeLogs.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\troubleshoot.png")
$buttonTroubleshootImeLogs.add_Click({
  & explorer c:\ProgramData\Microsoft\IntuneManagementExtension\Logs
})
$buttonTroubleshoot.DropDownItems.Add($buttonTroubleshootImeLogs)

# Create submenu for log collection
$buttonTroubleshootCollectLogs = New-Object System.Windows.Forms.ToolStripMenuItem
$buttonTroubleshootCollectLogs.Text = "Collect diagnostic logs"
$buttonTroubleshootCollectLogs.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\troubleshoot.png")
$buttonTroubleshootCollectLogs.add_Click({
  MdmDiagnosticsTool.exe -out "c:\temp\diagnostic"
  & explorer c:\temp\diagnostic
})
$buttonTroubleshoot.DropDownItems.Add($buttonTroubleshootCollectLogs)

# Create submenu for Ime restart
$buttonTroubleshootRestartIme = New-Object System.Windows.Forms.ToolStripMenuItem
$buttonTroubleshootRestartIme.Text = "IME Restart"
$buttonTroubleshootRestartIme.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\troubleshoot.png")
$buttonTroubleshootRestartIme.add_Click({
  Restart-Service -DisplayName "Microsoft Intune Management Extension"
})
$buttonTroubleshoot.DropDownItems.Add($buttonTroubleshootRestartIme)

# Create submenu for User Certificate
$buttonTroubleshootUsrCert = New-Object System.Windows.Forms.ToolStripMenuItem
$buttonTroubleshootUsrCert.Text = "User Certificate"
$buttonTroubleshootUsrCert.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\troubleshoot.png")
$buttonTroubleshootUsrCert.add_Click({
    Certmgr.msc
})
$buttonTroubleshoot.DropDownItems.Add($buttonTroubleshootUsrCert)

# Create submenu for Machine Certificate
$buttonTroubleshootLmCert = New-Object System.Windows.Forms.ToolStripMenuItem
$buttonTroubleshootLmCert.Text = "Machine Certificate"
$buttonTroubleshootLmCert.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\troubleshoot.png")
$buttonTroubleshootLmCert.add_Click({
  certlm.msc
})
$buttonTroubleshoot.DropDownItems.Add($buttonTroubleshootLmCert)

# Create submenu for Registry
$buttonTroubleshootStartRegistry = New-Object System.Windows.Forms.ToolStripMenuItem
$buttonTroubleshootStartRegistry.Text = "IME Registry"
$buttonTroubleshootStartRegistry.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\troubleshoot.png")
$buttonTroubleshootStartRegistry.add_Click({
  regedit
  [System.Windows.MessageBox]::Show('Navigate to: "HKLM\SOFTWARE\Microsoft\IntuneManagementExtension"')
})
$buttonTroubleshoot.DropDownItems.Add($buttonTroubleshootStartRegistry)

#############################
######## System Info ########
#############################
$buttonSystemInfo = $contextmenu.Items.Add("System Info");
$buttonSystemInfo.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sysInfo.png")

# Hostname
$buttonSystemInfoHostname = New-Object System.Windows.Forms.ToolStripMenuItem
$buttonSystemInfoHostname.Text = ("Hostname: $($env:computername)")
$buttonSystemInfoHostname.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sysInfo.png")
$buttonSystemInfo.DropDownItems.Add($buttonSystemInfoHostname)

# IP address
$buttonSystemInfoIp = New-Object System.Windows.Forms.ToolStripMenuItem
$ip = (Get-WmiObject -class "Win32_NetworkAdapterConfiguration"  | Where {$_.IPEnabled -Match "True"} | Sort-Object index -uniqu)[0].IPAddress[0]
$buttonSystemInfoIp.Text = ("IP: $ip")
$buttonSystemInfoIp.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sysInfo.png")
$buttonSystemInfo.DropDownItems.Add($buttonSystemInfoIp)

# Os Build
$buttonSystemInfoOsBuild = New-Object System.Windows.Forms.ToolStripMenuItem
$buttonSystemInfoOsBuild.Text = ("Os Build: $((([Environment]::OSVersion).Version).ToString())")
$buttonSystemInfoOsBuild.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sysInfo.png")
$buttonSystemInfo.DropDownItems.Add($buttonSystemInfoOsBuild)

# Uptime
$buttonSystemInfoUptime = New-Object System.Windows.Forms.ToolStripMenuItem
$uptime = ((Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime).ToString("yyyy.MM.dd hh:mm")
$buttonSystemInfoUptime.Text = ("Uptime: $uptime")
$buttonSystemInfoUptime.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sysInfo.png")
$buttonSystemInfo.DropDownItems.Add($buttonSystemInfoUptime)

# Last Update installation
$buttonSystemLastUpdateInstallation = New-Object System.Windows.Forms.ToolStripMenuItem
$lastUpdateInstallation = (( gwmi win32_quickfixengineering |sort installedon -desc )[0].InstalledOn).ToString("yyyy.MM.dd hh:mm")
$buttonSystemLastUpdateInstallation.Text = ("Last update installation: $lastUpdateInstallation")
$buttonSystemLastUpdateInstallation.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sysInfo.png")
$buttonSystemInfo.DropDownItems.Add($buttonSystemLastUpdateInstallation)

# Enrollment
$buttonSystemInfoEnrollment = New-Object System.Windows.Forms.ToolStripMenuItem
$enrollment = if(Get-Item -Path HKLM:\SOFTWARE\Microsoft\Enrollments\* | Get-ItemProperty | Where-Object -FilterScript {$null -ne $_.UPN}){"Yes"}else{"No"}
$buttonSystemInfoEnrollment.Text = ("MDM enrolled: $enrollment")
$buttonSystemInfoEnrollment.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sysInfo.png")
$buttonSystemInfo.DropDownItems.Add($buttonSystemInfoEnrollment)

# Device Ownership
$buttonSystemInfoDeviceOwnerShip = New-Object System.Windows.Forms.ToolStripMenuItem
$enrollment = switch(Get-ItemPropertyValue -Path HKLM:\SOFTWARE\Microsoft\Enrollments\Ownership -Name CorpOwned -ErrorAction SilentlyContinue){0{retun "Personal"}1{"Corporate"}$null{"Unkonw"}}
$buttonSystemInfoDeviceOwnerShip.Text = ("Device ownership: $enrollment")
$buttonSystemInfoDeviceOwnerShip.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sysInfo.png")
$buttonSystemInfo.DropDownItems.Add($buttonSystemInfoDeviceOwnerShip)

# Ime Status
$buttonSystemInfoImeStatus = New-Object System.Windows.Forms.ToolStripMenuItem
$imeStatus = If(Get-Service -Name "Microsoft Intune Management Extension" -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Running"}) {"Running"}else{"Not Running"}
$buttonSystemInfoImeStatus.Text = ("Ime Status: $imeStatus")
$buttonSystemInfoImeStatus.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\sysInfo.png")
$buttonSystemInfo.DropDownItems.Add($buttonSystemInfoImeStatus)


#############################
##### Change Password #######
#############################
$buttonExit = $contextmenu.Items.Add("Change Password");
$buttonExit.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\password.png")
$buttonExit.add_Click({
  Start-Process "https://account.activedirectory.windowsazure.com/ChangePassword.aspx?portalUrl=https://account.activedirectory.windowsazure.com/profile"
 })



#############################
############ Exit ###########
#############################
$buttonExit = $contextmenu.Items.Add("Exit");
$buttonExit.Image = [System.Drawing.Bitmap]::FromFile("$iconPath\exit.png")
$buttonExit.add_Click({
	$objTrayIcon.Visible = $false
	Stop-Process $pid
 })

 $objTrayIcon.ContextMenuStrip = $contextmenu;
 ###############################################

 [System.GC]::Collect()
 $systemTrayAppContext = New-Object System.Windows.Forms.ApplicationContext
 [void][System.Windows.Forms.Application]::Run($systemTrayAppContext)