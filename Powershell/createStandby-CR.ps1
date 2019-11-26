PARAM(

    [Parameter(Mandatory=$true)] [string] $targetDB = '',
    [Parameter(Mandatory=$true)] [string] $targetPROD = '',    # host\inst
    [string] $targetStandby = '', # host\inst
    [string] $workItem = '', # W-######
    [string] $dataCenter = '',
    [string] $teamName = 'SFMC Messaging HADR',
    [string] $infrastructureName = 'MC Email Studio',
    [string] $changeCategory = 'MC HADR Database - Standby Reinstantiation',
    [string] $changeType = 'Standard',
    [dateTime]$startDateTime,
    [Parameter( Mandatory = $FALSE,
                HelpMessage = 'Supply a credential object to access the Zarga API.')]
                [ValidateNotNull()]
                [System.Management.Automation.PSCredential]
                [System.Management.Automation.Credential()]
                $Credential = [System.Management.Automation.PSCredential]::Empty,
    [int] $dryRun = 1

    #  $myCred = get-credential
    #  .\createStandby-CR.ps1 -targetDB 'ExactTarget155' -targetProd 'LAS1P03C044I01\I01' -targetStandby 'LAS1P03CB161I05\I05' -workItem '' -dataCenter 'LAS' -changeType 'Emergency Break-Fix' -startDateTime '6/14/2019 3PM' -dryRun 0 -verbose
    #  .\createStandby-CR.ps1 -targetDB 'ExactTarget10036' -targetProd 'DFW1P05C052I06\I06' -targetStandby 'DFW1P05CB018I06\I06' -workItem 'W-6091346' -dataCenter 'DFW' -startDateTime '6/05/2019 4PM' -credential $myCred -dryRun 0
    #  .\createStandby-CR.ps1 -targetDB 'ExactTarget10036' -targetProd 'DFW1P05C052I06\I06' -targetStandby 'DFW1P05CB018I06\I06' -workItem 'W-6091346' -dataCenter 'DFW' -startDateTime '6/05/2019 4PM' -dryRun 0
)

process{

 
<# URL to the PullRequest - this should be declaritive data #>
$PullRequestURL = "https://github.exacttarget.com/dbauto/UtilityDB/tree/release/" 
$repository = "UtilityDB"

$subject = "Create Standby for $targetDB and Standby Backups"

<#Your GUS ID - refer to https://salesforce.quip.com/KmuwANS3FvOW on how to find this#>
SWITCH ( $env:USERNAME )
    {
        "DBAutomation Unassigned" { $CaseOwner = "005B0000002qauWIAQ"; BREAK}
        "BLindamood"              { $CaseOwner = "005B00000018dFWIAY"; BREAK}
        "Laura Mesa"              { $CaseOwner = "005B00000018dLXIAY"; BREAK}
        "HBrotherton"             { $CaseOwner = "005B0000001uT4FIAU"; BREAK}
        "Tatiana Seltsova"        { $CaseOwner = "005B00000018dRwIAI"; BREAK}
        "Jared Popejoy"           { $CaseOwner = "005B0000000T7DeIAK"; BREAK}
        "Kyle Neier"              { $CaseOwner = "005B0000002r1gFIAQ"; BREAK}
        "espicer"                 { $CaseOwner = "005B00000018dRdIAI"; BREAK}
        "mharris"                 { $CaseOwner = "005B00000018dMZIAY"; BREAK}
        "abarai"                  { $CaseOwner = "005B00000023ioaIAA"; BREAK}
        "jane.palmer"             { $CaseOwner = "005B00000021pr0IAA"; BREAK}
        "jnaypes"                 { $CaseOwner = "005B0000001LRJEIA4"; BREAK}

        default {WRITE-OUTPUT "You are unknow. $($env:USERNAME)"; BREAK}
    }
    
#>


$dateAdjustment = 0
$timeAdjustment = 0 # apparently GUS is messy
IF( !$startDateTime )
    {
        $date = (Get-Date).addDays($dateAdjustment)
    }
ELSE
    {
        $date = $startDateTime
    }

#for($i0=1; $i0 -le 7; $i0++)
#{        
#    if($date.AddDays($i0).DayOfWeek -eq 'Monday')
#    {
        #$date.AddDays($i)
        #[DateTime]::Today.AddDays($i0).AddHours(13)
        $phase0StartDate = $date.AddDays($dateAdjustment).AddHours($timeAdjustment) # apparently GUS is 7 hours behind Indiana
        $phase0EndDate = $date.AddDays($dateAdjustment).AddHours($timeAdjustment).AddMinutes(5)
        #$phase0StartDate
        #$phase0EndDate
        WRITE-HOST "Phase0 deploy: $phase0StartDate "
        WRITE-HOST "Phase0 deploy: $phase0EndDate "
#        break
#    }
#}

$confirmation = Read-Host "Are these deploy date/times correct?  :"
if ($confirmation -eq 'n') { EXIT; }

<#  Not needed when running from CLI to ZARGA
IF( $dryRun -eq 0 )
    {
        IF( !$Credential )
            {
                $cred = Get-Credential
            }
        ELSE
            {
                $cred = $Credential
            }

        $BasicCreds = Get-BasicAuthCreds $cred.UserName $cred.GetNetworkCredential().password
    }
#>

#Get the Assignee to the work item
#$WorkItem = Invoke-RestMethod -Uri "$URLRoot/service/gus/changerequest" -Method GET -Headers @{"Authorization"="$BasicCreds"}
#   `"ChangeType`": `"DB Review`",
#   `"ScrumTeam`": `"a00B0000005LcfbIAC`", DB PERF
#     ScrumTeam = "a00B0000005J1tZIAS" #OPS
#   `"ScrumTeam`": `"a00B0000009k1bkIAA`",

$CaseBody = "{
  `"BackoutPlan`": `"Stop backup job`",
  `"BusinessReason`": `"Routine Maintenance`",
  `"ChangeArea`": `"MC HADR Database - Standby Reinstantiation`",
  `"ChangeType`": `"$changeType`",
  `"RecordType`": `"Change`",
  `"Description`": `"Backup $targetDB to create standby, restore to standby instance, set up SQL and SDB backups in CommVault
* What validation of the environment is planned prior to the change? Are all assumptions made about the environment validated? We need to check that there is a full backup of $targetDB and ConfigDB taken daily
* In the event of a catastrophic error, what will the end-user impact be? The database could slow down/refuse connections.
* What is the difficulty level of the backout, and how long will it take in the event of a failure ? Very easy, very fast
* How will we know if the change is working as expected? Standby is created successfully
* Is Customer Communication required for this change? If so, how has this been addressed? N/A
* Are there other Teams needed to implement or verify this change? If so, name the coordinator. N/A `",
  `"InfrastructureType`": `"Primary`",
  `"RiskLevel`": `"Low`",
  `"RiskSummary`": `"Services Affected: $targetDB 
Risk if change is delayed: no DR for $targetDB`",
  `"OwnerId`": `"$CaseOwner`",
  `"ScrumTeam`": `"a00B0000009k1bkIAA`",
  `"SourceControl`": `"None`",
  `"Subject`": `"$subject`",
  `"TestedChange`": `"Yes`",
  `"VerificationPlan`": `" Standby and CommVault backups created`",
  `"WorkRecordNumber`": `"$workItem`",
  `"InfrastructureName`": `"$infrastructureName`",
  `"TeamName`": `"$teamName`",
  `"ChangeCategory`": `"$changeCategory`",
  `"ImplementationSteps`": [   
                                
                                {
                                    
                                  `"Description`": `"Restore $targetDB Standby`",
                                  `"DataCenter`": `"$dataCenter`",
                                  `"EstimatedEndTime`": `""+ $phase0EndDate.AddMinutes(15) +"`",
                                  `"EstimatedStartTime`": `""+ $phase0StartDate.AddMinutes(15) +"`",                                  
  `"InfrastructureName`": `"$infrastructureName`",
                                  `"InfrastructureType`": `"Secondary`",
                                  `"ListOfImplementationSteps`": [`"Use standard powershell script to copy and restore databases to standby `",
                                                                  `""+ $targetStandby.REPLACE('\','\\') +"`",
                                                                  `" `",
                                                                  `"Restore Database - Preparation`",
                                                                  `"Restore Database - Implementation`",
                                                                  `"https://docs.google.com/document/d/1J0AzuZyqUF16pH3nFWr6OiWtBuQvWLictHHSfzXEDuQ/edit#heading=h.yfbzhy34gr8v`"]
                                },

                               

                                {
                                    
                                  `"Description`": `"Create Standby backups`",
                                  `"DataCenter`": `"$dataCenter`",
                                  `"EstimatedEndTime`": `""+ $phase0EndDate.AddMinutes(30) +"`",
                                  `"EstimatedStartTime`": `""+ $phase0StartDate.AddMinutes(30) +"`",                                  
  `"InfrastructureName`": `"$infrastructureName`",
                                  `"InfrastructureType`": `"Secondary`",
                                  `"ListOfImplementationSteps`": [`"Create Commvault Backup and run `",
                                                                  `"Turn off SQL native full backup `",
                                                                  `""+ $targetPROD.REPLACE('\','\\') +"`",
                                                                  `" `",
                                                                  `"Create CommVault backup`",
                                                                  `"https://docs.google.com/document/d/1GYlVJPMl-lPDv8xY3BFEpeX3Dgb1GVEA__2bLd3wD5w/edit# `"]
                                }

                           ]
}"

IF( $dryRun -eq 0 )
    {
        $Case = Invoke-RestMethod -Uri "$URLRoot/service/gus/changerequest" -Method Post -Headers @{"Authorization"="$BasicCreds"} -ContentType "application/json" -body $CaseBody

        "PROD Release Case Generated - $($case.CaseNumber)"
        "You need to attach ZIP file and submit for approval - Don't forget this step"
        "Go to this URL - $($Case.ChangeRequestURL)"


        $BasicCreds
    }
ELSE
    {
        WRITE-VERBOSE "[] DryRun "
        WRITE-VERBOSE "[] Zarga: $($URLRoot)"
        WRITE-VERBOSE "[] Subject: $($subject) "
        WRITE-VERBOSE "$caseBody "
    }
}


begin{

    function Get-BasicAuthCreds {
        param([string]$Username,[string]$Password)
        $AuthString = "{0}:{1}" -f $Username,$Password
        $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
        return "Basic $([Convert]::ToBase64String($AuthBytes))"
}

#$UrlRoot = "http://ind2q00dbapi01.qa.local"  # test in browser with /swagger
#http://ind2q00dbapi01.qa.local/swagger/ui/index#!/ChangeRequest/ChangeRequest_PostChangeRequest
# error logs are located c:\inepub\wwwroot\zarga\logging
IF( $env:USERDNSDOMAIN.Replace('ET','QA') -eq 'QA.LOCAL' )
    {
        WRITE-VERBOSE "QA - ZARGA"
        $URLRoot ='http://ind2q00dbapi01.qa.local'
    }
ElSE
    {
        WRITE-VERBOSE "PROD - ZARGA"
        $URLRoot = 'https://zarga.internal.marketingcloud.com'
    }

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