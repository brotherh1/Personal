

PARAM(

    [string] $targetHost = '',
    [string] $targetINV ='XTINP1DBA01\DBAdmin'

    # . .\dbops_workingfolders\dbops\Harold\powerShell\san_migration.ps1
)

$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

function checkStatus-sanity ( [string] $f_currentUser = "" )
{
    WRITE-HOST " "
    IF( $f_currentUser -eq "") { $f_currentUser = $env:UserName }
    $sanityLevel = get-random -maximum 4
    WRITE-HOST "[] Checking Sanity Level "
    
    switch ($sanityLevel) 
        { 
        {($_ -eq 0)}  { WRITE-HOST `t"[ALERT] Sanity Level for $f_currentUser is severly low: $sanityLevel" }
        {($_ -eq 1)}  { WRITE-HOST `t"[WARNING] Sanity Level for $f_currentUser is questionable: $sanityLevel"  }
        {($_ -eq 2)}  { WRITE-HOST `t"[WARNING] Sanity Level for $f_currentUser is questionable: $sanityLevel"  }
        {($_ -eq 3)}  { WRITE-HOST `t"[OK] Sanity Level for $f_currentUser is perfect: $sanityLevel"  }
 
        default {WRITE-HOST "BAD Parameter:  checkStatus-Cluster clusterName command"; WRITE-HOST `t"Available commands: "; WRITE-HOST `t`t"backup, deprecation, readiness, service, instance, latency"; return}
    }
    WRITE-HOST " "
}

function checkStatus-Ping ( [string] $f_targetHost )
{
    $f_targetServer = $f_targetHost.substring(0,$f_targetHost.IndexOf('\')) +".XT.LOCAL"
    #$f_targetInstance = $f_targetHost.substring($f_targetHost.IndexOf('\')+1,$f_targetHost.length-($f_targetHost.IndexOf('\')+1))
    test-Connection -ComputerName $f_targetHost.substring(0,$f_targetHost.IndexOf('\')) -Count 2 -Quiet  
     
}

function checkStatus-instance ( [string] $f_targetHost )
{
    if ( checkStatus-Ping $f_targetHost ) 
        {
            $f_selectSQL ="select name,state_desc as DBState, DATABASEPROPERTYEX(name,'status') as DBStatus,
                    case DATABASEPROPERTYEX(name,'collation')
                    when NULL then 'CAN NOT Accept Connections'
                       else 'CAN Accept Connections' End as RecoveryStauts
                    from sys.databases"

            invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL  | format-table -AutoSize
         }
    ELSE
        {  
            WRITE-HOST `t"$f_targetHost is not Pinging - check SQL network name."
        }
}

function checkStatus-service ( [string] $f_targetHost )
{
    $f_targetServer = $f_targetHost.substring(0,$f_targetHost.IndexOf('\')) +".XT.LOCAL"
    $f_targetInstance = $f_targetHost.substring($f_targetHost.IndexOf('\')+1,$f_targetHost.length-($f_targetHost.IndexOf('\')+1))
    if ( checkStatus-Ping $f_targetHost ) 
        {   
            #get-service -computername $f_targetServer | select  name, status | where { ($_.name -like "SQLAGENT$"+ $f_targetInstance -or $_.name -like "MSSQL$"+ $f_targetInstance -or $_.name -like "MSSQLFDLauncher$"+ $f_targetInstance )  } | format-table -AutoSize  
            get-service -computername $f_targetServer | select  name, status | where { ($_.name -like "SQLAGENT$"+ $f_targetInstance -or $_.name -like "MSSQL$"+ $f_targetInstance -or $_.name -like "MSSQLFDLauncher$"+ $f_targetInstance  -or $_.name -like "MSDTC-"+ $f_targetInstance )  } | format-table -AutoSize
        }
    ELSE
        {  
            WRITE-HOST `t"$f_targetHost is not Pinging - check SQL network name."
        }
}

function checkStatus-MSDTC ( [string] $f_targetHost )
{
    if ( checkStatus-Ping $f_targetHost ) 
        {
            WRITE-HOST "[] Sending Query to MSDTC:"
            $f_selectSQL = "BEGIN DISTRIBUTED TRANSACTION; select @@version; COMMIT TRANSACTION;"
            $f_useless = @( invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL )

            WRITE-HOST "[] Checking $f_targetHost ERRORlog for '(MS DTC) has completed'"
            $f_selectSQL = "EXEC sys.xp_readerrorlog 0, 1, `"(MS DTC) has completed`" "
            IF( !(invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL )  )
                {
                    WRITE-HOST "[WARNING] Nothing found - assume MSDTC is still down. "
                    WRITE-HOST " "
                }
            ELSE
                {
                    invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL | SELECT logDate, text | format-table -AutoSize
                }
        }
    ELSE
        {  
            WRITE-HOST `t"$f_targetHost is not Pinging - check SQL network name."
        }
}

function checkStatus-Latency ( [string] $f_targetHost, [int] $f_count = 0 )
{
    $f_selectSQL = "EXEC sys.xp_readerrorlog 0, 1, `"I/O requests taking longer`" "
    IF( !(invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL )  )
        {
            WRITE-HOST `t"Nothing found - think things are good? "
            WRITE-HOST " "
        }
    ELSE
        {
            IF($f_count -eq 0)
                {
                    WRITE-HOST "$f_targetHost - Checking ERRORlog for 'I/O requests taking longer'"
                    invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL | SELECT logDate, text | format-table -AutoSize
                }
            ELSE
                {
                    $infractionCount = invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL | Measure-Object logDate -min -max
                    #$infractionCount
                    WRITE-HOST `t"Infraction Count: " $infractionCount.Count 
                    WRITE-HOST `t"Start Time: " $infractionCount.minimum
                    WRITE-HOST `t"END Time:   " $infractionCount.maximum
                }
        }
}

function checkStatus-Standby ( [string] $f_targetHost )
{
    switch ($f_targetHost) 
    {
        {($_ -LIKE "xtinP1*")}  {$standbyMGR = 'XTINBSD2\I2'        ; break}
        {($_ -LIKE "IND1P01*" )} {$standbyMGR = "XTINBSD2\I2"        ; break}
        {($_ -LIKE "xtinP2*")}  {$standbyMGR = 'XTINBSD2\I2'        ; break}
        {($_ -LIKE "IND1P02*" )} {$standbyMGR = "XTINBSD2\I2"        ; break}
        {($_ -LIKE "xtnv*")}    {$standbyMGR = 'XTNVP1BSD2\I2'      ; break}
        {($_ -LIKE "las*" )}    {$standbyMGR = 'XTNVP1BSD2\I2'      ; break}
        {($_ -LIKE "xtga*")}    {$standbyMGR = 'XTGAP4DBA01\I1'     ; break}
        {($_ -LIKE "atl*" )}    {$standbyMGR = 'XTGAP4DBA01\I1'     ; break}
        {($_ -LIKE "DFW*" )}    {$standbyMGR = 'DFW1P05DBA01I04\I04'; break}
        default {$standbyMGR = "UNKNOWN"}
    }

    $f_targetServer = $f_targetHost.substring(0,$f_targetHost.IndexOf('\'))
    $f_selectSQL = "
        SELECT sc.* FROM TargetInstance ti LEFT JOIN StandbyConfig sc
        ON ti.TargetInstanceID = sc.TargetInstanceID
        WHERE ti.TargetInstanceID IN (SELECT TargetInstanceID FROM TargetInstance WHERE InstanceName LIKE '"+ $f_targetServer +"%')"
    IF( !(invoke-sqlcmd -ServerInstance $standbyMGR -Database standbyDBmanager -Query $f_selectSQL) )
        {
            WRITE-HOST `t"This instance is not defined as a standby..."
            WRITE-HOST " "
        }
    ELSE
        {
            invoke-sqlcmd -ServerInstance $standbyMGR -Database standbyDBmanager -Query $f_selectSQL | select StandbyConfigID, SourceDBName, TargetDBName, Status, LastMessage | format-table -AutoSize
        }
    #invoke-sqlcmd -ServerInstance $standbyMGR -Database standbyDBmanager -Query $f_selectSQL | format-table -AutoSize

}

function checkStatus-Readiness ( [string] $f_targetHost )
{
    $f_selectSQL = "exec utility.dbo.dbarpts_checkfailoverreadiness"
    invoke-sqlcmd -ServerInstance $f_targetHost -Database MASTER -Query $f_selectSQL | format-table -AutoSize
<#  $results = invoke-sqlcmd -ServerInstance $f_targetHost -Database MASTER -Query $f_selectSQL #| format-table -AutoSize
    #$results | format-table -AutoSize
    write-host " "
    write-host "STATUS","MESSAGE"
    write-host "------","-------"
    forEach ($item in $results)
    {
        IF($item.status )
        {
            write-host  $item.status.padRight(9-$item.status.Length), $item.message -foregroundcolor $item.status | format-table -AutoSize
        }
    }
    write-host " "  #>
}

function checkStatus-Backup ( [string] $f_targetHost )
{
       #Load script from Praveen
    $f_selectSQL = "
    select @@servername,'if (@@servername = '+ char(39)+@@servername+CHAR(39)+') EXEC msdb.dbo.sp_update_schedule @schedule_id='+cast(schedule_id as varchar(100))+', @active_start_time=3500,@freq_subday_type=8, 		@freq_subday_interval=1;',




* from 

(SELECT   [JobName] = [jobs].[name]
		 ,[schedule].schedule_id
		 ,[schedule].schedule_uid
		 ,[schedule].name as Job_scheduled_Name
		,[Category] = [categories].[name]
		,[Owner] = SUSER_SNAME([jobs].[owner_sid])
		,[Enabled] = CASE [jobs].[enabled] WHEN 1 THEN 'Yes' ELSE 'No' END
		,[Scheduled] = CASE [schedule].[enabled] WHEN 1 THEN 'Yes' ELSE 'No' END
		,[Description] = [jobs].[description]
		,[Occurs] = 
				CASE [schedule].[freq_type]
					WHEN   1 THEN 'Once'
					WHEN   4 THEN 'Daily'
					WHEN   8 THEN 'Weekly'
					WHEN  16 THEN 'Monthly'
					WHEN  32 THEN 'Monthly relative'
					WHEN  64 THEN 'When SQL Server Agent starts'
					WHEN 128 THEN 'Start whenever the CPU(s) become idle' 
					ELSE ''
				END
		,[Occurs_detail] = 
				CASE [schedule].[freq_type]
					WHEN   1 THEN 'O'
					WHEN   4 THEN 'Every ' + CONVERT(VARCHAR, [schedule].[freq_interval]) + ' day(s)'
					WHEN   8 THEN 'Every ' + CONVERT(VARCHAR, [schedule].[freq_recurrence_factor]) + ' weeks(s) on ' + 
							 LEFT
							 (
								CASE WHEN [schedule].[freq_interval] &  1 =  1 THEN 'Sunday, '    ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] &  2 =  2 THEN 'Monday, '    ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] &  4 =  4 THEN 'Tuesday, '   ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] &  8 =  8 THEN 'Wednesday, ' ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] & 16 = 16 THEN 'Thursday, '  ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] & 32 = 32 THEN 'Friday, '    ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] & 64 = 64 THEN 'Saturday, '  ELSE '' END , 
								LEN
								(
									CASE WHEN [schedule].[freq_interval] &  1 =  1 THEN 'Sunday, '    ELSE '' END + 
									CASE WHEN [schedule].[freq_interval] &  2 =  2 THEN 'Monday, '    ELSE '' END + 
									CASE WHEN [schedule].[freq_interval] &  4 =  4 THEN 'Tuesday, '   ELSE '' END + 
									CASE WHEN [schedule].[freq_interval] &  8 =  8 THEN 'Wednesday, ' ELSE '' END + 
									CASE WHEN [schedule].[freq_interval] & 16 = 16 THEN 'Thursday, '  ELSE '' END + 
									CASE WHEN [schedule].[freq_interval] & 32 = 32 THEN 'Friday, '    ELSE '' END + 
									CASE WHEN [schedule].[freq_interval] & 64 = 64 THEN 'Saturday, '  ELSE '' END 
								) - 1
							 )
					WHEN  16 THEN 'Day ' + CONVERT(VARCHAR, [schedule].[freq_interval]) + ' of every ' + CONVERT(VARCHAR, [schedule].[freq_recurrence_factor]) + ' month(s)'
					WHEN  32 THEN 'The ' + 
							 CASE [schedule].[freq_relative_interval]
								WHEN  1 THEN 'First'
								WHEN  2 THEN 'Second'
								WHEN  4 THEN 'Third'
								WHEN  8 THEN 'Fourth'
								WHEN 16 THEN 'Last' 
							 END +
							 CASE [schedule].[freq_interval]
								WHEN  1 THEN ' Sunday'
								WHEN  2 THEN ' Monday'
								WHEN  3 THEN ' Tuesday'
								WHEN  4 THEN ' Wednesday'
								WHEN  5 THEN ' Thursday'
								WHEN  6 THEN ' Friday'
								WHEN  7 THEN ' Saturday'
								WHEN  8 THEN ' Day'
								WHEN  9 THEN ' Weekday'
								WHEN 10 THEN ' Weekend Day' 
							 END + ' of every ' + CONVERT(VARCHAR, [schedule].[freq_recurrence_factor]) + ' month(s)' 
					ELSE ''
				END
		,[Frequency] = 
				CASE [schedule].[freq_subday_type]
					WHEN 1 THEN 'Occurs once at ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':')
					WHEN 2 THEN 'Occurs every ' + 
								CONVERT(VARCHAR, [schedule].[freq_subday_interval]) + ' Seconds(s) between ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':') + ' and ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_end_time]), 6), 5, 0, ':'), 3, 0, ':')
					WHEN 4 THEN 'Occurs every ' + 
								CONVERT(VARCHAR, [schedule].[freq_subday_interval]) + ' Minute(s) between ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':') + ' and ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_end_time]), 6), 5, 0, ':'), 3, 0, ':')
					WHEN 8 THEN 'Occurs every ' + 
								CONVERT(VARCHAR, [schedule].[freq_subday_interval]) + ' Hour(s) between ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':') + ' and ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_end_time]), 6), 5, 0, ':'), 3, 0, ':')
					ELSE ''
				END
		,[AvgDurationInSec] = CONVERT(DECIMAL(10, 2), [jobhistory].[AvgDuration])
		,[Next_Run_Date] = 
				CASE [jobschedule].[next_run_date]
					WHEN 0 THEN CONVERT(DATETIME, '1900/1/1')
					ELSE CONVERT(DATETIME, CONVERT(CHAR(8), [jobschedule].[next_run_date], 112) + ' ' + 
						 STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [jobschedule].[next_run_time]), 6), 5, 0, ':'), 3, 0, ':'))
				END
FROM	 [msdb].[dbo].[sysjobs] AS [jobs] WITh(NOLOCK) 
		 LEFT OUTER JOIN [msdb].[dbo].[sysjobschedules] AS [jobschedule] WITh(NOLOCK) 
				 ON [jobs].[job_id] = [jobschedule].[job_id] 
		 LEFT OUTER JOIN [msdb].[dbo].[sysschedules] AS [schedule] WITh(NOLOCK) 
				 ON [jobschedule].[schedule_id] = [schedule].[schedule_id] 
		 INNER JOIN [msdb].[dbo].[syscategories] [categories] WITh(NOLOCK) 
				 ON [jobs].[category_id] = [categories].[category_id] 
		 LEFT OUTER JOIN 
		 (	
				 SELECT	  [job_id], [AvgDuration] = (SUM((([run_duration] / 10000 * 3600) + (([run_duration] % 10000) / 100 * 60) + ([run_duration] % 10000) % 100)) * 1.0) / COUNT([job_id])
				 FROM	  [msdb].[dbo].[sysjobhistory] WITh(NOLOCK)
				 WHERE	  [step_id] = 0 
				 GROUP BY [job_id]
		  ) AS [jobhistory] 
				 ON [jobhistory].[job_id] = [jobs].[job_id]
) as Job
where jobname in ('dbMaint Backup - Daily Main (Full or Diff)','dbMaint Backup - Database Logs')

--and Frequency like '%30 M%'
"
    #$f_backupInfo = @( invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL )
    ##forEach($backupJob in $f_backupInfo)
    #{
    #    WRITE-HOST $backupJob.jobName $backupJob.enabled $backupJob
   # }
   invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL | select jobName, enabled, scheduled, next_run_date, AvgDurationInSec | format-table -autosize
}

function checkStatus-Recovery ( [string] $f_targetHost, [string] $f_targetDB = "" )
{
    IF($f_targetDB -eq "" )
       {
            $f_selectSQL = "EXEC sys.xp_readerrorlog 0, 1, `"Recovery of database `" "
       }
    ELSE
        {
            $f_selectSQL = "EXEC sys.xp_readerrorlog 0, 1, `"Recovery of database '"+ $f_targetDB +"`" "
        }
    IF( !(invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL )  )
        {
            WRITE-HOST "[] Checking $f_targetHost - $f_selectSQL "
            WRITE-HOST `t"Nothing found - Are you expecting something to be broken?  Check instance....."
            WRITE-HOST " "
        }
    ELSE
        {
            invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL | SELECT logDate, text | format-table -AutoSize
        }
}

function checkStatus-ErrorLog ( [string] $f_targetHost, [string] $f_targetString = "" )
{
    IF( $f_targetString -eq "" )
        {
            IF( (invoke-sqlcmd -ServerInstance $f_targetHost -Query "EXEC sys.xp_readerrorlog 0, 1, `"The error log has been reinitialized. `" ")  )
                {
                    WRITE-HOST "[] Error Log indicates log rollver - no restart "
                    invoke-sqlcmd -ServerInstance $f_targetHost -Query "EXEC sys.xp_readerrorlog 0, 1, `"The error log has been reinitialized. `" " | SELECT logDate, text | format-table -AutoSize
                }
            ELSEIF( (invoke-sqlcmd -ServerInstance $f_targetHost -Query "EXEC sys.xp_readerrorlog 0, 1, `"Server restarted, running on `"  ")  )
                {
                    WRITE-HOST "[] Error Log indicates restart  " 
                    invoke-sqlcmd -ServerInstance $f_targetHost -Query "EXEC sys.xp_readerrorlog 0, 1, `"Server restarted, running on `"  " | SELECT logDate, text | format-table -AutoSize
                }
            ELSE
                {
                    WRITE-HOST `t"Nothing found - Are you expecting something to be broken?  Check instance....."
                    WRITE-HOST " "
                }
        }
    ELSE
        {
            WRITE-HOST "[] Displaying entire log  " 
            invoke-sqlcmd -ServerInstance $f_targetHost -Query "EXEC sys.xp_readerrorlog 0, 1 " | SELECT logDate, text | format-table -AutoSize
        }
}

function checkStatus-Deprecation ( [string] $f_targetHost, [int] $f_count = 0 )
{
    $f_selectSQL = "select name, enabled from msdb..sysjobs where (name like 'Deprecation%' or name like 'DEDeprecation%') "
    IF( !(invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL )  )
        {
            WRITE-HOST `t"[WARNING] No Jobs found.  Could be empty instance.  Is there an ET database?"
            WRITE-HOST " "
        }
    ELSE
        {
            If($f_count -eq 0 )
                {
                    #$f_selectSQL = "select name, enabled from msdb..sysjobs where (name like 'Deprecation%' or name like 'DEDeprecation%') "
                    invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL | format-table -AutoSize
                }
            ELSE
                {
                    $f_selectSQL = "select COALESCE(COUNT(name),0) as JobCount, COALESCE(enabled,0) as Enabled from msdb..sysjobs where (name like 'Deprecation%' or name like 'DEDeprecation%') group by enabled "
                    invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL | format-table -AutoSize
                }
        }
}

function checkStatus-transaction ( [string] $f_targetHost )
{
    WRITE-HOST "Instance Level - Transactions in Flight summary "
    $f_selectSQL = " -- InstanceLevel 
select * from 
(    select count(*) #Sessions, sum((database_transaction_log_bytes_used + database_transaction_log_bytes_reserved +  
         database_transaction_log_bytes_used_system + database_transaction_log_bytes_reserved_system))/1048576.0 'ActiveLogSizeMB',  sum(database_transaction_log_record_count) '#ActiveLogs' 
          ,datediff(ss, min(t.database_transaction_begin_time), getdate()) TransactionAgeSec  ,
          -- (this is not based on session start time. This is based on Transaction Start time)
          datediff(ss, min(s.login_time), getdate()) SessionAgeSec,
          datediff(ss,min(last_request_start_time), getdate()) LastRequestAgeSec
           from  sys.dm_tran_session_transactions st
           left join   sys.dm_tran_database_transactions t 
           on t.transaction_id = st.transaction_id 
           left join sys.dm_exec_sessions s
           on st.session_id = s.session_id
) as t
where #Sessions > 1
-- and ActiveLogSizeMB > 1024 (-- 1 GB)
-- SessionLevel"
    $f_targetFile = "\\XTINP1DBA01\d`$\Harold\SAN_Migration\"+ $f_targetHost +"_Transaction.txt"
    invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL | format-table -AutoSize

    write-host "Inflight Transaction Active Log size needs to be less than 1MB to be safe for shutdown."
    write-host " "
    write-host "Session Level - Transactions in Flight details"
    $f_selectSQL = " 
select st.session_id, sum((database_transaction_log_bytes_used + database_transaction_log_bytes_reserved +  
         database_transaction_log_bytes_used_system + database_transaction_log_bytes_reserved_system))/1048576.0 'ActiveLogSizeMB',  sum(database_transaction_log_record_count) '#ActiveLogs' 
          ,datediff(ss, min(t.database_transaction_begin_time), getdate()) TransactionAgeSec  ,
          -- (this is not based on session start time. This is based on Transaction Start time)
          datediff(ss, min(s.login_time), getdate()) SessionAgeSec,
          datediff(ss,min(last_request_start_time), getdate()) LastRequestAgeSec
           from  sys.dm_tran_session_transactions st
           left join   sys.dm_tran_database_transactions t 
           on t.transaction_id = st.transaction_id 
           left join sys.dm_exec_sessions s
           on st.session_id = s.session_id
           group by st.session_id

-- etc

-- In my Testing 1GB of recovery took more than 3 minutes)
-- 8GB is the suggested cap for killing a process ~30 minutes of rollback."

    invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL  | format-table -AutoSize

}

function checkStatus-Availability ( [string] $f_targetHost )
{

    $f_selectSQL = "SELECT distinct
        ar.replica_server_name, 
        ag.name AS ag_name, 
        is_distributed,
        drs.is_local, 
        drs.is_primary_replica, 
        drs.synchronization_state_desc, 
        drs.is_commit_participant, 
        drs.synchronization_health_desc
        ,db_name(database_id) as DatabaseName
    FROM sys.dm_hadr_database_replica_states AS drs
    left JOIN sys.availability_databases_cluster AS adc 
        ON drs.group_id = adc.group_id AND 
        drs.group_database_id = adc.group_database_id
    left JOIN sys.availability_groups AS ag
        ON ag.group_id = drs.group_id
    left JOIN sys.availability_replicas AS ar 
        ON drs.group_id = ar.group_id AND 
        drs.replica_id = ar.replica_id
 
    union all

    select distinct
    rep.replica_server_name,ag.name,is_distributed,is_local,case when primary_replica=replica_server_name then 1 else 0 end as is_primary_replica,
    synchronization_state_desc, is_commit_participant,repstate.synchronization_health_desc,DB_name(database_id) as DatabaseName
    from sys.availability_replicas rep
    cross apply sys.fn_hadr_distributed_ag_replica(group_id,replica_id) dag
    join sys.availability_groups ag on rep.group_id=ag.group_id
    join sys.dm_hadr_availability_group_states agstate on ag.group_id=agstate.group_id
    join sys.dm_hadr_database_replica_states repstate on repstate.group_id=dag.group_id
    "

    invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL  | format-table -AutoSize

    WRITE-HOST "Make certain SYNCHRONIZATION_STATE_DESC = SYNCHRONIZED and SYNCHRONIZATION_HEALTH_DESC=HEALTHY"

 }

function checkStatus-Cluster ( [string] $f_targetHost, [string] $f_command )
{
    WRITE-HOST "[] Inventory Server: $targetINV"
    $f_selectSQL = "SELECT [SQLInstallation] FROM [DBA].[dbo].[ExactTargetSQLInstallations] where servergroupname = 'Cluster "+ $f_targetHost +"' order by ipAddress"    
    WRITE-HOST `t $f_selectSQL
    WRITE-HOST " "
    $instanceList = @( invoke-sqlcmd -ServerInstance $targetINV -Query $f_selectSQL | select -exp sqlinstallation )
    IF(!$instanceList)
        { 
            WRITE-HOST "[ALERT] No Instance returned for Cluster: $f_targetHost "
        }
    ELSE
        {
            ForEach( $instance in $instanceList )
            {

                if (checkStatus-Ping $instance ) 
                { 
                    $f_selectSQL = "SELECT [Utility].[dbo].[GetConfig] ('instance.description','') as description"
                    $f_instanceDESC = invoke-sqlcmd -ServerInstance $instance -Query $f_selectSQL | select -exp  description

                    WRITE-HOST "$instance - $f_instanceDESC " 

                    switch ($f_command) 
                     { 
                       {($_ -LIKE "deprecation")}  { checkStatus-deprecation $instance 1 }
                       {($_ -LIKE "readiness")}    { checkStatus-readiness $instance }
                       {($_ -LIKE "service")}      { checkStatus-service $instance }
                       {($_ -LIKE "instance")}     { checkStatus-instance $instance }
                       {($_ -LIKE "latency")}      { checkStatus-Latency $instance 1 }
                       {($_ -LIKE "backup")}       { checkStatus-backup $instance }
                       {($_ -LIKE "Standby")}      { checkStatus-Standby $instance }
                       {($_ -LIKE "SanUsage")}     { checkStatus-SanUsage $instance }

                       default {WRITE-HOST "BAD Parameter:  checkStatus-Cluster clusterName command"; WRITE-HOST `t"Available commands: "; WRITE-HOST `t`t"backup, deprecation, readiness, service, instance, latency"; return}
                    }
                }
                ELSE
                {
                    WRITE-HOST "$instance - Instance not online"
                    WRITE-HOST " "
                }

            } #end forEach
        }
}

function checkStatus-SanUsage ( [string] $f_targetHost )
{
    $spaceSQL = "--Real clean...(USE THIS ONE)
SELECT
	Utility.dbo.GetConfig('Instance.serverGroup','') as ClusterName,
	Utility.dbo.GetConfig('Instance.description','') as DBName,
    CAST(SUM(CASE WHEN type = 0 THEN MF.size * 8 / 1024.0  ELSE 0 END) AS FLOAT) +
    CAST(SUM(CASE WHEN type = 1 THEN MF.size * 8 / 1024.0  ELSE 0 END) AS FLOAT) as DBSize
	
FROM
    sys.master_files MF
    JOIN sys.databases DB ON DB.database_id = MF.database_id
WHERE db.name like 'ExactTarget%'
GROUP BY DB.name"

    invoke-sqlcmd -ServerInstance $f_targetHost -Query $spaceSQL |  format-table -autosize

}

<#  CONTINUE TO USE MAINTENANCE DIRECTOR  #>
."$ScriptDirectory\setStatus-Cluster_PS.ps1"

Function getMigration-Command ( [string] $f_helptopic)
{
    WRITE-HOST "Available Commands:"
    WRITE-HOST `t"Pre-take down Commands:"
    WRITE-HOST `t`t"checkStatus-Transaction server\inst  #View status of inflight transactions"
    WRITE-HOST `t`t"checkStatus-Deprecation server\inst  #View status of deprecation jobs"
    WRITE-HOST `t`t"checkStatus-Readiness server\inst    #View status of the failover readiness"
    WRITE-HOST " "
    WRITE-HOST `t`t"checkStatis-Standby server\inst      #view status of log shipping jobs - targetserver is the standby"
    WRITE-HOST `t"After restart Commands:"
    WRITE-HOST `t`t"checkStatus-Service server\inst      #View status of SQL services"
    WRITE-HOST `t`t"checkStatus-Instance server\inst     #view status of databases"
    WRITE-HOST `t`t"checkStatus-MSDTC server\inst        #View recovery state of MSDTC"
    WRITE-HOST `t`t"checkStatus-Latency server\inst      #View state of IOPs in ERRORLOG"
    WRITE-HOST " "
    WRITE-HOST `t`t"checkStatus-Availability server\inst #view status of availability groups where required"
    WRITe-HOST `t`t"checkStatus-recovery server\inst     #view the recovery state of a member database"
    WRITE-HOST `t"Run Commands against all CLUSTER instances:"
    WRITe-HOST `t`t"checkStatus-Cluster clusterName readiness  "  
    WRITe-HOST `t`t"checkStatus-Cluster clusterName Deprecation"
    WRITe-HOST `t`t"checkStatus-Cluster clusterName Service"
    WRITe-HOST `t`t"checkStatus-Cluster clusterName Instance"
    WRITe-HOST `t`t"checkStatus-Cluster clusterName Latency"
    WRITE-HOST `t`t"checkStatus-cluster clusterName standby #The cluster should be the standby cluster"
    
    
    

    WRITE-Host " "
    WRITE-HOST "Quip Document: https://salesforce.quip.com/4S3gAv3K1m5i "
    WRITE-HOST " "
}

CLS
getMigration-Command

<#
TAKE FIRST INSTANCE RESOURCES DOWN using maintenance director
    Turn Audit OFF for the first instance you're working on. 
    Turn DEORECATION jobs OFF for first instance you're woring on 

CONFIRM READY TO TAKE DOWN
    checkStatus-Service XTINP1CL06D6\I6
    checkStatus-Deprecation XTINP1CL06D6\I6
    checkStatus-readiness XTINP1CL06D6\I6
    checkStatus-transaction XTINP1CL06D6\I6

SET CLUSTER RESOURCES DOWN using maintenance director
    turn off remaining AUDITS and deprecation jobs

CONFIRM
    checkStatus-Cluster XTINP2CL12 Audit
    checkStatus-Cluster XTINP2CL12 Deprecation

INSTANCE IS BACK ONLINE 
    checkStatus-service XTINP2CL12D1\I1
    checkStatus-instance  XTINP2CL12D1\I1
    checkStatus-MSDTC XTINP1CL06D6\I6

IF DB IN RECOVERY
    checkStatus-recovery XTINP2CL12D1\I1
    checkStatus-Recovery XTINP2CL12D1\I1 ExactTarget22

IF DB USES AVAILABILTY GROUPS
    checkStatus-Availability XTINP2CL12D1\I1

AFTER MIGRATION IS COMPLETED
    Turn audits and deprecation jobs back on using maintenance director

Can verify using....
    checkStatus-Cluster XTINP2CL12 readiness 
    checkStatus-Cluster XTINP2CL12 Deprecation 

#>


# Can we loop insatnce level commands until the come back favorably ?

