FUNCTION Import-SqlModule 
{
    <#
    .SYNOPSIS
        Imports the SQL Server PowerShell module or snapin.
    .DESCRIPTION
        Import-MrSQLModule is a PowerShell function that imports the SQLPS PowerShell
        module (SQL Server 2012 and higher) or adds the SQL PowerShell snapin (SQL
        Server 2008 & 2008R2).
    .EXAMPLE
         Import-SqlModule
    #>
        [CmdletBinding()]
        param ()
        TRY
            {
                $PolicyState=0
                if (-not(Get-Module -Name SQLPS) -and (-not(Get-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100 -ErrorAction SilentlyContinue))) {
                Write-Verbose -Message 'SQLPS PowerShell module or snapin not currently loaded'
                    if (Get-Module -Name SQLPS -ListAvailable) {
                        Write-Verbose -Message 'SQLPS PowerShell module found'
                        Push-Location
                        Write-Verbose -Message "Storing the current location: '$((Get-Location).Path)'"
                        if ((Get-ExecutionPolicy) -ne 'Restricted') {
                            Import-Module -Name SQLPS -DisableNameChecking -Verbose:$false
                            Write-Verbose -Message 'SQLPS PowerShell module successfully imported'
                        }
                        else{
                            Write-Warning -Message 'The SQLPS PowerShell module cannot be loaded with an execution policy of restricted'
                        }
                        Pop-Location
                        Write-Verbose -Message "Changing current location to previously stored location: '$((Get-Location).Path)'"
                    }
                    elseif (Get-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100 -Registered -ErrorAction SilentlyContinue) {
                        Write-Verbose -Message 'SQL PowerShell snapin found'
                        Add-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100
                        Write-Verbose -Message 'SQL PowerShell snapin successfully added'
                        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo') | Out-Null
                        Write-Verbose -Message 'SQL Server Management Objects .NET assembly successfully loaded'
                    }
                    else {
                        Write-Warning -Message 'SQLPS PowerShell module or snapin not found'
                    }
                }
                else {
                    Write-Verbose -Message 'SQL PowerShell module or snapin already loaded'
                }
    
            }
        CATCH
            {
                WRITE-VERBOSE "Add-PSSnapin Exception"
                $PolicyState = 2
                $returnObject = New-Object PSObject -Property @{
                        ErrorDetail = 'Add-PSSnapin Exception'
                    }
                $policystate
                $returnObject
                BREAK;
            }

    RETURN     $PolicyState
}

FUNCTION Check-HostPing ( [string] $f_targetHost, [string] $f_domain )
{
    $f_targetServer = $f_targetHost + $f_domain
    test-Connection -ComputerName $f_targetHost -Count 2 -Quiet       
}

FUNCTION Get-BasicAuthCreds 
{
    param([string]$Username,[string]$Password)
    $AuthString = "{0}:{1}" -f $Username,$Password
    $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
    return "Basic $([Convert]::ToBase64String($AuthBytes))"
}#

Function Get-DisksSpace            
{            
    <# .SYNOPSIS Grabs Hard Drive & Mount Point space information. 

    .DESCRIPTION Grabs Hard Drive & Mount Point space information. 

    .PARAMETER serverName Accepte 1 or more servernames, up to 50 at once. 

    .INPUTS Accepts pipline input of server names 

    .OUTPUTS SystemName, Name, SizeIn[KB|MB|GB], FreeIn[KB|MB|GB], PercentFree, Label 

    .NOTES None. 

    .LINK None. 

    .EXAMPLE PS> Get-DisksSpace localhost "MB" | ft
        
    .EXAMPLE
        Get-DisksSpace localhost | Out-GridView

    .EXAMPLE
        Get-DisksSpace localhost | ft

    .EXAMPLE
        Get-DisksSpace localhost | where{$_.PercentFree -lt 20} | Format-Table -AutoSize


    #>            
             
    [cmdletbinding()]            
    param            
    (            
        <#[Parameter(Mandatory)]#>            
        [Parameter(mandatory,ValueFromPipeline = $true,ValueFromPipelinebyPropertyname = $true)]            
        [ValidateCount(1,50)]            
        [string[]]$Servername='localhost',            
        [Parameter()]            
        [ValidateSet('KB', 'MB', 'GB')]            
        [string]$unit= "GB"            
    )            
 process {            
$measure = "1$unit"            
            
Get-WmiObject -computername $serverName -query "
select SystemName, Name, DriveType, FileSystem, FreeSpace, Capacity, Label
  from Win32_Volume
 where DriveType = 2 or DriveType = 3" `
| select SystemName ,            
         Name ,            
         @{Label="SizeIn$unit";Expression={"{0:n2}" -f($_.Capacity/$measure)}} ,            
         @{Label="FreeIn$unit";Expression={"{0:n2}" -f($_.freespace/$measure)}} ,            
         @{Label="PercentFree";Expression={"{0:n2}" -f(($_.freespace / $_.Capacity) * 100)}} ,            
          Label | WHERE { ($_.Name -ne "C:\") -AND ($_.Name -ne "D:\")}
 }            
}#function Get-DisksSpace

FUNCTION Get-InstanceDrive( [string] $f_targetInstance, [string] $f_dryRun )
{

    SWITCH( $f_targetInstance )
        {
            {($_ -LIKE "*16")} {$instDrive = 'X:'; BREAK}
            {($_ -LIKE "*15")} {$instDrive = "W:"; BREAK}
            {($_ -LIKE "*14")} {$instDrive = 'V:'; BREAK}
            {($_ -LIKE "*13")} {$instDrive = 'U:'; BREAK}
            {($_ -LIKE "*12")} {$instDrive = 'S:'; BREAK}
            {($_ -LIKE "*11")} {$instDrive = 'P:'; BREAK}
            {($_ -LIKE "*10")} {$instDrive = 'O:'; BREAK}
            {($_ -LIKE "*9") } {$instDrive = 'N:'; BREAK}
            {($_ -LIKE "*8") } {$instDrive = "M:"; BREAK}
            {($_ -LIKE "*7") } {$instDrive = 'L:'; BREAK}
            {($_ -LIKE "*6") } {$instDrive = 'K:'; BREAK}
            {($_ -LIKE "*5") } {$instDrive = 'J:'; BREAK}
            {($_ -LIKE "*4") } {$instDrive = 'H:'; BREAK}
            {($_ -LIKE "*3") } {$instDrive = 'G:'; BREAK}
            {($_ -LIKE "*2") } {$instDrive = 'F:'; BREAK}
            {($_ -LIKE "*1") } {$instDrive = 'E:'; BREAK}
            default {
                        WRITE-VERBOSE "[ALERT] Uknown instance Drive"
                        $PolicyState = 2
                        $returnObject = New-Object PSObject -Property @{
                                ErrorDetail = 'Uknown location'
                            }
                        $policystate
                        $returnObject
                        RETURN;
                    }    
        } #SWITCH

    RETURN $instDrive

}

FUNCTION Check-WorkItemStatus
{
    PARAM ( 
            [string] $workItem,
            [string] $BasicCreds 
          )

    $workItem = $workItem.toLower()
    $policyEndpoint = "/service/gus/workitem/$workItem" 
   
    #WRITE-VERBOSE "[] Processing: $policyEndpoint"

    $policyEndpointList = @( $policyEndpoint )

    $PSObjectOutput = New-Object System.Object
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name ServerInstance –Value $serverinstance
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name Policy –Value $policy
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name Action –Value $action
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name PolicyEndpoint –Value $policyEndpoint
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name PolicyEndpointList –Value $policyEndpointList
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name ActionEndpoint –Value $actionEndpoint
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name ActionEndpointList –Value $actionEndpointList

    #Hit some endpoints
    TRY
        {
            #WRITE-VERBOSE `t"Invoke-RestMethod -TimeoutSec 900 -Uri `"$URLRoot/$policyEndpointList`" -Method GET -Headers @{`"Authorization`"=`"`$BasicCreds`"}"
            $policyResults =  $policyEndpointList | %{Invoke-RestMethod -TimeoutSec 900 -Uri "$URLRoot/$($_)" -Method GET -Headers @{"Authorization"="$BasicCreds"}}
        }
    CATCH
        {
            $myDetail = $_.Exception.Message -replace('The remote server returned an error: ','')
            $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name ErrorMessage_EndpointCheck –Value $myDetail

            IF($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) # Display GET ERROR
                {  
                    $policyResults = @{ Status = "RED"; Value = "3"; State = "CRITICAL"; DETAIL = "$myDetail"; }
                }
            ELSE
                {
                    $policyResults = @{ Status = "RED"; Value = "3"; State = "CRITICAL"; DETAIL = "CALL DBA"; }
                }
            IF( $myDetail -eq "(401) UnAuthorized." ) { WRITE-HOST $myDetail -f RED; $PSObjectOutput | Select-Object @{N='ErrorMessage'; E={$_.ErrorMessage_EndpointCheck}}; BREAK }
        }

    IF( ($policyResults.Value -ne "0") -AND ($policyResults.State -eq "CRITICAL") ) 
        {
            WRITE-VERBOSE `t`t"Process Failure - No action "
        }

    $policyResults
}

FUNCTION Create-workItem
{
    PARAM ( 
            [string] $subject,
            [string] $details,
            [string] $status,
            [string] $BasicCreds 
          )

    #SFMC Database Provisioning - TEST
    $productTag = 'a1aB0000000CW1zIAG'

    #windows
    #$productTag = ''

    $actionEndpoint = "/service/gus/userstory" 
   
    #WRITE-VERBOSE "[] Processing: $policyEndpoint"

    $actionEndpoint = @( $actionEndpoint )

    $PSObjectOutput = New-Object System.Object
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name ServerInstance –Value $serverinstance
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name Policy –Value $policy
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name Action –Value $action
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name PolicyEndpoint –Value $policyEndpoint
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name PolicyEndpointList –Value $policyEndpointList
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name ActionEndpoint –Value $actionEndpoint
    $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name ActionEndpointList –Value $actionEndpointList

    #Hit some endpoints
    TRY
        {
            $setBody = "{
                            `"subject`":`"$subject`",
                            `"details`":`"$details`",
                            `"productTag`":`"$productTag`",
                            `"status`":`"$status`"
                        }"
            #WRITE-VERBOSE `t"Invoke-RestMethod -TimeoutSec 900 -Uri `"$URLRoot/$policyEndpointList`" -Method GET -Headers @{`"Authorization`"=`"`$BasicCreds`"}"
            $setBody

            $actionResults =  $actionEndpoint | %{Invoke-RestMethod -TimeoutSec 900 -Uri "$URLRoot/$($_)" -Method POST -Headers @{"Authorization"="$BasicCreds"} -ContentType "application/json" -body $setBody}
        }
    CATCH
        {
            $myDetail = $_.Exception.Message -replace('The remote server returned an error: ','')
            $PSObjectOutput  | Add-Member –MemberType NoteProperty –Name ErrorMessage_EndpointCheck –Value $myDetail

            IF($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) # Display GET ERROR
                {  
                    $actionResults = @{ Status = "RED"; Value = "3"; State = "CRITICAL"; DETAIL = "$myDetail"; }
                }
            ELSE
                {
                    $actionResults = @{ Status = "RED"; Value = "3"; State = "CRITICAL"; DETAIL = "CALL DBA"; }
                }
            IF( $myDetail -eq "(401) UnAuthorized." ) { WRITE-HOST $myDetail -f RED; $PSObjectOutput | Select-Object @{N='ErrorMessage'; E={$_.ErrorMessage_EndpointCheck}}; BREAK }
        }

    IF( ($actionResults.Value -ne "0") -AND ($policyResults.State -eq "CRITICAL") ) 
        {
            WRITE-VERBOSE "`t`t Process Failure - No action "
        }

    $actionResults
}

FUNCTION User-Reclaim ( [string] $f_targetCluster, [Object[]] $f_instance, [boolean] $f_decomm, [boolean] $f_DryRun )
{
    WRITE-VERBOSE "`t`t Get-InstanceDrive $($f_instance.OwnerGroup)"
    $targetDrive = Get-InstanceDrive $f_instance.OwnerGroup
    WRITE-VERBOSE "`t`t Get-DisksSpace $clusterFQDN, $($f_instance.Name), $($f_instance.OwnerGroup), $($targetDrive)*;"
    $diskList = Get-DisksSpace $($instance.Name) | WHERE {$_.Name -like "$($targetDrive)*"}

    $usedLUNCount = 0
    $userLUNCount = 0
    $reclaimList = @()

    ForEach($disk in $diskList)
        {
            WRITE-VERBOSE "`t $($disk.SystemName) $($disk.Name) $($disk.SizeInGB) $($disk.FreeInGB) $($disk.PercentFree) $($disk.Label)"
            If( $disk.Name -like '*Data*' -OR $disk.Name -like '*Log*' ) #-AND $disk.PercentFree -gt $searchPercent )
                {
                    WRITE-VERBOSE "[WARNING] User LUN found: $($disk.Name )"
                    $containsDataLUN= $true

                    #check does SQL have use of drive 
                    $selectSQL = "SELECT name from sysaltfiles where filename like '$($disk.Name )%'"

                    $fileName = $null
                    $fileName = Invoke-Sqlcmd -ServerInstance "$($f_instance.name)\$($f_instance.ownergroup)" -Database Master -Query $selectSQL -QueryTimeout 65535 | select -EXP name

                    IF( $fileName.Count -eq 0 )
                        {
                            WRITE-VERBOSE "[WARNING] EMPTY LUN FOUND: $($disk.Name )%"
                            $reclaimList += $disk.Label
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "[INFO] That LUN is being used by file(s): "
                            ForEach( $file in $fileName )
                                {
                                    WRITE-VERBOSE "`t`t $file"
                                }
                            $usedLUNCount ++
                        }

                    $userLUNCount ++
                }
        } #forEach DISK
    
    $dt = New-Object System.Data.Datatable
    [void]$dt.Columns.Add("Instance")
    [void]$dt.Columns.Add("action")
    [void]$dt.Columns.Add("decomm")
    [void]$dt.Columns.Add("LUN_LABEL")

    IF( $userLUNCount -eq $usedLUNCount )
        {
            WRITE-VERBOSE "[OK] $($f_instance.name) has no user LUNs to reclaim $($usedLUNCount):$($userLUNCount)"  

            IF( $f_decomm -AND $userLUNCount -eq 0)
                {
                    WRITE-VERBOSE "[WARNING] This instance is with others marked for decommissioning."
                    WRITE-VERBOSE "`t Check central inventory for workitem for instance: $($f_instance.name)"
                    $selectSQL = "SELECT ServerDescription FROM [DBA].[dbo].[ExactTargetSQLInstallations] WHERE SQLServerName = '$($f_instance.name)' AND serverDescription like '%Instance Decomm W%'"

                    $ServerDescription = $null
                    $ServerDescription = Invoke-Sqlcmd -ServerInstance $targetInvServer -Database $targetInvDB -Query $selectSQL -QueryTimeout 65535 | select -EXP ServerDescription

                    If( $ServerDescription.Count -eq 0 )
                        {
                            WRITE-HOST "[ALERT] No workitem found in central inventory"
                            [void]$dt.Rows.Add("$($f_instance.name)","CREATE NEW WI","Shutdown Services","OFFLINE/DISABLE")
                                    
                            [void]$dt.Rows.Add("$($f_instance.name)","UPDATE INV","Shutdown Services","")
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "[OK] Workitem found : $($ServerDescription)"
                            WRITE-VERBOSE "`t $(Check-WorkItemStatus $ServerDescription.replace('[S0] Instance Decomm ','')) "
                            $workItemStatus = $(Check-WorkItemStatus $ServerDescription.replace('[S0] Instance Decomm ','') $BasicCreds)

                            IF( $workItemStatus.Status__c -eq "Closed" )
                                {
                                    WRITE-HOST "[ALERT] $($f_instance.name) $($ServerDescription.replace('[S0] Instance Decomm ','')) Status: $($workItemStatus.Status__c) "
                                    [void]$dt.Rows.Add("$($f_instance.name)","CREATE NEW WI","Shutdown Services","ReIssue")
                                           
                                    [void]$dt.Rows.Add("$($f_instance.name)","UPDATE INV","Shutdown Services","ReIssue")
                                }
                            ELSE
                                {
                                    WRITE-VERBOSE "[OK] $($ServerDescription.replace('[S0] Instance Decomm ','')) Status: $($workItemStatus.Status__c) "
                                }
                        }
                }#end IF( $f_decomm )
        }
    ELSE
        {
            IF( $usedLUNCount -eq 0 )
                {
                    WRITE-HOST "[ALERT] $($f_instance.name) has LUN(s) to reclaim $($usedLUNCount):$($userLUNCount)" 
                            

                            IF( $f_decomm )
                                {
                                    WRITE-VERBOSE "`t Check central inventory for workitem for instance: $($f_instance.name)"
                                    $selectSQL = "SELECT ServerDescription FROM [DBA].[dbo].[ExactTargetSQLInstallations] WHERE SQLServerName = '$($f_instance.name)' AND serverDescription like '%Instance Decomm W%'"

                                    $ServerDescription = $null
                                    $ServerDescription = Invoke-Sqlcmd -ServerInstance $targetInvServer -Database $targetInvDB -Query $selectSQL -QueryTimeout 65535 | select -EXP ServerDescription

                                    If( $ServerDescription.Count -eq 0 ) # no recorded user story to sysadmin
                                        {
                                            WRITE-HOST "[ALERT] No Work item found"
                                            [void]$dt.Rows.Add("$($f_instance.name)","CREATE NEW WI","Shutdown Services","OFFLINE/DISABLE")

                                        }
                                    ELSE
                                        {
                                            WRITE-VERBOSE "[OK] $($f_instance.name) is being decommissioned: $($ServerDescription)"

                                            WRITE-VERBOSE "`t $(Check-WorkItemStatus $ServerDescription.replace('[S0] Instance Decomm ','')) "
                                            $workItemStatus = $(Check-WorkItemStatus $ServerDescription.replace('[S0] Instance Decomm ','') $BasicCreds)
                                                    
                                            IF( $workItemStatus.Status__c -eq "Closed" )
                                                {
                                                    WRITE-HOST "[ALERT] $($ServerDescription.replace('[S0] Instance Decomm ','')) Status: $($workItemStatus.Status__c) "
                                                    [void]$dt.Rows.Add("$($f_instance.name)","Instance","CREATE NEW WI","ReIssue")

                                                    ForEach( $userLUN in $reclaimList )
                                                        {
                                                            [void]$dt.Rows.Add("$($f_instance.name)","Instance","","$($userLUN)")
                                                        }         

                                                    [void]$dt.Rows.Add("$($f_instance.name)","UPDATE CENTRAL INVENTORY","","None")
                                                }
                                            ELSE
                                                {
                                                    WRITE-VERBOSE "[OK] $($ServerDescription.replace('[S0] Instance Decomm ','')) Status: $($workItemStatus.Status__c) "
                                                }
                                        }
                                }
                            ELSE
                                {
                                            


                                    WRITE-VERBOSE "`t Check local worktable for workitem for instance: $($f_instance.name)"
                                    $selectSQL = "SELECT top 1 WorkItemID FROM [WorkTableDB].[dbo].[WorkItemLog] WHERE subject = 'reclaim unused storage' and status = 'NEW' and recordType = 'USER STORY'"

                                    $localWorkItemRecord = $null
                                    $localWorkItemRecord = Invoke-Sqlcmd -ServerInstance "$($f_instance.name)\$($f_instance.OwnerGroup)" -Database "WORKTABLEDB" -Query $selectSQL -QueryTimeout 65535 | select -EXP WorkItemID

                                    If( $localWorkItemRecord.Count -eq 0 ) # no recorded user story to sysadmin
                                        {
                                            WRITE-HOST "[ALERT] No Work local item found"
                                            [void]$dt.Rows.Add("$($f_instance.name)","CREATE NEW WI","Reclaim LUNs","STAY ONLINE")

                                            ForEach( $userLUN in $reclaimList )
                                                {
                                                    [void]$dt.Rows.Add("$($f_instance.name)","OFFline and","Reclaim LUN","$($userLUN)")
                                                }         

                                            [void]$dt.Rows.Add("$($f_instance.name)\$($f_instance.OwnerGroup)","UPDATE LOCAL INVENTORY","Reclaim LUNs","NEW")

                                        }
                                    ELSE
                                        {
                                            WRITE-VERBOSE "[OK] $($f_instance.name) previous LUN reclaim request: $($localWorkItemRecord)"

                                            WRITE-VERBOSE "`t $(Check-WorkItemStatus $localWorkItemRecord) "
                                            $localWorkItemStatus = $(Check-WorkItemStatus $localWorkItemRecord $BasicCreds)

                                            IF( ($localWorkItemStatus.Status__c -eq "Closed") -OR ($localWorkItemStatus.Status__c -eq "Never") -OR ($localWorkItemStatus.Status__c -eq "Duplicate") )
                                                {
                                                    WRITE-HOST "[ALERT] $($localWorkItemRecord) Status: $($localWorkItemStatus.Status__c) "
                                                    [void]$dt.Rows.Add("$($f_instance.name)","CREATE NEW WI","Reclaim LUNs","STAY ONLINE")

                                                    ForEach( $userLUN in $reclaimList )
                                                        {
                                                            [void]$dt.Rows.Add("$($f_instance.name)","OFFline and","Reclaim LUN","$($userLUN)")
                                                        }         

                                                    [void]$dt.Rows.Add("$($f_instance.name)\$($f_instance.OwnerGroup)","UPDATE LOCAL INVENTORY","Reclaim LUNs","ReIssue")
                                                }
                                            ELSE
                                                {
                                                    WRITE-VERBOSE "[OK] $($localWorkItemRecord) Status: $($localWorkItemStatus.Status__c) "
                                                }
                                        }
                                }

                        <#     ForEach( $userLUN in $reclaimList )
                                {
                                    [void]$dt.Rows.Add("$($f_instance.name)","OFFline and","Reclaim LUN","$($userLUN)")
                                }         

                            IF( $f_decomm )
                                {
                                    [void]$dt.Rows.Add("$($f_instance.name)","UPDATE INV","Shutdown Services","OFFLINE/DISABLE")
                                }
                            ELSE
                                {
                                    [void]$dt.Rows.Add("$($f_instance.name)","UPDATE INV","Reclaim LUNs","STAY ONLINE")
                                }
                        #>
                }
            ELSE
                {
                    WRITE-VERBOSE "[WARNING] $($f_instance.name) has unused LUN(s) $($usedLUNCount):$($userLUNCount)"
                    WRITE-VERBOSE "Check instance set up - files might be on the incorrect mounts"
                    ForEach( $userLUN in $reclaimList )
                        {
                            WRITE-VERBOSE "`t`t Unused Mounts: $($userLUN)"
                        }
                }
        }
    #RETURN OBJECT LIST
    $dt

}

FUNCTION Something-Else ( [Object[]] $f_diskList )
{
    ForEach( $disk in $f_diskList )
        {
            WRITE-VERBOSE "`t`t $($disk.SystemName) $($disk.Name) $($disk.SizeInGB) $($disk.FreeInGB) $($disk.PercentFree) $($disk.Label)"
                                                 
            #Baseline drives that could be dropped during decom
            If( $searchType -eq "system" -AND $disk.Name -like '*BAK*' ) #-AND $disk.PercentFree -gt $searchPercent )
                {
                    WRITE-VERBOSE "BAK LUN found more than $searchPercent Free: "
                    $containsDataLUN= $true
                    #check does DB have use of drive    
                }
            If( $searchType -eq "system" -AND $disk.Name -like '*UTILITY' ) #-AND $disk.PercentFree -gt $searchPercent )
                {
                    WRITE-VERBOSE "UTILITY LUN found more than $searchPercent Free: "
                    $containsLogLUN= $true
                    #check does DB have use of drive    
                }
            If( $searchType -eq "system" -AND $disk.Name -like '*SQLImportFiles' ) #-AND $disk.PercentFree -gt $searchPercent )
                {
                    WRITE-VERBOSE "SQLImportFiles LUN found more than $searchPercent Free: "
                    $containsLogLUN= $true
                    #check does DB have use of drive    
                }
        }
}

Function Test-ClusterLUNs
{
     [CmdletBinding(SupportsShouldProcess)]
     PARAM(
            [Parameter(Mandatory=$true)] [STRING] $Target,
            [STRING] $SearchType,
            [STRING] $AuthString,
            [Parameter( Mandatory = $FALSE,
                HelpMessage = 'Supply a credential object to access the Zarga API.')]
                [ValidateNotNull()]
                [System.Management.Automation.PSCredential]
                [System.Management.Automation.Credential()]
                $Credential = [System.Management.Automation.PSCredential]::Empty,
            [boolean] $SuppressDetail = $false,
            [boolean] $DryRun = $false
        )

    TRY{
            $PolicyState = Import-SqlModule              
             
IF(-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
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

            IF( $env:USERDNSDOMAIN.Replace('ET','QA') -eq 'QA.LOCAL' )
                {
                    $URLRoot ='http://ind2q00dbapi01.qa.local'
                }
            ElSE
                {
                    $URLRoot = 'https://zarga.internal.marketingcloud.com'
                    # Override while load balancer is misbehaving...
                    #$URLRoot = 'https://IND1CS0DBAAPI01.xt.local'
                }
 
            IF(!$Credential.username)
                {
                    $cred = Get-Credential
                }
            ELSE
                {
                    $Cred = $credential
                }

            $BasicCreds = Get-BasicAuthCreds $cred.UserName $cred.GetNetworkCredential().password   
          
            $currentDomain = "."+ $env:userDNSdomain.Replace("CT.","")

            SWITCH($currentDomain)
            {
                {($_ -eq ".QA.LOCAL")} {$targetInvDB = "DBA"; $targetInvServer = "XTNVP1DBA01\I1"; $domain = ".QA.LOCAL"; BREAK}
                {($_ -eq ".INTERNAL.SALESFORCE.COM")} {$targetInvDB = "DBA"; $targetInvServer = "IND2Q00DBA01\I1"; $domain = ".QA.LOCAL"; BREAK}
                {($_ -eq ".XT.LOCAL") -AND ($Target -like "xtnv*" -OR $Target -like "las*")} {$targetInvDB = "DBA"; $targetInvServer = "XTNVP1DBA01\I1"; $domain = ".XT.LOCAL"; BREAK}
                {($_ -eq ".XT.LOCAL")} {$targetInvDB = "DBA"; $targetInvServer = "XTINP1DBA01\DBAdmin"; $domain = ".XT.LOCAL"; BREAK}
                DEFAULT {
                            WRITE-VERBOSE "[ALERT] Unsupported Domain"
                            $PolicyState = 2
                            $returnObject = New-Object PSObject -Property @{
                                    ErrorDetail = 'Unsupported Domain'
                                }
                            $policystate
                            $returnObject
                            RETURN; 
                        }
            }
            $clusterFQDN = $Target + $domain

            WRITE-VERBOSE "[] Started: $((Get-Date).ToString())"
            WRITE-VERBOSE "[] TargetCluster: $clusterFQDN"
            WRITE-VERBOSE "[] Target INV: $targetInvServer"
            WRITE-VERBOSE "[] Target INV DB: $targetInvDB"
            WRITE-VERBOSE "[] Suppress Detail: $SuppressDetail"
            WRITE-VERBOSE "[] Dry Run: $DryRun"
            WRITE-VERBOSE " "
            WRITE-VERBOSE "[] Sanity check - does target cluster exist in inventory? "

            $selectSQL = "SELECT Count(ServerDescription) as Instcount FROM [DBA].[dbo].[ExactTargetSQLInstallations] WHERE serverGroupName = 'Cluster $($Target)'"

            $clusterCount = 0
            #$fileName =  Invoke-command -ComputerName $targetServer -Credential $mycreds -ScriptBlock {Invoke-Sqlcmd -ServerInstance $using:targetSQLserver -Database Master -Query $using:selectSQL -QueryTimeout 65535} | select -EXP name
            $clusterCount = Invoke-Sqlcmd -ServerInstance $targetInvServer -Database $targetInvDB -Query $selectSQL -QueryTimeout 65535 | select -EXP Instcount

            If( $clusterCount -eq 0 )
                {
                    WRITE-VERBOSE "[ALERT] Cluster not found in inventory - RUN AWAY!"
                    RETURN;
                }
            ELSE
                {
                    WRITE-VERBOSE "[OK] Cluster found in inventory - $($clusterCount) instances"

                    WRITE-VERBOSE "[] Sanity check - Check-HostPing $Target $domain"
                    if ( Check-HostPing $Target $domain ) 
                        {
                            $decommCount = 0
                            WRITE-VERBOSE "`t`t Check for other decommed instances?"
                            #  Function to query inventory for and instance inst clusterGroupName where serverDescription like '[S0] Instance Decomm W%'
                            $selectSQL = "SELECT Count(ServerDescription) as Instcount FROM [DBA].[dbo].[ExactTargetSQLInstallations] WHERE serverGroupName = 'Cluster $($Target)' AND serverDescription like '%Instance Decomm W%'"

                            #example for doblehop issue  Invoke-command -ComputerName $targetServer -Credential $mycreds -ScriptBlock {Invoke-Sqlcmd -ServerInstance $using:targetSQLserver -Database Master -Query $using:selectSQL -QueryTimeout 65535} 
                            $decommCount += Invoke-Sqlcmd -ServerInstance $targetInvServer -Database $targetInvDB -Query $selectSQL -QueryTimeout 65535 | select -EXP Instcount
                         }
                    ELSE
                        {  
                            WRITE-VERBOSE "[WARNING] Cluster $($Target)$domain is not Pinging"
                            WRITE-VERBOSE "`t`t Check inventory if decomm requested based on serverDescription like '%Cluster Decomm requested W%'"
                            $selectSQL = "SELECT ServerDescription  FROM [DBA].[dbo].[ExactTargetSQLInstallations] WHERE SQLServerName = '$($instance.Name)' AND serverDescription like '%Cluster Decomm W%'"

                            $ServerDescription = $null
                            $ServerDescription = Invoke-Sqlcmd -ServerInstance $targetInvServer -Database $targetInvDB -Query $selectSQL -QueryTimeout 65535 | select -EXP ServerDescription

                            If( $ServerDescription.Count -eq 0 )
                                {
                                    WRITE-VERBOSE "[ALERT] TARGET $($Target)$domain is not Pinging - check SQL network name and inventory."
                                    RETURN;
                                }
                            ELSE
                                {
                                    WRITE-VERBOSE "[OK] Cluster is being decommisioned: $($ServerDescription)"
                                    RETURN;
                                }
                        }
                    If( $decommCount -eq 0 )
                        {
                            WRITE-VERBOSE "[OK] Nothing else Decommissioned in this cluster. $($decommCount):$($clusterCount)"
                            [boolean] $decomm = $false
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "[WARNING] This cluster has instances marked for decomm: $($decommCount):$($clusterCount)"
                            [boolean] $decomm = $true
                        }
                }

            IF( (get-service -computer $clusterFQDN | where name -eq "ClusSvc" | select -exp status ) -eq "Running" )
                {   # Process a cluster 
                    $instanceList = Get-ClusterResource -Cluster $clusterFQDN | Where-Object {$_.Name -like "SQL Network Name*"} | select @{name='Name'; Expression={$_.name.replace('SQL Network Name (','').replace(')','')}}, ownergroup
      
                    $responses = @()
                    ForEach($instance in $instanceList)
                        {
                            WRITE-VERBOSE " "
                            WRITE-VERBOSE "[] Processing: $($instance.Name)\$($instance.OwnerGroup)"

                            WRITE-VERBOSE "`t`t Check-HostPing $($instance.Name)$domain"
                            if ( Check-HostPing $($instance.Name) $domain ) 
                                {   
                               
                                    # FUNCTION TO TEST USER LUNS
                                    If( $searchType -eq "userReclaim" )
                                        {
                                            WRITE-VERBOSE "[] Process user-Reclaim $($Target) $($instance) $($decomm) $($DryRun)"
                                            $responses += $(User-Reclaim $Target $instance $decomm $DryRun)
                                            # TEST LUNS 
                                        }
                                    ELSEIF( $serachType -eq "<SomethingElse>" )
                                        {
                                            Something-Else $diskList
                                        }
                                }
                            ELSE
                                {  
                                    WRITE-VERBOSE "[WARNING] Instance $($instance.Name)$domain is not Pinging"
                                    WRITE-VERBOSE "`t`t Check inventory if decomm requested based on serverDescription like '%Instance Decomm requested W%'"
                                    $selectSQL = "SELECT ServerDescription  FROM [DBA].[dbo].[ExactTargetSQLInstallations] WHERE SQLServerName = '$($instance.Name)' AND serverDescription like '%Instance Decomm W%'"

                                    $ServerDescription = $null
                                    $ServerDescription = Invoke-Sqlcmd -ServerInstance $targetInvServer -Database $targetInvDB -Query $selectSQL -QueryTimeout 65535 | select -EXP ServerDescription

                                    If( $ServerDescription.Count -eq 0 )
                                        {
                                            WRITE-VERBOSE "[ALERT] Cluster $($instance.Name)$domain is not Pinging - check SQL network name and inventory."
                                        }
                                    ELSE
                                        {
                                            WRITE-VERBOSE "[OK] Instance is being decommisioned: $($ServerDescription)"
                                        }
                                }
                        }# ForEach Insance

                    <##############################################
                    # Process responses
                    ##############################################>
                    If( $searchType -eq "userReclaim" )
                        {
                            $body = $null
                            IF( $($responses | where {$_.action -eq 'CREATE NEW WI' -and $_.decomm -eq 'Shutdown Services'} | measure-object | Select-Object -expand count) -gt 0 )
                                {
                                    $workItemSubject = "TEST Reclaim LUNs and shutdown resources in cluster: $($Target)"
                                    WRITE-VERBOSE "Subject: $($workItemSubject)"
                                    WRITE-VERBOSE "Body: SysAdmins - Please unmount any LUN(s) listed below and inform storage they can be reclaimed."
                                        $body = "SysAdmins - Please unmount any LUN(s) listed below and inform storage they can be reclaimed."
                                    WRITE-VERBOSE "`t`t Also shutdown and disable the services for SQL instance $($f_instance.name)."
                                        $body += "`r`n Also shutdown and disable the services for SQL instance noted with 'OFFLINE/DISABLE'"
                                    WRITE-VERBOSE "`t`t This will aid in the patching project and will also help with memory pressure and overloaded nodes on some clusters."
                                        $body += "`r`n This will aid in the patching project and will also help with memory pressure and overloaded nodes on some clusters."   
                                    $returnedInstances = $responses | where {$_.action -eq 'CREATE NEW WI'} | Select-object -property Instance, LUN_LABEL | Sort-Object -Property Instance
                                    ForEach( $returnedInstance in $returnedInstances )
                                        {
                                            $body += "`r`n"
                                            WRITE-VERBOSE "Instance: $($returnedInstance.Instance) -Final Status:  $($returnedInstance.LUN_LABEL)"
                                                $body += "`r`n Instance: $($returnedInstance.Instance) -Final Status:  $($returnedInstance.LUN_LABEL)"
                                            $returnedLUNs = $responses | where {$_.Instance -eq "$($returnedInstance.Instance)" -and $_.decomm -eq 'Reclaim LUN'}
                                            ForEach( $returnedLUN in $returnedLUNs )
                                                {
                                                    WRITE-VERBOSE "`t`t $($returnedLUN.LUN_LABEL)"
                                                        $body += "`r`n`t`t $($returnedLUN.LUN_LABEL)"
                                                }
                                        }                                                             
                                }
                            ELSEIF( $($responses | where {$_.action -eq 'CREATE NEW WI' -and $_.decomm -eq 'Reclaim LUNs'} | measure-object | Select-Object -expand count) -gt 0 )
                                {
                                    $workItemSubject = "TEST Reclaim LUNS in cluster: $($Target)"
                                    WRITE-VERBOSE "Subject: $($workItemSubject)"
                                    WRITE-VERBOSE "Body: SysAdmins - Please unmount the LUN(s) listed below and inform storage they can be reclaimed."
                                        $body = "SysAdmins - Please unmount the LUN(s) listed below and inform storage they can be reclaimed."
                                    $returnedInstances = $responses | where {$_.action -eq 'CREATE NEW WI'} | Select-object -property Instance, LUN_LABEL | Sort-Object -Property Instance
                                    ForEach( $returnedInstance in $returnedInstances )
                                        {
                                            $body += "`r`n"
                                            WRITE-VERBOSE "Instance: $($returnedInstance.Instance) " #-Final Status:  $($returnedInstance.lun_label)"
                                                $body += "`r`n Instance: $($returnedInstance.Instance) " #-Final Status:  $($returnedInstance.lun_label)"
                                            $returnedLUNs = $responses | where {$_.Instance -eq "$($returnedInstance.Instance)" -and $_.decomm -eq 'Reclaim LUN'}
                                            ForEach( $returnedLUN in $returnedLUNs )
                                                {
                                                    WRITE-VERBOSE "`t`t $($returnedLUN.LUN_LABEL)"
                                                        $body += "`r`n`t`t $($returnedLUN.LUN_LABEL)"
                                                }
                                        }
                                } 

                            #WRITE-VERBOSE "Body: $($body)"
                            IF( $body -eq $null )
                                {
                                    WRITE-VERBOSE " "
                                    WRITE-VERBOSE "[OK] Nothing to reclaim in the cluster"
                                }   
                            ELSE
                                {
                                     
                                    IF( $DryRun )
                                        {
                                            WRITE-VERBOSE "[Dry Run] Create-workItem $workItemSubject 'Body' '' 'BasicCreds' "              
                                        }
                                    ELSE
                                        {
                                            WRITE-VERBOSE "`t Create-workItem $workItemSubject 'Body' '' 'BasicCreds' " 
                                            $workItemCreate = $(Create-workItem $workItemSubject $body '' $BasicCreds)

                                            IF( $decomm )
                                                {
                                                    #WRITE-HOST "[ALERT] Update SQL inventory description '[S0] Instance Decomm W-########'"
                                                    WRITE-HOST "[ALERT] Updating SQL inventory description '[S0] Instance Decomm $($workItemCreate.Name)'"

                                                    $updateInstances = $responses | where {$_.action -eq 'UPDATE INV'} | Select-object -property Instance, LUN_LABEL | Sort-Object -Property Instance
                                                    ForEach( $updateInstance in $updateInstances )
                                                        {
                                                            $updateSQL = "UPDATE dba.dbo.ExactTargetSqlInstallations SET [ServerDescription] = REPLACE([ServerDescription], LEFT([ServerDescription],4), '[S0] Instance Decomm $($workItemCreate.Name) '), servertype = 'Down', rptindexes = 0, rptinst=0, rptinstdbs=0, rptmatrix=0, rptspace=0, rptbackups=0 WHERE SQLServerName = '$($updateInstance.Instance)'";
                                                            WRITE-VERBOSE $updateSQL
                                                            Invoke-Sqlcmd -ServerInstance $targetInvServer -Database $targetInvDB -Query $updateSQL -QueryTimeout 65535 
                                                        }
                                                }
                                            ELSE # must be local LUN reclaims not decomm
                                                {
                                                     $updateInstances = $responses | where {$_.action -eq 'UPDATE LOCAL INVENTORY'} | Select-object -property Instance, LUN_LABEL | Sort-Object -Property Instance
                                                     ForEach( $updateInstance in $updateInstances )
                                                        {
                                                            WRITE-VERBOSE "Update local workTableDB: $($updateInstance.Instance) with workitem: $($workItemCreate.Name)"
                                                            $returnedLUNs = $responses | where {$_.Instance -eq "$($returnedInstance.Instance)" -and $_.decomm -eq 'Reclaim LUN'}

                                                            $detail = ""
                                                            ForEach( $returnedLUN in $returnedLUNs )
                                                                {
                                                                    #WRITE-VERBOSE "`t`t $($returnedLUN.LUN_LABEL)"
                                                                    $detail += "($returnedLUN.LUN_LABEL) "
                                                                }

                                                            $insertSQL = "INSERT INTO [dbo].[WorkItemLog] ([WorkItemAlertID],[WorkItemID],[WorkItemGUID],[RecordType],[Status],[Subject],[Detail],[ProductTag],[CreationDate])
                                                            SELECT [UTILITY].[Info].[fnAlertIDHash] ( 'reclaim unused storage' ,'','' ), '$($workItemCreate.Name)','$($workItemCreate.ID)','USER STORY','NEW','reclaim unused storage','$($detail)','$($workItemCreate.Product_Tag__c)','$(Get-Date)';"

                                                            Invoke-Sqlcmd -ServerInstance "$($updateInstance.Instance)" -Database "WorkTableDB" -Query $insertSQL -QueryTimeout 65535
                                                        }
                                                }
                                        }
                                }
                        }
                    ELSEIF( $searchType -eq "<SomethingElse>" )
                        {
                            Something-Else $diskList
                        }
                    
                    $responses

                }
            ELSE
                {   # Process a stand alone not complete or tested....
                    WRITE-VERBOSE " "
                    $targetServer = $clusterFQDN
                    WRITE-VERBOSE "[] Processing: $targetServer"
                    $targetSQLserver = $targetServer +"\"+ $targetInstance
                    $targetDrive = Get-InstanceDrive $targetServer
                    WRITE-VERBOSE "`t`t Get-DisksSpace $clusterFQDN, $targetServer, $targetInstance, $targetDrive, $dryRun;"
                    $targetDrive = $targetDrive +"*"
                    WRITE-VERBOSE "`t`t Get-DisksSpace $clusterName, NodeName, $targetInstance, $targetDrive, $dryRun;"
                    $singleNode = invoke-command -computername $clusterFQDN -scriptblock { systeminfo } | findStr /r /C:"Host Name:"   
                    $node = $singleNode -replace "Host Name:                 ",""

                    if ( Check-HostPing $node $domain ) 
                            {
                                WRITE-VERBOSE "`t`t Get-DisksSpace $clusterName, $node, $dryRun;"
                            }
                        ELSE
                            {  
                                WRITE-VERBOSE "[WARNING] Machine $node is not Pinging - check everything."
                                $PolicyState = 2
                                $returnObject = New-Object PSObject -Property @{
                                        ErrorDetail = 'Machine $node is not Pinging - check everything'
                                    }
                                $policystate
                                $returnObject
                                BREAK
                            }
                }
        }
    CATCH{
            $PolicyState= 2;
            $PolicyState;
            $Error
            WRITE-VERBOSE "Something bad happened."
            RETURN    
        }
}

<#####################################################################
Purpose:  
    This script will interrogate a cluster for all instances and LUNs. 
    Any thresholds need to be stored in a table or defined in declarative data.
    This script should only need cluster name to function.  It will require the authString once in ZARGA.

History:  
    20180905 hbrotherton W-000000000 Created
    YYYYMMDD USERID W-000000000 This is what I changed.
Comments:
    Anything you feel is important to share that is not the "purpose"
    
    SearchType "UserReclaim" will looks at each instance to see what LUNs are assigned and compare that list to what is in sysaltFiles

    SearhType "BaseLine" = BAK, SQLImport, and UTILITY LUNS search to make certain baselining LUNS are correct.

   

    Code used for testing
        . .\Diskfunctions.ps1

        test-ClusterLUNs -Target "las1p03c041" -SearchType "UserReclaim" -DryRun 0 -verbose
        test-ClusterLUNs -Target "xtnvcl06"    -SearchType "UserReclaim" -DryRun 0 -verbose
        test-ClusterLUNs -Target "xtnvcl11"    -SearchType "UserReclaim" -DryRun 1 -verbose
        test-ClusterLUNs -Target "xtnvp3cl18"  -SearchType "UserReclaim" -DryRun 0 -verbose

        test-ClusterLUNs -Target "las1p03c041" -SearchType "BaseLine" -verbose


Quip Documentaion:
    https://salesforce.quip.com/wehMA339iOoj
#######################################################################>

#$answers = test-ClusterLUNs -Target "ATL1P04C005" -SearchType "UserReclaim" -Credential $cred -DryRun 0 -verbose
<#
IF( $($answers | where {$_.action -eq 'CREATE NEW WI' -and $_.decomm -eq 'Shutdown Services'} | measure-object | Select-Object -expand count) -gt 0 )
{
    WRITE-hOST "shutdown"
}
ELSEIF( $($answers | where {$_.action -eq 'CREATE NEW WI' -and $_.decomm -eq 'Reclaim LUNs'} | measure-object | Select-Object -expand count) -gt 0 )
{
    write-host "Reclaim"
    WRITE-HOST "Subject: TEST Reclaim LUNS on cluster: $($Target)"

    $returnedInstances = $answers | Select -exp Instance lun_label | select-object -Unique | Sort-Object -Property Instance
    ForEach( $returnedinstance in $returnedInstances )
    {
        WRITE-HOST "Instance: $($returnedinstance)"
        $returnedLUNs = $answers | where {$_.Instance -eq "$($returnedinstance)" -and $_.decomm -eq 'Reclaim LUN'}
        ForEach( $returnedLUN in $returnedLUNs )
        {
            WRITE-HOST "`t`t $($returnedLUN.LUN_LABEL)"
        }

    }
}

$answers| where {$_.action -eq 'CREATE NEW WI'} | Select-object -property Instance, LUN_LABEL | Sort-Object -Property Instance

ForEach ($returnedinstance in $returnedInstances)
{
    WRITE-HOST $instAnswer.Instance

ForEach ( $answer in $answers )
{
    write-host $answer.Instance
    write-host $answer.lun_label

}
}
#>
