	--select * from [msdb].[dbo].[backupset]


SELECT
    bs.database_name,bs.media_set_ID,
    bmf.physical_device_name--, *
FROM
    msdb.dbo.backupmediafamily bmf
    JOIN
    msdb.dbo.backupset bs ON bs.media_set_id = bmf.media_set_id
WHERE
    bs.backup_finish_date = (	SELECT --MAX(media_set_ID)--, [BS].[database_name], 
							   MAX([BS].[backup_finish_date]) --AS BackupDate,
							   --DATEDIFF(n, MAX([BS].[backup_finish_date]), GETDATE()) AS MinutesSince --"
						FROM [msdb].[dbo].[backupset] AS BS
						WHERE [BS].[description] like 'FULL %'
							  AND [BS].[database_name] = 'ExactTarget11073'
								GROUP BY [BS].[database_name]
)
GROUP BY [BS].[database_name], bs.media_set_ID,bmf.physical_device_name
--ORDER BY
--    bmf.media_set_id DESC;

select * from msdb.dbo.backupset 
where database_name = 'ExactTarget11074' and first_LSN =< 1945000892720000001 and last_lsn >= 1945000892720000001
--1945000892720000001