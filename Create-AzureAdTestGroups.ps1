<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Create-AzureAdTestGroups
Description:
Get all intune assignments from an aad group
Release notes:
Version 1.0: Init
#> 

Connect-AzureAD

$countOfTestGroups = 10

while($i -lt $countOfTestGroups)
    {
        New-AzureADGroup -DisplayName "zTestSecurityGroup$i" -SecurityEnabled $true -Description "Test group nr group $i"  -MailEnabled $false -MailNickName "NotSet"
        $i++
    }


