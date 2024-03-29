<#
.SYNOPSIS
    Script that initiates the IntuneDeviceInventory module
.NOTES
    Version: 1.0
    Author: Jannik Reinhard (jannikreinhard.com)
    Script: Get-MdmDiagnosticLogs.ps1
    Description:
    Get an object from the mdm diagnostic log or printed out the content
    Release notes:
    Version 1.0: Init
#>
Function Get-MdmDiagnosticLogObject {
    param (
      [parameter(HelpMessage = "Collect new logs")][ValidateNotNullOrEmpty()][switch]$collectNew=$false,
      [parameter(HelpMessage = "Get return only")][switch]$returnonly=$false,
      [parameter(Mandatory=$true, HelpMessage = "Typle of logs")][ValidateSet('All','ActiveSync','DeviceManageabilityProviderInfo','DeviceManagementAccount','Diagnostics','EAS','Enrollments','EnterpriseDesktopAppManagementinfo','FirstSyncData','MdmWinsOverGp','PolicyManager','PolicyManagerMeta','ProvisioningResults','Resources','SCEP','SystemInformation','Version','WAP')][string[]]$output=$Null
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
          [string]$header
        )
      $lenght = $header.Length + 33
      
      for($i=0; $i -le $lenght;$i++){Write-Host "#" -NoNewline -ForegroundColor Yellow}
      Write-Host
      Write-Host "################ $header ################" -ForegroundColor Yellow
      for($i=0; $i -le $lenght;$i++){Write-Host "#" -NoNewline -ForegroundColor Yellow}
      Write-Host
    }
  
    function Get-ObjectPrinted
    {
      # https://www.red-gate.com/simple-talk/blogs/display-object-a-powershell-utility-cmdlet/
      [CmdletBinding()]
      param
      (
        [Parameter(Mandatory = $true,
              ValueFromPipeline = $true)]
        $TheObject,
        [int]$depth = 5,
        [Object[]]$Avoid = @('#comment'),
        [string]$Parent = '$',
        [int]$CurrentDepth = 0
      )
      
      if (($CurrentDepth -ge $Depth) -or
        ($TheObject -eq $Null)) { return; }
      $ObjectTypeName = $TheObject.GetType().Name
      if ($ObjectTypeName -in 'HashTable', 'OrderedDictionary')
      {
        $TheObject = [pscustomObject]$TheObject;
        $ObjectTypeName = 'PSCustomObject'
      }
      if ($TheObject.Count -le 1 -and $ObjectTypeName -ne 'object[]')
      {
        if ($ObjectTypeName -in @('PSCustomObject'))
        { $MemberType = 'NoteProperty' }
        else
        { $MemberType = 'Property' }
        $TheObject | 
        gm -MemberType $MemberType | where { $_.Name -notin $Avoid } |
        Foreach{
          Try { $child = $TheObject.($_.Name); }
          Catch { $Child = $null }
                $brackets=''; if ($_.Name -like '*.*'){$brackets="'"}
          if ($child -eq $null -or
            $child.GetType().BaseType.Name -eq 'ValueType' -or
            $child.GetType().Name -in @('String', 'String[]'))
          { [pscustomobject]@{ 'Path' = "$Parent.$brackets$($_.Name)$brackets"; 'Value' = $Child; } }
          elseif (($CurrentDepth + 1) -eq $Depth)
          {
            [pscustomobject]@{ 'Path' = "$Parent.$brackets$($_.Name)$brackets"; 'Value' = $Child; }
          }
          else
          {
            Get-ObjectPrinted -TheObject $child -depth $Depth -Avoid $Avoid `
                                  -Parent "$Parent.$brackets$($_.Name)$brackets" `
                    -CurrentDepth ($currentDepth + 1)
          }
      
        }
      }
      else
      {
        if ($TheObject.Count -gt 0)
                {0..($TheObject.Count - 1) | Foreach{
          $child = $TheObject[$_];
          if (($child -eq $null) -or
            ($child.GetType().BaseType.Name -eq 'ValueType') -or
            ($child.GetType().Name -in @('String', 'String[]')))
          { [pscustomobject]@{ 'Path' = "$Parent[$_]"; 'Value' = "$($child)"; } }
          elseif (($CurrentDepth + 1) -eq $Depth)
          {
            [pscustomobject]@{ 'Path' = "$Parent[$_]"; 'Value' = "$($child)"; }
          }
          else
          {
            Get-ObjectPrinted -TheObject $child -depth $Depth -Avoid $Avoid -parent "$Parent[$_]" `
                    -CurrentDepth ($currentDepth + 1)
          }
          
        }
      }
        else {[pscustomobject]@{ 'Path' = "$Parent"; 'Value' = $Null }}
        }
    }
  
  
  
    Function Write-ValueOutFromObject{
      param(
        [string]$header,
        [PSCustomObject]$object
      )
  
      Write-InitHeader -header $header
      Get-ObjectPrinted $object -depth 6
    }
  
    function Convert-XmlNodeToPsCustomObject ($node){
      # https://stackoverflow.com/questions/3242995/convert-xml-to-psobject
      $hash = @{}
      foreach($attribute in $node.attributes){
          $hash.$($attribute.name) = $attribute.Value
      }
      $childNodesList = ($node.childnodes | ?{$_ -ne $null}).LocalName
      foreach($childnode in ($node.childnodes | ?{$_ -ne $null})){
          if(($childNodesList | ?{$_ -eq $childnode.LocalName}).count -gt 1){
              if(!($hash.$($childnode.LocalName))){
                  $hash.$($childnode.LocalName) += @()
              }
              if ($childnode.'#text' -ne $null) {
                  $hash.$($childnode.LocalName) += $childnode.'#text'
              }
              $hash.$($childnode.LocalName) += Convert-XmlNodeToPsCustomObject($childnode)
          }else{
              if ($childnode.'#text' -ne $null) {
                  $hash.$($childnode.LocalName) = $childnode.'#text'
              }else{
                  $hash.$($childnode.LocalName) = Convert-XmlNodeToPsCustomObject($childnode)
              }
          }   
      }
      $hash = $hash | ConvertTo-PsCustomObjectFromHashtable 
      return $hash
    }
  
    Function ConvertTo-PsCustomObjectFromHashtable { 
      param ( 
          [Parameter(  
              Position = 0,   
              Mandatory = $true,   
              ValueFromPipeline = $true,  
              ValueFromPipelineByPropertyName = $true  
          )] [object[]]$hashtable 
      ); 
  
      begin { $i = 0; } 
  
      process { 
          foreach ($myHashtable in $hashtable) { 
              if ($myHashtable.GetType().Name -eq 'hashtable') { 
                  $output = New-Object -TypeName PsObject; 
                  Add-Member -InputObject $output -MemberType ScriptMethod -Name AddNote -Value {  
                      Add-Member -InputObject $this -MemberType NoteProperty -Name $args[0] -Value $args[1]; 
                  }; 
                  $myHashtable.Keys | Sort-Object | % {  
                      $output.AddNote($_, $myHashtable.$_);  
                  } 
                  $output
              } else { 
                  Write-Warning "Index $i is not of type [hashtable]"; 
              }
              $i += 1;  
          }
      } 
    }
  
    #################################################################################################
    ########################################### Start ###############################################
    #################################################################################################
    $logPath = "c:\temp\diagnostic"
    if(-not ((Get-CheckIfLogExist -path $logPath) -or $collectNew)){
      MdmDiagnosticsTool.exe -out $logPath
    }
  
    [xml]$xmlLog = Get-Content -Path "$logPath/MDMDiagReport.xml"
    $mdmObject = Convert-XmlNodeToPsCustomObject $xmlLog
  
    if($returnonly){
      if($output -contains "all"){
        return $($mdmObject.MDMEnterpriseDiagnosticsReport)
      }else{
          # ToDo: Optimize
        $mdmObject.MDMEnterpriseDiagnosticsReport | Select-Object -Property $output
      }
    }else{
      ($mdmObject.MDMEnterpriseDiagnosticsReport).PSObject.Properties | ForEach-Object {
        if($output -contains "all"){
          Write-ValueOutFromObject -header $_.Name -object $_ | Where-Object {$_.Path -notlike @('$*IsGettable*') -and $_.Path -notlike @('$*IsSettable*') -and $_.Path -notlike @('$*IsInstance*') -and $_.Path -notlike @('$*MemberType*') -and $_.Path -notlike @('$*TypeNameOfValue*')}
        }elseif($output -contains $_.Name){
            Write-ValueOutFromObject -header $_.Name -object $_ | Where-Object {$_.Path -notlike @('$*IsGettable*') -and $_.Path -notlike @('$*IsSettable*') -and $_.Path -notlike @('$*IsInstance*') -and $_.Path -notlike @('$*MemberType*') -and $_.Path -notlike @('$*TypeNameOfValue*')}
        }
      }
    }
}
## Get 'FirstSyncData', 'SystemInformation' as output in the the terminal
#------------------------------------------------------------------------
# Get-MdmDiagnosticLogObject -output @('FirstSyncData', 'SystemInformation')


##Get  'FirstSyncData', 'SystemInformation' as return value into an variable
#------------------------------------------------------------------------
# $mdmDiagnostic = Get-MdmDiagnosticLogObject -returnonly -output @('FirstSyncData', 'SystemInformation')


## Generate a new logfile and get  'FirstSyncData', 'SystemInformation' as return value into an variable
#------------------------------------------------------------------------
#$mdmDiagnostic = Get-MdmDiagnosticLogObject -returnonly -collectNew -output @('FirstSyncData', 'SystemInformation')


## Get all device configuration object meta data
#------------------------------------------------------------------------
# $mdmLogInfo = Get-MdmDiagnosticLogObject -output @('PolicyManagerMeta') -returnonly
# Write-Output $mdmLogInfo.PolicyManagerMeta.AreaMetadata