<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-NewEnrolledDevicesReport
Description:
Get Email with new enrolled devices
Release notes:
Version 1.0: Init
#> 


function Get-AuthHeader{
    param (
        [parameter(Mandatory=$true)]$tenantId,
        [parameter(Mandatory=$true)]$clientId,
        [parameter(Mandatory=$true)]$clientSecret
       )
    
    $authBody=@{
        client_id=$clientId
        client_secret=$clientSecret
        scope="https://graph.microsoft.com/.default"
        grant_type="client_credentials"
    }

    $uri="https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $accessToken=Invoke-WebRequest -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $authBody -Method Post -ErrorAction Stop -UseBasicParsing
    $accessToken=$accessToken.content | ConvertFrom-Json

    $authHeader = @{
        'Content-Type'='application/json'
        'Authorization'="Bearer " + $accessToken.access_token
        'ExpiresOn'=$accessToken.expires_in
    }
    
    return $authHeader
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################
# Variables
$MailSender = "mail@abc.onmicrosoft.com"
$MailTo = "mail@abc.onmicrosoft.com"

# Automation Secrets
$tenantId = Get-AutomationVariable -Name 'TenantId'
$clientId = Get-AutomationVariable -Name 'AppId'
$clientSecret = Get-AutomationVariable -Name 'AppSecret'


$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

# Define the time range
$endDate = Get-Date
$startDate = $endDate.AddDays(-7)
$filter = "enrolledDateTime gt $($startDate.ToString("yyyy-MM-ddTHH:mm:ssZ"))&enrolledDateTime le $($endDate.ToString("yyyy-MM-ddTHH:mm:ssZ"))"

# Query Intune devices enrolled in the past week
$graphApiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
$graphApiQuery = "?`$filter=$filter&`$select=id,deviceName,operatingSystem,enrolledDateTime,userPrincipalName,model"
$uri = $graphApiUrl + $graphApiQuery
$response = Invoke-RestMethod -Method Get -Uri $uri -Headers $global:authToken

# Generate CSV report
$reportPath = "NewEnrolledDevicesReport.csv"
$response.value | Select-Object id,deviceName,operatingSystem,enrolledDateTime,userPrincipalName,model | Export-Csv -Path $reportPath -NoTypeInformation
$csv = [Convert]::ToBase64String([IO.File]::ReadAllBytes(".\$reportPath"))

#Send Mail    
$URLsend = "https://graph.microsoft.com/v1.0/users/$MailSender/sendMail"
$BodyJsonsend = @"
{
    "message": {
      "subject": "New enrolled devices",
      "body": {
        "contentType": "Text",
        "content": "Dear Admin, this Mail contains the enrolled devices from the last 7 days"
      },
      "toRecipients": [
        {
          "emailAddress": {
            "address": "$MailTo"
          }
        }
      ],
      "attachments": [
        {
          "@odata.type": "#microsoft.graph.fileAttachment",
          "name": "newEnrolledDevicesReport.csv",
          "contentType": "text/plain",
          "contentBytes": "$csv"
        }
      ]
    }
  }
"@


Invoke-RestMethod -Method POST -Uri $URLsend -Headers $global:authToken -Body $BodyJsonsend