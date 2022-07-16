<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Deploy-IntuneSystemtrayScript
Description:
Create a system tray icon with some company portal functions
Release notes:
Version 1.0: Init
Version 1.1: Bug fixes
Inspiration: https://stackoverflow.com/questions/62892229/spawn-powershell-admin-consoles-from-windows-tray
#> 

# Variables
$taskName = "StartIntuneSystemtray"
$scriptPath = "C:\Windows\Temp\"

# Create directory if not exist
if (!(Test-Path $scriptPath)) {
    New-Item $scriptPath -itemType Directory
}

# Alternative to using the Base64 option - I use C:\Windows\IntuneFiles\ for storing anything from Intune on the local machine.
# Start-BitsTransfer -Source "<Azure Blob Storage URL>/CompanyPortal.ico" -Destination "C:\Windows\IntuneFiles\CompanyPortal.ico"

$iconBase64 = "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"
# Decode icon
[byte[]]$Bytes = [convert]::FromBase64String($iconBase64)
[System.IO.File]::WriteAllBytes("$scriptPath/companyPortal.ico",$Bytes)	


$script = @'
<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Create-IntuneSystemtray
Description:
Create a system tray icon with some company portal functions
Release notes:
Version 1.0: Init
Inspiration: https://stackoverflow.com/questions/62892229/spawn-powershell-admin-consoles-from-windows-tray
#> 
#################################################
################### Variables ###################
#################################################
$cmtraceSourceLink = "https://github.com/JayRHa/Intune-Scripts/raw/cdc787103c094da7b322e218036adc0934f30159/Create-IntuneSystemtray/CMTrace.exe"
#################################################

[System.GC]::Collect()
$path = (Split-Path -Parent $($global:MyInvocation.MyCommand.Definition))

# Load Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing



# Create Primary form
$objForm = New-Object System.Windows.Forms.Form
$objForm.Visible = $false
$objForm.WindowState = "minimized"
$objForm.ShowInTaskbar = $false

$objForm.add_Closing({ $objForm.ShowInTaskBar = $False })

# Add Icon
$objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$objNotifyIcon.Icon = $path + "\companyPortal.ico"
$objNotifyIcon.Text = "TrayUtility"
$objNotifyIcon.Visible = $true

# Context menue
$objContextMenu = New-Object System.Windows.Forms.ContextMenu

# Button Start Company Portal
$buttonOpenCompanyPortal = New-Object System.Windows.Forms.MenuItem
$buttonOpenCompanyPortal.Index = 1
$buttonOpenCompanyPortal.Text = "Open Company Portal"
$buttonOpenCompanyPortal.add_Click({
    explorer.exe shell:appsFolder\Microsoft.CompanyPortal_8wekyb3d8bbwe!App
})

# Button Sync
$buttonSync = New-Object System.Windows.Forms.MenuItem
$buttonSync.Index = 2
$buttonSync.Text = "Sync"
$buttonSync.add_Click({
    $syncIme = New-Object -ComObject Shell.Application
    $syncIme.open("intunemanagementextension://syncapp")
})

# Menu Troubleshoot
$menuTroubleshoot = New-Object System.Windows.Forms.MenuItem
$menuTroubleshoot.Index = 4
$menuTroubleshoot.Text = "Troubleshoot"

# Create an Exit Menu Item
$buttonExit = New-Object System.Windows.Forms.MenuItem
$buttonExit.Index = 5
$buttonExit.Text = "Exit"
$buttonExit.add_Click({
    $objForm.Close()
    $objNotifyIcon.visible = $false
})
# Add the Menu Items to the Context Menu

$objContextMenu.MenuItems.Add($buttonSync) | Out-Null
$objContextMenu.MenuItems.Add($buttonOpenCompanyPortal) | Out-Null
$objContextMenu.MenuItems.AddRange($menuTroubleshoot) | Out-Null
$objContextMenu.MenuItems.Add($buttonExit) | Out-Null

# Create submenu for CmTrace installation
$cmtracePath = "C:\Windows\Temp\CMTrace.exe"
if(-NOT (Test-Path -Path $cmtracePath)){
    $menuTroubleshoot_installCmtrcace = $menuTroubleshoot.MenuItems.Add("Install CMTrace")
    $menuTroubleshoot_installCmtrcace.add_Click({
        Invoke-WebRequest -Uri $cmtraceSourceLink -OutFile $cmtracePath
        $menuTroubleshoot_installCmtrcace.visible = $false
        $objForm.Refresh()
        Start-Process -FilePath $cmtracePath
    })
}

# Create submenu for Ime restart
$menuTroubleshoot_imeLogs = $menuTroubleshoot.MenuItems.Add("Show IME Logs")
$menuTroubleshoot_imeLogs.add_Click({
    explorer c:\ProgramData\Microsoft\IntuneManagementExtension\Logs
})
# Create submenu for log collection
$menuTroubleshoot_collectLogs = $menuTroubleshoot.MenuItems.Add("Collect diagnostic logs")
$menuTroubleshoot_collectLogs.add_Click({
    MdmDiagnosticsTool.exe -out c:\temp\diagnostic
    explorer c:\temp\diagnostic
})
# Create submenu for Ime restart
$menuTroubleshoot_restartIme = $menuTroubleshoot.MenuItems.Add("IME Restart")
$menuTroubleshoot_restartIme.add_Click({
    Restart-Service -DisplayName "Microsoft Intune Management Extension"
})
# Create submenu for User Certificate
$menuTroubleshoot_usrCert = $menuTroubleshoot.MenuItems.Add("User Certificate")
$menuTroubleshoot_usrCert.add_Click({
    Certmgr.msc
})
# Create submenu for Machine Certificate
$menuTroubleshoot_lmCert = $menuTroubleshoot.MenuItems.Add("Machine Certificate")
$menuTroubleshoot_lmCert.add_Click({
    certlm.msc
})
# Create submenu for Registry
$menuTroubleshoot_startRegistry = $menuTroubleshoot.MenuItems.Add("IME Registry")
$menuTroubleshoot_startRegistry.add_Click({
    regedit
    [System.Windows.MessageBox]::Show('Navigate to: "HKLM\SOFTWARE\Microsoft\IntuneManagementExtension"')
})


# Assign the Context Menu
$objNotifyIcon.ContextMenu = $objContextMenu
$objForm.ContextMenu = $objContextMenu

# Show the Form - Keep it open
$objForm.ShowDialog() | Out-Null
$objForm.Dispose()
'@


# Remove Task if it exists
if ($(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue).TaskName -eq $taskName) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$False
}

# Create the powershell file to reference on login
New-Item -Path "$scriptPath/Create-IntuneSystemtray.ps1" -type "file" -Value $script -force

# Create Task
$trigger    = New-ScheduledTaskTrigger -AtLogOn
$user       = New-ScheduledTaskPrincipal -GroupId S-1-5-32-545
$action     = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle hidden $scriptPath/Create-IntuneSystemtray.ps1"
$task       = New-ScheduledTask -Action $action -Trigger $trigger -Principal $user
Register-ScheduledTask -TaskName $taskName -InputObject $task
Get-ScheduledTask | ? {$_.TaskName -eq $taskName} | Start-ScheduledTask
