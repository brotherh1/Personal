USE snapbackupDB;
select * from logCopyConfig
where copySetID = '1113' AND enabled = 1 --sourceHost like '%C003%' aND enabled = 1

--  SELECT * from logCopyConfig where copysetID = '103'
--  select * from logCopyConfig WHERE sourceHost like '%CL01%' aND enabled = 1
/*
UPDATE logCopyConfig
SET destPath = REPLACE(destPAth, 'H:\TRN','K:\TRN')
WHERE logCopyConfigID = '431' sourceHost like '%CL02%' aND enabled = 1

update logCopyConfig SET enabled = 0 where copysetID = '117'  sourceHost like 'XTINCL07%'  --copysetID = '108'
update logCopyConfig SET enabled = 0 where logCopyConfigID = '103'  

update logCopyConfig
SET copysetID = '107'
where copysetID = '1007' AND sourceHost not like '%P1CL01%' aND enabled = 1

EXEC [dbo].[dropCreateClusterCopyJob] '17'

*/

select * from msdb..sysjobs where job_id not in (
SELECT job_ID from msdb..sysjobsteps 
WHERE step_name = 'Ensure Backup Inventory is up to date')
AND  name like 'copy matrix%' and enabled =1 order by name