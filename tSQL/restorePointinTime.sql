-- select @@servername

-- DFW1P05C058I03\I03

-- RESTORE LOG <database_name> FROM <backup_device> WITH NORECOVERY;  
DECLARE @targetDB varchar(100) = 'ExactTarget12'
DECLARE @StopTime datetime = 'May 23, 2019 3:35 PM' -- Servers are in Central target is 2:25PM EST
DECLARE @StartTime datetime = '5/21/2019 1:00 AM'

SELECT 
	bs.database_name AS DatabaseName
	,CASE bs.type
		WHEN 'D' THEN 'Full'
		WHEN 'I' THEN 'Differential'
		WHEN 'L' THEN 'Transaction Log'
	END AS BackupType
	,bs.backup_start_date AS BackupStartDate
	,CAST(bs.first_lsn AS VARCHAR(50)) AS FirstLSN
	,CAST(bs.last_lsn AS VARCHAR(50)) AS LastLSN
	,bmf.physical_device_name AS PhysicalDeviceName
	, 'RESTORE LOG '+  @targetDB +' FROM '''+ bmf.physical_device_name +''' WITH NORECOVERY,  STOPAT = '''+ convert(varchar(100), @StopTime) +''';' as RestoreStatement
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS bmf
	ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name =  @targetDB and first_lsn < 818751000057064800001 --and last_LSN > 818751000057064800001 
--and bs.backup_start_date > @StartTime --and bs.backup_start_date < @stopTime
--	and ( bmf.physical_device_name like '%bak1%' OR bmf.physical_device_name like '%bak00%' )
ORDER BY 
	backup_start_date ASC	,backup_finish_date

	-- WITH STOPAT = time, RECOVERY...