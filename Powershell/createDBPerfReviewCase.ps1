process{


<#URL to the PullRequest - this is the URL that the Perf team will go to for review"#>
$PullRequestURL = "https://github.exacttarget.com/dbauto/DWH/pull/32" 
<#The Gus Story/Bug you are working on - this will link this review to the story permanently in GUS#>
$WorkItemNumber = "W-4666393"
<#Your GUS ID - refer to https://salesforce.quip.com/KmuwANS3FvOW on how to find this#>
$CaseOwner = "005B0000001uT4FIAU"
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



#$cred = Get-Credential

$BasicCreds = Get-BasicAuthCreds $cred.UserName $cred.GetNetworkCredential().password


#Get the Assignee to the work item
#$WorkItem = Invoke-RestMethod -Uri "$URLRoot/service/gus/changerequest" -Method GET -Headers @{"Authorization"="$BasicCreds"}

$CaseBody = "{
  `"BackoutPlan`": `"None - code review`",
  `"BusinessReason`": `"Project Work`",
  `"ChangeArea`": `"MC Config Management Changes`",
  `"ChangeType`": `"DB Review`",
  `"Description`": `"Pull Request::\r\n$PullRequestURL\r\n\r\nRefer to https://salesforce.quip.com/OLdUAjtOHF1h for instructions on how to review in Github.`",
  `"InfrastructureType`": `"Primary`",
  `"RiskLevel`": `"Low`",
  `"RiskSummary`": `"None - code review`",
  `"OwnerId`": `"$CaseOwner`",
  `"ScrumTeam`": `"a00B0000005LcfbIAC`",
  `"SourceControl`": `"GitHub`",
  `"Subject`": `"DBAuto Perf Review - $WorkItemNumber`",
  `"TestedChange`": `"No`",
  `"VerificationPlan`": `"None - code review`",
  `"WorkItemNumber`": `"$WorkItemNumber`",
  `"ImplementationSteps`": []
}"


$Case = Invoke-RestMethod -Uri "$URLRoot/service/gus/changerequest" -Method Post -Headers @{"Authorization"="$BasicCreds"} -ContentType "application/json" -body $CaseBody

"Perf Case Generated - $($case.CaseNumber)"
"You need to submit for approval - Don't forget this step"
"Go to this URL - $($Case.ChangeRequestURL)"
}


begin{

    function Get-BasicAuthCreds {
        param([string]$Username,[string]$Password)
        $AuthString = "{0}:{1}" -f $Username,$Password
        $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
        return "Basic $([Convert]::ToBase64String($AuthBytes))"
}

$UrlRoot = "http://ind2q00dbapi01.qa.local"  # test in brrowser with /swagger
# error logs are located c:\inepub\www\zarga\logging


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