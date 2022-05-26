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
[System.GC]::Collect()

$path = (Split-Path -Parent $($global:MyInvocation.MyCommand.Definition))

# Load Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
#Add-Type -AssemblyName WindowsFormsIntegration
#Add-Type -AssemblyName presentationframework


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
    Get-ScheduledTask | ? {$_.TaskName -eq 'PushLaunch'} | Start-ScheduledTask
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
    Restart-Service -Name "IntuneManagementExtension"
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