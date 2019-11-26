-- https://sqlsunday.com/2013/08/11/shrinking-tempdb-without-restarting-sql-server/
-- use TEMPDB; CHECKPOINT
-- DBCC FREEPROCCACHE
SELECT session_id as SPID, command, aa.text AS Query, start_time,percent_complete, 
dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time, getdate()
FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) aa 
WHERE  r.command in('BACKUP LOG','BACKUP DATABASE','RESTORE DATABASE')
-- Select @@servername
EXEC ('dbcc sqlperf(logspace)');
/*  ET746 increase BAK1 and Bak2 to 4TB ?

USE [tempdb]
GO
DBCC SHRINKFILE (N'TempDB_log_01' , 0, TRUNCATEONLY)
GO
*/
-- Find open transactions that are sleeping
select * from sys.sysprocesses where [status] = 'sleeping' and open_tran <> 0
-- Use standard job to shrink
EXEC msdb..sp_start_job @job_name = 'dbMaint Backup - Daily Main (Full or Diff)'
EXEC msdb..sp_start_job @job_name = 'dbMaint Backup - Database Logs'
--  EXEC msdb.dbo.sp_help_job @Job_name = 'dbMaintLogManagement'
EXEC msdb..sp_start_job @job_name = 'dbMaintLogManagement'

/*

kill 4403
kill 1547
kill 2810
kill 3972

*/