<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Sync-DistributionGroupWithSecurityGroup
Description:
Mirror a distribution group with an security groups members
Release notes:
Version 1.0: Init
Verison 2.0b: Reworked the authentication scheme to use system managed identity and be more robust (Michael Mardahl)
#> 


#region declarations
$tenantDomain = "Fabrikam.onmicrosoft.com" #.onmicrosoft.com domain for exchange online connection
#$EXOcmdlets = "New-DistributionGroup,Update-DistributionGroupMember,Get-DistributionGroupMember" #cmdlets to load from Exchange Online
$graphVersion = "v1.0" #version of Graph endpoint
$secGroupPrefix = "FeatureRollout_" #prefix of the groups to mirror as Distribution groups
$distGroupSuffix = "_dist" #suffix added to the mirror groups. These are created if they don't exist

#endregion declarations

#region functions
function Invoke-GraphRequest {
    param(
        [Parameter(Mandatory)]
        $query
    )
    $response = Invoke-RestMethod -Uri https://graph.microsoft.com/$graphVersion$query -Headers $graphToken -Method GET
	return $response.value

}
#endregion functions

#region execute

"Please enable appropriate Enterprise App permissions to the system identity of this automation account. Otherwise, the runbook may fail..."
"Office 365 Exchange Online - Exchange.ManageAsApp"
"Microsoft Graph - Group.ReadWrite.All (Or owner of the "

try
{
    "[INFO] Logging in to Azure with managed identity"
    Connect-AzAccount -Identity

	"[INFO] Acquire access token for Microsoft Graph"
	$token = (Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com').Token
	$global:graphToken = @{Authorization="Bearer $token"}
	#$global:graphToken = @{Authorization="Bearer $token";ConsistencyLevel="eventual"} #enables advanced queries

	"Logging in to Exchange Online with managed identity"
	Connect-ExchangeOnline -ManagedIdentity -Organization $tenantDomain -ShowBanner:$false
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

#Get Security Groups
$SecurityGroups = Invoke-GraphRequest "/groups?`$filter=mailEnabled eq false and startsWith(displayName, '$secGroupPrefix')"

#mirror each security group into a distribution group individually
foreach ($SecurityGroup in $SecurityGroups)
{
	$distGroupName = "$($SecurityGroup.displayName)$distGroupSuffix"
	#Get transitive members of security group
	$secMembers = Invoke-GraphRequest "/groups/$($SecurityGroup.id)/transitiveMembers"
	
	#find existing distribution groups and create a new one if none are found
	$distGroup = Get-DistributionGroup -Identity $distGroupName -ErrorAction SilentlyContinue

	if($distGroup){
		"[INFO] Existing group found ($distGroupName). Mirroring members."

		$distMembers = Get-DistributionGroupMember -Identity $distGroupName
		$toRemove = $distMembers | Where {$_.ExternalDirectoryObjectId -notin $secMembers.id}
		$toAdd = $secMembers | Where {$_.id -notin $distMembers.ExternalDirectoryObjectId} 

		#add members
		foreach ($member in $toAdd){

			try {
				Add-DistributionGroupMember -Identity $distGroupName -Member $member.userPrincipalName
				"[INFO] Added $($member.userPrincipalName)"
			} catch {
				"[WARNING] Unable to add $($member.userPrincipalName) - Might not be a mail user, so it doesn't matter that much."
			}
		}

		#remove members
		foreach ($member in $toRemove){

			try {
				Remove-DistributionGroupMember -Identity $distGroupName -Member $member.PrimarySmtpAddress -Confirm:$false
				"[INFO] Removed $($member.PrimarySmtpAddress)"
			} catch {
				"[WARNING] Unable to remove $($member.PrimarySmtpAddress) - Might not be a mail user, so it doesn't matter that much."
			}
		}

	} else {
		"[INFO] No group found ($distGroupName). Creating distribution group and mirroring members on next run."

		New-DistributionGroup -Name $distGroupName -Type "Distribution"
	}
	


}
Disconnect-ExchangeOnline -Confirm:$false
#endregion execute
