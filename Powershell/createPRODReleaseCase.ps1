process{


<#URL to the PullRequest - this is the URL that the Perf team will go to for review"#>
$PullRequestURL = "https://github.exacttarget.com/dbauto/UtilityDB/tree/release/" 
<#The Gus Story/Bug you are working on - this will link this review to the story permanently in GUS#>
$newReleaseNumber = "1.15.0"
$oldReleaseNumber = "1.14.0"
<#Your GUS ID - refer to https://salesforce.quip.com/KmuwANS3FvOW on how to find this#>
$CaseOwner = "005B0000001uT4FIAU" 

$repository = "UtilityDB"

$subject = "DEPLOY $repository repo $releaseNumber"
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
$timeAdjustment = 17 # apparently GUS is messy
$date = (Get-Date).addDays($dateAdjustment)

for($i0=1; $i0 -le 7; $i0++)
{        
    if($date.AddDays($i0).DayOfWeek -eq 'Monday')
    {
        #$date.AddDays($i)
        #[DateTime]::Today.AddDays($i0).AddHours(13)
        $phase0StartDate = [DateTime]::Today.AddDays($i0).AddHours($timeAdjustment) # apparently GUS is 7 hours behind Indiana
        $phase0EndDate = [DateTime]::Today.AddDays($i0).AddHours($timeAdjustment).AddMinutes(5)
        #$phase0StartDate
        #$phase0EndDate
        WRITE-HOST "Phase0 deploy: $phase0StartDate "
        WRITE-HOST "Phase0 deploy: $phase0EndDate "
        break
    }
}
for($i1=1; $i1 -le 7; $i1++)
{        
    if($phase0StartDate.AddDays($i1).DayOfWeek -eq 'Thursday')
    {
        #$date.AddDays($i1)
        #[DateTime]::$phase0StartDate.AddDays($i1).AddHours(13)
        $phase1StartDate = [DateTime]::Today.AddDays($i1+$i0).AddHours($timeAdjustment)
        $phase1EndDate = [DateTime]::Today.AddDays($i1+$i0).AddHours($timeAdjustment).AddMinutes(5)
        WRITE-HOST "Phase1 deploy: $phase1StartDate "
        WRITE-HOST "Phase1 deploy: $phase1EndDate "
        break
    }
}
for($i2=1; $i2 -le 7; $i2++)
{        
    if($phase1StartDate.AddDays($i2).DayOfWeek -eq 'Tuesday')
    {
        #$date.AddDays($i2)
        #[DateTime]::$phase0StartDate.AddDays($i2).AddHours(13)
        $phase2StartDate = [DateTime]::Today.AddDays($i2+$i1+$i0).AddHours($timeAdjustment)
        $phase2EndDate = [DateTime]::Today.AddDays($i2+$i1+$i0).AddHours($timeAdjustment).AddMinutes(5)
        WRITE-HOST "Phase2 deploy: $phase2StartDate "
        WRITE-HOST "Phase2 deploy: $phase2EndDate "
        break
    }
}
$confirmation = Read-Host "Are these deploy dates correct?  :"
if ($confirmation -eq 'n') { EXIT; }

$cred = Get-Credential

$BasicCreds = Get-BasicAuthCreds $cred.UserName $cred.GetNetworkCredential().password

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
  `"ChangeType`": `"Minor`",
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
                                  `"EstimatedEndTime`": `"$phase0EndDate`",
                                  `"EstimatedStartTime`": `" $phase0StartDate`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                },

                                {
                                    
                                  `"Description`": `"Deploy $repository Phase0`",
                                  `"DataCenter`": `"LAS1`",
                                  `"EstimatedEndTime`": `""+ $phase0EndDate.AddMinutes(5) +"`",
                                  `"EstimatedStartTime`": `""+ $phase0StartDate.AddMinutes(5) +"`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                },

                                {
                                    
                                  `"Description`": `"Deploy $repository Phase0`",
                                  `"DataCenter`": `"IND1`",
                                  `"EstimatedEndTime`": `""+ $phase0EndDate.AddMinutes(10) +"`",
                                  `"EstimatedStartTime`": `""+ $phase0StartDate.AddMinutes(10) +"`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                },

                                {
                                    
                                  `"Description`": `"Deploy $repository Phase0`",
                                  `"DataCenter`": `"ATL`",
                                  `"EstimatedEndTime`": `""+ $phase0EndDate.AddMinutes(15) +"`",
                                  `"EstimatedStartTime`": `""+ $phase0StartDate.AddMinutes(15) +"`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                },

                                {
                                    
                                  `"Description`": `"Deploy $repository Phase1`",
                                  `"DataCenter`": `"DFW1`",
                                  `"EstimatedEndTime`": `"$phase1EndDate`",
                                  `"EstimatedStartTime`": `"$phase1StartDate`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                },
                                {
                                    
                                  `"Description`": `"Deploy $repository Phase1`",
                                  `"DataCenter`": `"IND1`",
                                  `"EstimatedEndTime`": `""+ $phase1EndDate.AddMinutes(5) +"`",
                                  `"EstimatedStartTime`": `""+ $phase1StartDate.AddMinutes(5) +"`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                },

                                {
                                    
                                  `"Description`": `"Deploy $repository Phase1`",
                                  `"DataCenter`": `"LAS1`",
                                  `"EstimatedEndTime`": `""+ $phase1EndDate.AddMinutes(10) +"`",
                                  `"EstimatedStartTime`": `""+ $phase1StartDate.AddMinutes(10) +"`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                },

                                {
                                    
                                  `"Description`": `"Deploy $repository Phase2`",
                                  `"DataCenter`": `"IND1`",
                                  `"EstimatedEndTime`": `"$phase2EndDate`",
                                  `"EstimatedStartTime`": `"$phase2StartDate`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                },

                                {
                                    
                                  `"Description`": `"Deploy $repository Phase2`",
                                  `"DataCenter`": `"IND2`",
                                  `"EstimatedEndTime`": `""+ $phase2EndDate.AddMinutes(5) +"`",
                                  `"EstimatedStartTime`": `""+ $phase2StartDate.AddMinutes(5) +"`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                },

                                {
                                    
                                  `"Description`": `"Deploy $repository Phase2`",
                                  `"DataCenter`": `"ATL`",
                                  `"EstimatedEndTime`": `""+ $phase2EndDate.AddMinutes(10) +"`",
                                  `"EstimatedStartTime`": `""+ $phase2StartDate.AddMinutes(10) +"`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                },

                                {
                                    
                                  `"Description`": `"Deploy $repository Phase2`",
                                  `"DataCenter`": `"LAS1`",
                                  `"EstimatedEndTime`": `""+ $phase2EndDate.AddMinutes(15) +"`",
                                  `"EstimatedStartTime`": `""+ $phase2StartDate.AddMinutes(15) +"`",
                                  `"InfrastructureType`": `"string`",
                                  `"ListOfImplementationSteps`": [`"Execute the scripts in the files in this order:`",`"WorkTableDB`",`"Utility`",`"master`",`" `",
                                                                  `"Execute the scripts in the folder in this order:`",`"Role`",`"Schema`",`"Table`",`"Type`",`"UserDefinedFunction`",`"View`",`"StoredProcedure`",`"Init`"]
                                }
                           ]
}"


$Case = Invoke-RestMethod -Uri "$URLRoot/service/gus/changerequest" -Method Post -Headers @{"Authorization"="$BasicCreds"} -ContentType "application/json" -body $CaseBody

"PROD Release Case Generated - $($case.CaseNumber)"
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