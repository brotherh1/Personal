PARAM (
        [string] $serverinstance = 'ATL1QA1C012I12#I12',
        [string] $policy ="policy/auditsdisabled",
        [string] $BasicCreds
        
        )

process{
#$cred = Get-Credential

#$BasicCreds = Get-BasicAuthCreds $cred.UserName $cred.GetNetworkCredential().password
$policy = $policy.toLower()
#$serverinstance = 'ATL1QA1C012I12#I12'
$serverinstance = $serverinstance.replace('#','%23')
$endpoint = "/dbserver/$serverinstance/$policy" 

WRITE-HOST "Processing: $endpoint"

#"/dbserver/$serverinstance",
#"/dbserver/$serverinstance/policy/isredinstancesharinghost",
$endpointList = @( $endpoint
#"/dbserver/$serverinstance/policy/activetransactionduration",
#"/dbserver/$serverinstance/policy/auditsdisabled",
#"/dbserver/$serverinstance/policy/logshippingactive",
#"/dbserver/$serverinstance/policy/logshippingpaused",
#"/dbserver/$serverinstance/policy/standardauditsenabled"#,
#"/dbserver/$serverinstance/policy/inflighttransactionsize",
#"/dbserver/$serverinstance/policy/logspaceused",
#"/dbserver/$serverinstance/policy/nobackupisrunning",
#"/dbserver/$serverinstance/policy/nodeprecationjobsenabled",
#"/dbserver/$serverinstance/policy/nodeprecationjobsrunning",
#"/dbserver/$serverinstance/policy/nospidsinrollback"#,
#"/dbserver/$serverinstance/action/DisableDeprecationJobs",
#"/dbserver/$serverinstance/action/DisableLogBackup",
#"/dbserver/$serverinstance/action/KillLongRunningSPID",
#"/dbserver/$serverinstance/action/SetMaintenance",
#"/dbserver/$serverinstance/action/StartStandardAudits",
#"/dbserver/$serverinstance/action/StopAudits",
#"/dbserver/$serverinstance/action/StopDeprecationJobs",
#"/dbserver/$serverinstance/action/enableLogShipping",
#"/dbserver/$serverinstance/action/killSPID",
#"/dbserver/$serverinstance/action/pauseLogShipping"
)


#Hit some endpoints
$Results =  $endpointList | %{Invoke-RestMethod -Uri "$URLRoot/$($_)" -Method GET -Headers @{"Authorization"="$BasicCreds"}}


$Results
$Results.Count
}

begin{

    function Get-BasicAuthCreds {
        param([string]$Username,[string]$Password)
        $AuthString = "{0}:{1}" -f $Username,$Password
        $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
        return "Basic $([Convert]::ToBase64String($AuthBytes))"
}

#$UrlRoot = "http://localhost:56796"
$UrlRoot = "http://ind2q00dbapi01.qa.local"


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