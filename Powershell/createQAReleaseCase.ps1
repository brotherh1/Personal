process{


<#URL to the PullRequest - this is the URL that the Perf team will go to for review"#>
$PullRequestURL = "https://github.exacttarget.com/dbauto/UtilityDB/tree/release/" 
<#The Gus Story/Bug you are working on - this will link this review to the story permanently in GUS#>
$newReleaseNumber = "1.XX.0"
$oldReleaseNumber = "1.XX.0"
<#Your GUS ID - refer to https://salesforce.quip.com/KmuwANS3FvOW on how to find this#>
$CaseOwner = "005B0000001uT4FIAU" 

$subject = "[TEST] DEPLOY UtilityDB repo $releaseNumber to QA"
<#
    DBAutomation Unassigned - 005B0000002qauWIAQ
    Brennan Lindamood - 005B00000018dFWIAY
    Laura Mesa - 005B00000018dLXIAY
    Harold Brotherton - 005B0000001uT4FIAU
    Tatiana Seltsova - 005B00000018dRwIAI
    Jared Popejoy - 005B0000000T7DeIAK
    Kyle Neier - 005B0000002r1gFIAQ
    Shaun Watts - 005B0000000TrxuIAC
    Robbie Baxter - 005B0000000T7F1IAK
    
#>

$dateAdjustment = 0
$timeAdjustment = 20 # apparently GUS is 7 hours behind Indiana
$date = (Get-Date).addDays($dateAdjustment)

for($i0=1; $i0 -le 7; $i0++)
{        
    if($date.AddDays($i0).DayOfWeek -eq 'Wednesday')
    {
        #$date.AddDays($i)
        #[DateTime]::Today.AddDays($i0).AddHours(13)
        $startDate = [DateTime]::Today.AddDays($i0).AddHours($timeAdjustment) # apparently GUS is 7 hours behind Indiana
        $endDate = [DateTime]::Today.AddDays($i0).AddHours($timeAdjustment).AddMinutes(5)
        #$phase0StartDate
        #$phase0EndDate
        WRITE-HOST "Staging deploy: $startDate "
        WRITE-HOST "Staging deploy: $endDate "
        break
    }
}

$confirmation = Read-Host "Are these deploy dates correct?  :"
if ($confirmation -eq 'n') { EXIT; }

#$cred = Get-Credential

#$BasicCreds = Get-BasicAuthCreds $cred.UserName $cred.GetNetworkCredential().password

#Get the Assignee to the work item
#$WorkItem = Invoke-RestMethod -Uri "$URLRoot/service/gus/changerequest" -Method GET -Headers @{"Authorization"="$BasicCreds"}
#   `"ChangeType`": `"DB Review`",
#   `"ScrumTeam`": `"a00B0000005LcfbIAC`", DB PERF
#    ScrumTeam = "a00B0000005J1tZIAS" #OPS
#  a00B0000005J1tZ ?? maybe ops

$CaseBody = "{
  `"BackoutPlan`": `"Update all objects from the prior release in Github: $PullRequestURL$oldReleaseNumber`",
  `"BusinessReason`": `"Project Work`",
  `"ChangeArea`": `"MC Database`",
  `"ChangeType`": `"R&D Env (Peer Review Only)`",
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
                                    
                                  `"Description`": `"Deploy UtilityDB Repo`",
                                  `"DataCenter`": `"IND1`",
                                  `"EstimatedEndTime`": `"$endDate`",
                                  `"EstimatedStartTime`": `" $startDate`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                }
                           ]
}"


$Case = Invoke-RestMethod -Uri "$URLRoot/service/gus/changerequest" -Method Post -Headers @{"Authorization"="$BasicCreds"} -ContentType "application/json" -body $CaseBody

"QA Release Case Generated - $($case.CaseNumber)"
"You need to attach ZIP file and submit for approval - Don't forget this step"
"Go to this URL - $($Case.ChangeRequestURL)"
}


begin{

    function Get-BasicAuthCreds {
        param([string]$Username,[string]$Password)
        $AuthString = "{0}:{1}" -f $Username,$Password
        $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
        return "Basic $([Convert]::ToBase64String($AuthBytes))"
}

$UrlRoot = "http://ind2q00dbapi01.qa.local"  # test in browser with /swagger
#http://ind2q00dbapi01.qa.local/swagger/ui/index#!/ChangeRequest/ChangeRequest_PostChangeRequest
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