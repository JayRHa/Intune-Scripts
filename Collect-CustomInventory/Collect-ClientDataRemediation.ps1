<#
.SYNOPSIS
    Collect client telemetry and send it to an Azure Function endpoint.
.DESCRIPTION
    Remediation script that gathers CPU utilization, RAM usage, and Azure AD
    join information from the local device, then POSTs the data as JSON to a
    configured Azure Function URL.
.NOTES
    Author : Jannik Reinhard (jannikreinhard.com)
    Version: 1.1
    Release: v1.0 - Init
             v1.1 - Replaced Get-WmiObject with Get-CimInstance, added guards
#>

#### Configuration ####
$azureFunctionUrl = ""
$cpuTestCycle = 10
$ramTestCycle = 10
$time = Get-Date
$runFrequenz = 1

if ([string]::IsNullOrEmpty($azureFunctionUrl)) {
    Write-Error "Azure Function URL is not configured. Set `$azureFunctionUrl before running."
    exit 1
}

###########################################################################################
################################### Functions #############################################
###########################################################################################
function Get-AvgCpuUtilization($cpuTestCycle){
    $avgLoad = 0
    1..$cpuTestCycle | ForEach-Object {
        $avgLoad += (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        Start-Sleep -Milliseconds 50
    }

    return @"
    {
        "cpuLoadAvg" : $(($avgLoad / $cpuTestCycle))
    }
"@
}
function Get-AvgRam($ramTestCycle){
    $totalvisiblememorysize = 0
    $freephysicalmemory = 0
    $totalvirtualmemorysize = 0
    $freevirtualmemory = 0
    1..$ramTestCycle | ForEach-Object {
        $ramUsage = Get-CimInstance Win32_OperatingSystem
        $totalvisiblememorysize += $ramUsage.totalvisiblememorysize
        $freephysicalmemory += $ramUsage.freephysicalmemory
        $totalvirtualmemorysize += $ramUsage.totalvirtualmemorysize
        $freevirtualmemory += $ramUsage.freevirtualmemory
        Start-Sleep -Milliseconds 50
    }

    return @"
    {
        "totalPhisicalMemoryAvg" : $($totalvisiblememorysize / $ramTestCycle)
        ,"freePhisicalMemoryAvg" : $($freephysicalmemory / $ramTestCycle)
        ,"totalVirtualMemoryAvg" : $($totalvirtualmemorysize / $ramTestCycle)
        ,"freeVirtualMemoryAvg" : $($freevirtualmemory / $ramTestCycle)
    }
"@
}

function Get-ValidationInfo{
		$AzureADJoinInfoRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
        $AzureADJoinInfoKey = Get-ChildItem -Path $AzureADJoinInfoRegistryKeyPath | Select-Object -ExpandProperty "PSChildName"
		if ($AzureADJoinInfoKey -ne $null) {
                if ([guid]::TryParse($AzureADJoinInfoKey, $([ref][guid]::Empty))) {
                    $AzureADJoinCertificate = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Where-Object { $PSItem.Subject -like "CN=$($AzureADJoinInfoKey)" }
                }
                else {
                    $AzureADJoinCertificate = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Where-Object { $PSItem.Thumbprint -eq $AzureADJoinInfoKey }
                }
			if ($AzureADJoinCertificate -ne $null) {
				$AzureADDeviceID = ($AzureADJoinCertificate | Select-Object -ExpandProperty "Subject") -replace "CN=", ""
				$AzureADJoinDate = ($AzureADJoinCertificate | Select-Object -ExpandProperty "NotBefore")
			}
		}
    $AzureADTenantInfoRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo"
	$AzureADTenantID = Get-ChildItem -Path $AzureADTenantInfoRegistryKeyPath | Select-Object -ExpandProperty "PSChildName"


    return @"
    {
        "aadDeviceId" : "$($AzureADDeviceID)"
        ,"aadDeviceJoinDate" : "$(($AzureADJoinDate).ToString("MM/dd/yyyy HH:mm:ss"))"
        ,"tenantId" : "$($AzureADTenantID)"
    }
"@
}


###########################################################################################
##################################### Start ###############################################
###########################################################################################

$result = @"
{
    "data" : {
        "hostname" : "$($env:computername)"
        ,"cpu": $(Get-AvgCpuUtilization($cpuTestCycle))
        ,"ram" : $(Get-AvgRam($ramTestCycle))
    }
    ,"validation" : $(Get-ValidationInfo)
    ,"time" : "$($time.ToUniversalTime().ToString("MM/dd/yyyy HH:mm:ss"))"
}
"@

try {
    Invoke-WebRequest -Uri $azureFunctionUrl -Method "POST" -Body $result
    exit 0
}
catch {
    Write-Error "Failed to send data to Azure Function: $_"
    exit 1
}
