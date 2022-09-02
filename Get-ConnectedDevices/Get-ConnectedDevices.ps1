# Get lonove devices
$deviceId = @('')

foreach($device in Get-PnpDevice){
    if(($lenoveDockIds | %{$device.DeviceID -like "$_*"}) -contains $true){
        Write-Host "Device found"
        Exit 1
    }
}

Write-Host "Device not found"
Exit 0
