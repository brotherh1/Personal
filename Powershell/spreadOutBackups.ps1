<####################################
# Pass this script the target cluster - target DBA01 - and dry =0 to see how the backups will be offset.
# Developed: 

\\XTINP1DBA01\GitHub\dbops_workingfolders\dbops\Harold\powerShell\spreadOutBackups.ps1 -targetCluster "xtnvp3cl18" -invServer "XTNVP1DBA01\I1"-dryRun 0
#####################################>
PARAM(
	
 		[Parameter(Position=0)]
		[Alias("targetHost")]       
        [string] $targetCluster = "IND1P02C007",
 		
        [Parameter(Position=1)]
		[Alias("invhost")]       
        [string]$invServer = "XTINP1DBA01\DBADMIN" ,

 		[Parameter(Position=2)]
		[Alias("minOff")]       
        [int] $minutesoffSet = 20,
                	
        [Parameter(Position=3)]
		[Alias("startHour")]       
        [int] $jobStartHour = 23,

 		[Parameter(Position=4)]
		[Alias("testRun")]       
        [int] $dryrun = 1

        )

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Xml.XmlDocument");
[void][System.Reflection.Assembly]::LoadWithPartialName("System.IO");
#$pshost = Get-Host              # Get the PowerShell Host.
#$pswindow = $pshost.UI.RawUI    # Get the PowerShell Host's UI.
#$newsize = $pswindow.BufferSize # Get the UI's current Buffer Size.
#$newsize.width = 150            # Set the new buffer's width to 150 columns.
#$pswindow.buffersize = $newsize # Set the new Buffer Size as active.
#$newsize = $pswindow.windowsize # Get the UI's current Window Size.
#$newsize.width = 150            # Set the new Window Width to 150 columns.
#$pswindow.windowsize = $newsize # Set the new Window Size as active.


#IF ( (Get-PSSnapin -Name sqlserverprovidersnapin100 -ErrorAction SilentlyContinue) -eq $null )
#    {
#        Add-PsSnapin sqlserverprovidersnapin100
#    }
#IF ( (Get-PSSnapin -Name sqlservercmdletsnapin100 -ErrorAction SilentlyContinue) -eq $null )
#    {
#        Add-PsSnapin sqlservercmdletsnapin100
#    }



function update-jobSched ( [String] $instanceName, [string] $newTime )
{   
    $sqlQuery = "SELECT scheds.name,active_start_time FROM msdb..sysjobs AS jobs 
     LEFT JOIN msdb..sysjobschedules AS jobscheds ON jobs.job_id = jobscheds.job_id 
     LEFT JOIN msdb..sysschedules AS scheds ON jobscheds.schedule_id = scheds.schedule_id 
     WHERE jobs.name = 'dbMaint Backup - Daily Main (Full or Diff)'"
    
    IF($dryRun -eq 1)
    {
        write-output "[DEBUG] $instanceName"
        write-output "`t $sqlQuery"
    }


    $schName = @(invoke-sqlcmd -ServerInstance $instanceName  -Query $sqlQuery | select name, active_start_time )
    #$schedName = $schName.replace('@{name=','').replace('}','')
    $schedName = $schName.name
    $schedStart = $schName.active_start_time
    Write-output "[] Current Schedule Name: $schedName"
    Write-output "[] Current Schedule Start: $schedStart"
    $sqlUpdate = "EXEC msdb.dbo.sp_update_schedule @name = '$schedName', @active_start_time = $newTime"

    write-output "`t $sqlUpdate"
    IF($dryrun -eq 0)
    {
        invoke-sqlcmd -ServerInstance $instanceName  -Query $sqlUpdate 
    }
    Write-output " "
}
#clear
	
$myInvocation.MyCommand.Name

Get-Date
write-output " "
                                        
write-output "[] Inv Server: $invServer "
Write-output "[] Minutes off Set: $minutesoffSet"
Write-output "[] Target Cluster: $targetCluster"
$clusterOffSet = $targetCluster.substring($targetCluster.length -1) 
write-output "[] Cluster minute offset: $clusterOffSet"

$debug = $dryRun
write-output "[] Debug: $debug"

$getList_sqlCMD ="SELECT SQLInstallation,SQLServerName,IPAddress,InstanceName
     FROM [DBA].[dbo].[ExactTargetSQLInstallations]
     where sqlinstallation like '$targetCluster"+"%' "
 
IF($dryRun -eq 1)
{
    write-output "[DEBUG] Get list of instances from inventory"
    write-output "`t $getList_sqlCMD"
}

$targetInst_cursor = @(invoke-sqlcmd -ServerInstance $invServer  -Query $getList_sqlCMD | select SQLInstallation ,SQLServerName ,IPAddress,InstanceName )

#write-output $copyList_cursor.name

	$targetInst_cursor | forEach-object{  

                                        $sqlInstall = $_.SQLInstallation
                                        write-output "[] Inst Name: $sqlInstall"
                                        $sqlHost = $_.SQLServerName
                                        IF($dryRun -eq 1)
                                        {
                                            write-output "[] SourceHost: $sqlHost"
                                        }
                                        #$instOffSet = $sqlHost.substring($sqlHost.length -1) 
                                        $instOffSet = $sqlInstall.substring($sqlInstall.indexOf("\")+2 ) 
                                        IF($instOffSet -eq 0){$instOffSet=10}
                                        write-output "[] Instance Multiplier: $instOffSet * $minutesoffSet + $clusterOffSet"
                                        $instName = $_.InstanceName
                                        #$clOffSet = $sqlHost.IndexOf($instName)-1

                                        #$clusterOffSet = $sqlHost.substring($clOffSet,1) 
                                        #write-output "Cluster off set: $clusterOffSet"
                                        
                                        $now=get-date

                                        $end=$now.AddMinutes(([convert]::ToInt32($instOffSet,10)* $minutesoffSet ) + $clusterOffSet)

                                        $ts=New-TimeSpan -Start $now -End $end
                                        #IF($dryRun -eq 1)
                                        #{
                                            write-output "`t Base time: $jobStartHour 00 00"
                                            #$ts | select Hours, Minutes
                                            write-output "`t Time to add: $($ts.hours) Hours $($ts.minutes) minutes"
                                        #}

                                        IF($ts.hours -eq "0" )
                                        {
                                            $myHours = $jobStartHour
                                        }
                                        ELSE
                                        {
                                            $myHours = $ts.hours+$jobStartHour
                                        }
                                        IF($myHours -gt 23){$myHours = $myHours-24}
                                        
                                        If($myHours -lt 10 )
                                        {
                                            #write-output "preceeding zero."
                                            $jobTime = "0"+ [convert]::ToString($myHours) #+ [convert]::ToString($ts.minutes) + "00"
                                        }
                                        Else
                                        {
                                            $jobTime = [convert]::ToString($myHours) #+ [convert]::ToString($ts.minutes) + "00"
                                        }
                                        If($ts.minutes -lt 10 )
                                        {
                                            #write-output "preceeding zero."
                                            $jobTime = $jobTime +"0"+ [convert]::ToString($ts.minutes) + "00"
                                        }
                                        Else
                                        {
                                            $jobTime = $jobTime + [convert]::ToString($ts.minutes) + "00"
                                        }
                              
                                        write-output "[] Calculated job Start Time: $jobTime"
                                        write-output "  "
 
                                        update-jobSched $sqlInstall $jobTime 
                                        write-output "  "   

    }

