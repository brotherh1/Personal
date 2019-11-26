  SELECT     CONVERT(decimal(4, 1), percent_complete) AS [%]
            ,estimated_completion_time/1000/60 AS MinLeft
            ,DB_NAME(st.dbid) AS [Database]
            ,CONVERT(varchar(24), r.Start_time, 20) AS StartTime
            ,r.session_id
            ,r.command
            ,r.status
            ,r.wait_type
            ,r.wait_time
            ,r.reads
            ,r.writes 
	    ,r.blocking_session_id
            ,r.logical_reads
            ,r.cpu_time
            ,CONVERT(decimal(9, 1), (r.granted_query_memory/128.0)) AS MBytesRAM
            ,ss.host_name
            ,ss.login_name
            ,CASE ss.transaction_isolation_level
               WHEN 1 THEN 'NOLOCK'
               WHEN 2 THEN 'READCOMMITTED'
               WHEN 3 THEN 'REPEATABLEREAD'
               WHEN 4 THEN 'SERIALIZABLE!'
               WHEN 5 THEN 'SNAPSHOT'
               ELSE 'WTF?'
            END AS LockLevel
            ,ISNULL(OBJECT_NAME(st.objectid, st.dbid), 'Ad hoc') AS ObjectName
            ,SUBSTRING(st.text, (r.statement_start_offset/2)+1, 
            ((CASE r.statement_end_offset
               WHEN -1 THEN DATALENGTH(st.text)
               ELSE r.statement_end_offset
            END - r.statement_start_offset)/2) + 1) AS CurrentStatement
            ,sql_handle
            ,plan_handle
       FROM sys.dm_exec_connections c
       JOIN sys.dm_exec_sessions ss ON c.session_id = ss.session_id
       JOIN sys.dm_exec_requests r ON ss.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st 
      WHERE r.session_id > 45
        AND r.session_id <> @@SPID
        --AND ss.[host_name] LIKE '%RPT%'
        --AND CONVERT(decimal(9, 1), (r.granted_query_memory/128.0)) >5000
   ORDER BY r.start_time
--*******************************************************************************************************
-- Amount of Running/Blocking Sessions

select 'running' as sessionstate,count(*) as noofsessions  from sys.dm_exec_sessions es where es.status = 'running'
UNION
select  'blocking' as sessionstate,count(*) as noofsessions
FROM sys.dm_exec_connections ec 
JOIN sys.dm_exec_requests er ON ec.connection_id = er.connection_id
where er.blocking_session_id>0
order by 1 desc

-- *******************************************************************************************************
-- Lead blocker

if exists ( select blocking_session_id from sys.dm_exec_requests where blocking_session_id>0)
select 'lead blocker' sessiontype,session_id from sys.dm_exec_requests
where session_id IN(select distinct blocking_session_id from sys.dm_exec_requests where blocking_session_id>0) 
and blocking_session_id=0


--*******************************************************************************************************
   -- LOG Manager Information

   SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
--USE [Exacttarget684]
GO
SELECT vfs.database_id,
       df.name,
       df.physical_name,
       vfs.file_id,
       Sum(ior.io_pending) AS PendingIORequests
FROM   sys.dm_io_pending_io_requests ior
       INNER JOIN sys.Dm_io_virtual_file_stats (Db_id(), NULL) vfs
               ON ( vfs.file_handle = ior.io_handle )
       INNER JOIN sys.database_files df
               ON ( df.file_id = vfs.file_id )
WHERE  df.name = 'etlog01'
GROUP  BY vfs.database_id,
          df.name,
          df.physical_name,
          vfs.file_id
          
          
-- LEad Blocker
select loginame, cpu, memusage, physical_io, * 
  from  master..sysprocesses a
 where  exists ( select b.*
    from master..sysprocesses b
    where b.blocked > 0 and
   b.blocked = a.spid ) and not
 exists ( select b.*
     from master..sysprocesses b
    where b.blocked > 0 and
   b.spid = a.spid ) 
order by spid