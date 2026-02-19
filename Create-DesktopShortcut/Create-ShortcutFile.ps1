<#
.SYNOPSIS
    Create a web shortcut .lnk file
.DESCRIPTION
    Creates a desktop shortcut (.lnk) that opens a website in Microsoft Edge, including a custom icon.
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
#>

function New-WebShortcut {
    param (
        [Parameter(Mandatory)]
        [String] $Path,
        [Parameter()]
        [String] $WebsiteUrl,
        [Parameter()]
        [String] $Icon
    )

    $edgePath = "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($Path)
    $Shortcut.TargetPath = $edgePath
    $Shortcut.Arguments = $WebsiteUrl
    $Shortcut.IconLocation = $Icon
    $Shortcut.Save()
    [Runtime.InteropServices.Marshal]::ReleaseComObject($WshShell) | Out-Null
}

# Name of the shortcut
$shortcutName = "Intranet Shortcut"
# Icon file best to use a website
$icon = "https://jannikreinhard.com/files/website.ico"
$iconPath = "C:\ProgramData\WebpageShortcut\webPage.ico"
# Link of the website
$websiteUrl = "https://jannikreinhard.com/"
# Output folder
$outputFolder = "C:\temp"

try {
    $path = Join-Path -Path $outputFolder -ChildPath "$shortcutName.lnk"

    # Download icon and create shortcut
    Invoke-WebRequest -Uri $icon -OutFile "$outputFolder\webPage.ico" -ErrorAction Stop
    New-WebShortcut -Path $path -WebsiteUrl $websiteUrl -Icon $iconPath
    exit 0
} catch {
    Write-Error "Failed to create shortcut file: $_"
    exit 1
}
