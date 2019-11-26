PARAM(

    [string] $sourceDB = '',
    [string] $sourceHost = '',
    [string] $targetDB = '',
    [string] $targetHost = '',
    [string] $backupFile = '',  #  \\IND1P01cb082I04\H$\SQL\I04\BAK1\ExactTarget11\ConfigDB_20170828_212801_a1.bak
    [int] $dryRun = 1
    ## These values should be table driven to try and eliminate typos....
    #  \cmdLine-Standby.ps1 -sourceDB 'ExactTarget7013' -sourceHost 'ATL1P04C012I03\I03' -targetHost 'ATL1P04C001I08\I08' -backupFile '\\UNC\file.BAK'
    #  \cmdLine-Standby.ps1 -sourceDB 'ExactTarget7013' -sourceHost 'ATL1P04C012I03\I03' -targetDB 'ExactTarget7777' -targetHost 'ATL1P04C001I08\I08' -backupFile '\\UNC\file.BAK'

    # .\cmdLine-Standby.ps1 -sourceHost XTINP1CL01D8\I8 -sourceDB ConfigDB -targetHost IND1P01CB082I04\I04
    #  https://sharepoint.stackexchange.com/questions/164216/how-to-correctly-include-file-in-powershell
)

function get-drive ( [string] $f_instance )
{
    $f_instance = $f_instance.replace("I0","I")  #just in case

    switch ($f_instance) 
    { 
       {($_ -LIKE "*\I1")}  {$rootDrive = "E:"} 
       {($_ -LIKE "*\I2")}  {$rootDrive = "F:"} 
       {($_ -LIKE "*\I3")}  {$rootDrive = "G:"} 
       {($_ -LIKE "*\I4")}  {$rootDrive = "H:"} 
       {($_ -LIKE "*\I5")}  {$rootDrive = "J:"} 
       {($_ -LIKE "*\I6")}  {$rootDrive = "K:"} 
       {($_ -LIKE "*\I7")}  {$rootDrive = "L:"}
       {($_ -LIKE "*\I8")}  {$rootDrive = "M:"} 
       {($_ -LIKE "*\I9")}  {$rootDrive = "N:"} 
       {($_ -LIKE "*\I10")} {$rootDrive = "O:"} 
       {($_ -LIKE "*\I11")} {$rootDrive = "P:"} 
       {($_ -LIKE "*\I12")} {$rootDrive = "S:"} 
       {($_ -LIKE "*\I13")} {$rootDrive = "U:"} 
       {($_ -LIKE "*\I14")} {$rootDrive = "V:"} 
       {($_ -LIKE "*\I15")} {$rootDrive = "W:"} 
       {($_ -LIKE "*\I16")} {$rootDrive = "X:"} 
        default {$rootDrive = "BAD INSTANCE"}
    }
    RETURN $rootDrive
}

function copy-Utility ( [string] $f_instance, [string] $f_targetDB )
{
    $instDrive = get-drive $f_instance
    IF( $f_targetDB -like "ExactTarget*" )
        { 
            $targetDrive = "\\"+ $f_instance.substring(0,$f_instance.IndexOf('\')) +"\"+ $instDrive.REPLACE(":","$") +"\StandbyUtil"
        }
    ELSE
        { 
            $targetDrive = "\\"+ $f_instance.substring(0,$f_instance.IndexOf('\')) +"\"+ $instDrive.REPLACE(":","$") +"\StandbyUtil_"+ $f_targetDB
        }

    #WRITE-HOST `t"Copying files: $standbyUTIL to $targetDrive"
    $f_copyCMD = "robocopy $standbyUTIL $targetDrive /MIR /ETA"
    IF($dryRun -eq 1)
        {
            WRITE-HOST `t"[DryRun] $f_copyCMD"
            #WRITE-HOST `t`t"$f_copyCMD"
        }
    ELSE
        {
            WRITE-HOST `t"Copying base files..."
            invoke-expression $f_copyCMD
        }

}

function excute-command( [string] $f_sourceHost, [string] $f_sourceDB, [string] $f_targetHost, [string] $f_targetDB, [string] $f_standbyMGR, [string] $f_backupFile  )
{
    $instDrive = get-drive $f_targetHost
    #Passing in UNC path and file name
    $targetBAKdrive = $f_backupFile
    #$targetBAKdrive = "\\"+ $f_targetHost.substring(0,$f_targetHost.IndexOf('\')) +"\"+ $instDrive.REPLACE(":","$") +"\SQL"
    #$targetBAKdrive = $targetBAKdrive + $f_targetHost.substring($f_targetHost.IndexOf('\'),$f_targetHost.length-($f_targetHost.IndexOf('\'))) +"\BAK1\"+ $f_targetDB +"\"+ $backupFile

    $selectSQL = "SELECT UPPER(REPLACE(@@SERVERNAME ,'\','.XT.LOCAL\') +','+ convert(varchar(10),local_tcp_port)) AS FullInstanceName  FROM sys.dm_exec_connections WHERE session_id = @@spid"
    $sourceFullName = invoke-sqlcmd -ServerInstance $f_sourceHost -Query $selectSQL | select -exp FullinstanceName
    $targetFullName = invoke-sqlcmd -ServerInstance $f_targetHost -Query $selectSQL | select -exp FullinstanceName
    
    IF($f_targetDB -like 'ExactTarget*')
        {
            $execCMD = "`"$instDrive"+"\StandbyUtil\bin\Standby DB Manager.exe`" -sourceinstance $sourceFullName -sourceDatabase $f_sourceDB -targetInstance $targetFullName -targetdatabase $f_targetDB -standbymanager $f_standbyMGR -backupfile $targetBAKdrive -dbprefix $f_targetDB " 
        }
    ELSE
        {
            $execCMD = "`"$instDrive"+"\StandbyUtil_"+ $f_targetDB +"\bin\Standby DB Manager.exe`" -sourceinstance $sourceFullName -sourceDatabase $f_sourceDB -targetInstance $targetFullName -targetdatabase $f_targetDB -standbymanager $f_standbyMGR -backupfile $targetBAKdrive -dbprefix $f_targetDB " 
        }
    
  <#  IF($dryRun -eq 1)
        {
            WRITE-HOST `t"[DryRun] $execCMD"
            #WRITE-HOST `t`t"$execCMD"
        }
    ELSE
        {
            WRITE-HOST `t"Executing command..."

        }#>
    create-poulateJob $f_targetHost $f_targetDB $execCMD
    
    WRITE-HOST "[] Enable LogShip job"
    $enableJob = "EXEC msdb.dbo.sp_update_job @job_Name='LogShip_"+ $f_targetDB +"', @enabled=1"
    IF($dryRun -eq 1)
        {
            WRITE-HOST `t"[DryRun] $enableJob"
            #WRITE-HOST `t`t"$execCMD"
        }
    ELSE
        {
            WRITE-HOST `t"Executing command..."
            invoke-sqlcmd -ServerInstance $f_targetHost -Query $enableJob
        }
}

function create-poulateJob ( [string] $f_targetHost, [string] $f_targetDB, [string] $f_command )
{
    $rootDrive = get-drive $f_targetHost

    IF($f_targetDB -like 'ExactTarget*')
        {
            $ouputFile = $rootDrive +"\StandbyUtil\bin\populateStandbyManager_output.txt"
        }
    ELSE
        {
            $ouputFile = $rootDrive +"\StandbyUtil_"+ $f_targetDB +"\bin\populateStandbyManager_output.txt"
        }
    Write-Host "[] DROP existing job populate Standby Manager job"
    $dropSQL = "IF EXISTS( SELECT * from msdb..sysjobs where NAME = 'PopulateStandbyManager_"+ $f_targetDB +"') BEGIN EXEC msdb.dbo.sp_delete_job @job_name=N'PopulateStandbyManager_"+ $f_targetDB +"', @delete_unused_schedule=1; END "
    IF($dryRun -eq 1)
        {
            WRITE-HOST `t"[DryRun] $dropSQL "
        }
    ELSE
        {
            WRITE-HOST `t"Executing create populate Standby Manager job..."
            invoke-sqlcmd -ServerInstance $f_targetHost -Query $dropSQL
        }

    $createSQL = "
    DECLARE @jobId BINARY(16)
    EXEC msdb.dbo.sp_add_job @job_name=N'PopulateStandbyManager_"+ $f_targetDB +"', 
		    @enabled=0, 
		    @notify_level_eventlog=0, 
		    @notify_level_email=0, 
		    @notify_level_netsend=0, 
		    @notify_level_page=0, 
		    @delete_level=1, 
		    @description=N'No description available.', 
		    @category_name=N'[Uncategorized (Local)]', 
		    @owner_login_name=N'sa', @job_id = @jobId OUTPUT

    /****** Object:  Step [Call standby DB manager.exe]    Script Date: 8/30/2017 4:13:36 PM ******/
    EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Call standby DB manager.exe', 
		    @step_id=1, 
		    @cmdexec_success_code=0, 
		    @on_success_action=1, 
		    @on_success_step_id=0, 
		    @on_fail_action=2, 
		    @on_fail_step_id=0, 
		    @retry_attempts=0, 
		    @retry_interval=0, 
		    @os_run_priority=0, @subsystem=N'CmdExec', 
		    @command= '"+ $f_command +"',
		    @output_file_name='"+ $ouputFile +"', 
		    @flags=0

    EXEC msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1

    EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
    "
    WRITE-HOST "[] Create populate Standby Manager job"
    IF($dryRun -eq 1)
        {
            WRITE-HOST `t"[DryRun] $createSQL "
        }
    ELSE
        {
            WRITE-HOST `t"Executing create populate Standby Manager job..."
            invoke-sqlcmd -ServerInstance $f_targetHost -Query $createSQL
        }

    WRITE-HOST "[] Start populate Standby Manager job"
    $startSQL = "EXEC MSDB..sp_start_job @job_name = 'PopulateStandbyManager_"+ $f_targetDB +"'"
    IF($dryRun -eq 1)
        {
            WRITE-HOST `t"[DryRun] $startSQL "
        }
    ELSE
        {
            WRITE-HOST `t"Executing Start populate Standby Manager job..."
            invoke-sqlcmd -ServerInstance $f_targetHost -Query $startSQL
        }
}
#########################################################################################
#  Set location
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

switch ($sourceHost) 
    {
        {($_ -LIKE "xtinP1*")} {$standbyMGR = 'XTINBSD2.XT.LOCAL\I2,10002';         $standbyUTIL = '\\XTINP1DBA01\d$\Standbys\IN-P1-P2-StandbyMgr\StandbyUtil'; break}
        {($_ -LIKE "IND1P1*")} {$standbyMGR = "XTINBSD2.XT.LOCAL\I2,10002";         $standbyUTIL = '\\XTINP1DBA01\d$\Standbys\IN-P1-P2-StandbyMgr\StandbyUtil'; break}
        {($_ -LIKE "xtinP2*")} {$standbyMGR = 'XTINBSD2.XT.LOCAL\I2,10002';         $standbyUTIL = '\\XTINP1DBA01\d$\Standbys\IN-P1-P2-StandbyMgr\StandbyUtil'; break}
        {($_ -LIKE "IND1P2*")} {$standbyMGR = "XTINBSD2.XT.LOCAL\I2,10002";         $standbyUTIL = '\\XTINP1DBA01\d$\Standbys\IN-P1-P2-StandbyMgr\StandbyUtil'; break}
        {($_ -LIKE "xtnv*")}   {$standbyMGR = 'XTNVP1BSD2.XT.LOCAL\I2,10002';       $standbyUTIL = '\\XTINP1DBA01\d$\Standbys\NV-P3-StandbyMgr\StandbyUtil';    break}
        {($_ -LIKE "las*" )}   {$standbyMGR = 'XTNVP1BSD2.XT.LOCAL\I2,10002';       $standbyUTIL = '\\XTINP1DBA01\d$\Standbys\NV-P3-StandbyMgr\StandbyUtil';    break}
        {($_ -LIKE "xtga*")}   {$standbyMGR = 'XTGAP4DBA01.XT.LOCAL\I1,10001';      $standbyUTIL = '\\XTINP1DBA01\d$\Standbys\GA-P4-StandbyMgr\StandbyUtil';    break}
        {($_ -LIKE "atl*" )}   {$standbyMGR = 'XTGAP4DBA01.XT.LOCAL\I1,10001';      $standbyUTIL = '\\XTINP1DBA01\d$\Standbys\GA-P4-StandbyMgr\StandbyUtil';    break}
        {($_ -LIKE "DFW*" )}   {$standbyMGR = 'DFW1P05DBA01I04.XT.LOCAL\I04,10001'; $standbyUTIL = '\\XTINP1DBA01\d$\Standbys\DFW-P5-StandbyMgr\StandbyUtil';   break}
        default {$standbyMGR = "UNKNOWN"}
    }

#$tempuser = "CT\"+ $env:UserName

WRITE-OUTPUT "[] Started: $((Get-Date).ToString())" 
WRITE-OUTPUT "[] Standby MGR: $standbyMGR"
WRITE-OUTPUT "[] Source DB: $sourceDB"
WRITE-OUTPUT "[] Source Host: $sourceHost"
WRITE-OUTPUT "[] Target DB: $targetDB"
WRITE-OUTPUT "[] Target Host: $targetHost"
WRITE-OUTPUT "[] DryRun: $dryRun "
WRITE-OUTPUT " "

#User-input passwords, store as a credential to pass to SNjr
#$tempPassword = read-host  -AsSecureString "Please enter the new sa password" | convertTo-secureString
#$encrypPassword = convertTo-secureString $tempPassword
#$tempuser = $env:UserName
#$credentials_sa = New-Object System.Management.Automation.PSCredential -ArguementList $tempuser, $encrypPassword
#$credentials_SA.GetNetworkCredential().Password

WRITE-HOST "[] Copy StandbyUTIL"
    #$targetUtil = copy-Utility $targetHost $targetDB $configID
    copy-Utility $targetHost $targetDB
#EXIT
Write-Host "[] Execute StandbyDBmanager.exe - via SQL AGENT job"
    excute-command $sourceHost $sourceDB $targetHost $targetDB $standbyMGR $backupFile
#EXIT

