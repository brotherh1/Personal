process{
$cred = Get-Credential

$BasicCreds = Get-BasicAuthCreds $cred.UserName $cred.GetNetworkCredential().password

$serverinstance = 'ATL1QA1C012I12#I12'
$serverinstance = $serverinstance.replace('#','%23')

$endpointList = @(
#"/dbserver/$serverinstance/action/setmaintenance",
"/dbserver/$serverinstance/action/DisableDeprecationJobs",
"/dbserver/$serverinstance/action/DisableLogBackup",
"/dbserver/$serverinstance/action/KillLongRunningSPID",
#"/dbserver/$serverinstance/action/SetMaintenance",
"/dbserver/$serverinstance/action/StartStandardAudits",
"/dbserver/$serverinstance/action/StopAudits",
"/dbserver/$serverinstance/action/StopDeprecationJobs",
"/dbserver/$serverinstance/action/enableLogShipping",
"/dbserver/$serverinstance/action/pauseLogShipping"
)

$RequestBody = "{
    `"InMaintenance`": 0,
    `"MaintenanceDurationMinutes`": 10,
    `"Comments`": `"Just doing some stuff and things`"
  }"

#Hit some endpoints
$Results =  $endpointList | %{Invoke-RestMethod -Uri "$URLRoot/$($_)" -Method POST -Headers @{"Authorization"="$BasicCreds"}}

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

$UrlRoot = "http://localhost:56796"
#$UrlRoot = "http://ind2q00dbapi01.qa.local"


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