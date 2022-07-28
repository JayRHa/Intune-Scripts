<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Create-ShortcutFile
Description:
Create the Lnk shortcut file
Release notes:
Version 1.0: Init
Version 1.1: Copy icon local
#> 


function Create-WebShortcut {
    param (
        [Parameter(Mandatory)]
        [String] $Path,
        [Parameter()]
        [String] $WebsiteUrl,
        [Parameter()]
        [String] $Icon
    )

    #Edge
    $edgePath = "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"


    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($Path)
    $Shortcut.TargetPath = $edgePath
    $Shortcut.Arguments = $WebsiteUrl
    $Shortcut.IconLocation = $Icon
    $Shortcut.Save()
    [Runtime.InteropServices.Marshal]::ReleaseComObject($WshShell) | Out-Null
}

#Name of the shortcut
$shortcutName = "Intranet Shortcut" 
#Icon file best to use a website
$icon = "https://jannikreinhard.com/files/website.ico"
$iconPath = "C:\ProgramData\WebpageShortcut\webPage.ico"
#Link of the webseite
$websiteUrl = "https://jannikreinhard.com/"
#OutputFolder
$outputFolder = "C:\temp"



$path = Join-Path -Path $outputFolder -ChildPath "$shortcutName.lnk"

#Create shortcut
Invoke-WebRequest -Uri $icon -OutFile "$outputFolder\webPage.ico"

Create-WebShortcut -Path $path -WebsiteUrl $websiteUrl -Icon $iconPath


