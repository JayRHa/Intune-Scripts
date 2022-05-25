<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Detection-ToastSurveyLogAnalytics
Description:
Create a system tray icon with some company portal functions
Release notes:
Version 1.0: Init
Inspiration: https://stackoverflow.com/questions/62892229/spawn-powershell-admin-consoles-from-windows-tray
#> 

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
    Get-ScheduledTask | ? {$_.TaskName -eq 'PushLaunch'} | Start-ScheduledTask
})

# Create an Exit Menu Item
$ExitMenuItem = New-Object System.Windows.Forms.MenuItem
$ExitMenuItem.Index = 5
$ExitMenuItem.Text = "Exit"
$ExitMenuItem.add_Click({
    $objForm.Close()
    $objNotifyIcon.visible = $false
})
# Add the Menu Items to the Context Menu
$objContextMenu.MenuItems.Add($buttonSync) | Out-Null
$objContextMenu.MenuItems.Add($buttonOpenCompanyPortal) | Out-Null
$objContextMenu.MenuItems.Add($ExitMenuItem) | Out-Null
#
# Assign the Context Menu
$objNotifyIcon.ContextMenu = $objContextMenu
$objForm.ContextMenu = $objContextMenu

# Show the Form - Keep it open
$objForm.ShowDialog() | Out-Null
$objForm.Dispose()