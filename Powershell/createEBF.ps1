process{

<#The Gus Story/Bug you are working on - this will link this review to the story permanently in GUS#>
$relatedWorkItem = ''

$subject = "DEPLOY $repository repo $releaseNumber"

$date = (Get-Date)
$startDate = $date.AddDays($i0).AddHours($timeAdjustment) # apparently GUS is 7 hours behind Indiana
$endDate = $date.AddDays($i0).AddHours($timeAdjustment).AddMinutes(5)

$cred = Get-Credential

$BasicCreds = Get-BasicAuthCreds $cred.UserName $cred.GetNetworkCredential().password

switch($cred.UserName)
    {
        { ($_ -like 'BLindamood*')  } { $caseOwner = '005B00000018dFWIAY' }
        { ($_ -like 'lmesa*')       } { $caseOwner = '005B00000018dLXIAY' }
        { ($_ -like 'hbrotherton*') } { $caseOwner = '005B0000001uT4FIAU' }
        { ($_ -like 'tseltsova*')   } { $caseOwner = '005B00000018dRwIAI' }
        { ($_ -like 'jpopejoy*')    } { $caseOwner = '005B0000000T7DeIAK' }
        { ($_ -like 'kneier*')      } { $caseOwner = '005B0000002r1gFIAQ' }
        { ($_ -like 'swatts*')      } { $caseOwner = '005B0000000TrxuIAC' }
        { ($_ -like 'rbaxter*')     } { $caseOwner = '005B0000000T7F1IAK' }

    } #$caseOwner

    #SCRUM TEAM = /INFRA TEAM ??? MC Email Studio / SFMC Database Operations

$CaseBody = "{
  `"BackoutPlan`": `"Update all objects from the prior release in Github: $PullRequestURL$oldReleaseNumber`",
  `"BusinessReason`": `"Project Work`",
  `"ChangeArea`": `"MC Database`",
  `"ChangeType`": `"Emergency Break-Fix`",
  `"Description`": `"Pull Request::\r\n$PullRequestURL$newReleaseNumber\r\n\r\nRefer to https://salesforce.quip.com/5uJQAjxROABi `",
  `"InfrastructureType`": `"Primary and Secondary`",
  `"RiskLevel`": `"Low`",
  `"RiskSummary`": `"None - code reviewed`",
  `"OwnerId`": `"$CaseOwner`",
  `"ScrumTeam`": `"a00B0000005J1tZIAS`", 
  `"SourceControl`": `"GitHub`",
  `"Subject`": `"$subject`",
  `"TestedChange`": `"Yes`",
  `"VerificationPlan`": `"Validate that all of the objects (roles, tables, stored procedures) that are to exist do actually exist and have a modified date of when the execution was done.`",
  `"WorkItemNumber`": `"`",
  `"ImplementationSteps`": [   
                                {
                                    
                                  `"Description`": `"Deploy $repository Phase0`",
                                  `"DataCenter`": `"DFW1`",
                                  `"EstimatedEndTime`": `"$endDate`",
                                  `"EstimatedStartTime`": `" $startDate`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                }
                           ]
}"


$Case = Invoke-RestMethod -Uri "$URLRoot/service/gus/changerequest" -Method Post -Headers @{"Authorization"="$BasicCreds"} -ContentType "application/json" -body $CaseBody

"PROD Release Case Generated - $($case.CaseNumber)"
#"You need to attach ZIP file and submit for approval - Don't forget this step"
"Go to this URL - $($Case.ChangeRequestURL)"
}


begin{

    function Get-BasicAuthCreds {
        param([string]$Username,[string]$Password)
        $AuthString = "{0}:{1}" -f $Username,$Password
        $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
        return "Basic $([Convert]::ToBase64String($AuthBytes))"
}

IF( $env:USERDNSDOMAIN.Replace('ET','QA') -eq 'QA.LOCAL' )
    {
        $URLRoot ='http://ind2q00dbapi01.qa.local'  # test in browser with /swagger
    }
ElSE
    {
        $URLRoot = 'https://zarga.internal.marketingcloud.com'  # test in browser with /swagger
        # Override while load balancer is misbehaving...
        $URLRoot = 'https://IND1CS0DBAAPI01.xt.local'  # test in browser with /swagger
    }
# error logs are located c:\inepub\wwwroot\zarga\logging

if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
{
$certCallback=@"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
 }
[ServerCertificateValidationCallback]::Ignore();


} 

# 401 unauthorized
# 500 internal ( bleeding ) error