
--CREATE procedure info.CopyMatrixLogFiles
--AS
--begin
	SELECT j.Name AS 'Job Name', 
		--'"' + NULLIF(j.Description, 'No description available.') + '"' AS 'Description',
		--SUSER_SNAME(j.owner_sid) AS 'Job Owner',
		--(SELECT COUNT(step_id) FROM dbo.sysjobsteps WHERE job_id = j.job_id) AS 'Number of Steps',
		--(SELECT COUNT(step_id) FROM dbo.sysjobsteps WHERE job_id = j.job_id AND command LIKE '%xp_cmdshell%') AS 'has_xpcmdshell',
		--(SELECT COUNT(step_id) FROM dbo.sysjobsteps WHERE job_id = j.job_id AND command LIKE '%msdb%job%') AS 'has_jobstartstopupdate',
		--(SELECT COUNT(step_id) FROM dbo.sysjobsteps WHERE job_id = j.job_id AND command LIKE '%ftp%') AS 'has_ftp',
		--'Job Enabled' = CASE j.Enabled
		--    WHEN 1 THEN 'Yes'
		--    WHEN 0 THEN 'No'
		--END,
		'Frequency' = CASE s.freq_type
			WHEN 1 THEN 'Once'
			WHEN 4 THEN 'Daily'
			WHEN 8 THEN 'Weekly'
			WHEN 16 THEN 'Monthly'
			WHEN 32 THEN 'Monthly relative'
			WHEN 64 THEN 'When SQLServer Agent starts'
		END, 
		CASE(s.freq_subday_interval)
			WHEN 0 THEN 'Once'
			ELSE cast('Every ' 
					+ right(s.freq_subday_interval,2) 
					+ ' '
					+     CASE(s.freq_subday_type)
								WHEN 1 THEN 'Once'
								WHEN 4 THEN 'Minutes'
								WHEN 8 THEN 'Hours'
							END as char(16))
		END as 'Subday Frequency',
		'Next Start Date'= CONVERT(DATETIME, RTRIM(NULLIF(js.next_run_date, 0)) + ' '
			+ STUFF(STUFF(REPLACE(STR(RTRIM(js.next_run_time),6,0),
			' ','0'),3,0,':'),6,0,':')),
		'Max Duration' = STUFF(STUFF(REPLACE(STR(maxdur.run_duration,7,0),
			' ','0'),4,0,':'),7,0,':'),
		'Last Run Duration' = STUFF(STUFF(REPLACE(STR(lastrun.run_duration,7,0),
			' ','0'),4,0,':'),7,0,':'),
		'Last Start Date' = CONVERT(DATETIME, RTRIM(lastrun.run_date) + ' '
			+ STUFF(STUFF(REPLACE(STR(RTRIM(lastrun.run_time),6,0),
			' ','0'),3,0,':'),6,0,':')) --,'Last Run Message' = lastrun.message
	FROM MSDB.dbo.sysjobs j
	LEFT OUTER JOIN MSDB.dbo.sysjobschedules js
		ON j.job_id = js.job_id
	LEFT OUTER JOIN MSDB.dbo.sysschedules s
		ON js.schedule_id = s.schedule_id 
	LEFT OUTER JOIN (SELECT job_id, max(run_duration) AS run_duration
			FROM MSDB.dbo.sysjobhistory
			GROUP BY job_id) maxdur
	ON j.job_id = maxdur.job_id
	-- INNER JOIN -- Swap Join Types if you don't want to include jobs that have never run
	LEFT OUTER JOIN
		(SELECT j1.job_id, j1.run_duration, j1.run_date, j1.run_time, j1.message
		FROM MSDB.dbo.sysjobhistory j1
		WHERE instance_id = (SELECT MAX(instance_id) 
							 FROM MSDB.dbo.sysjobhistory j2 
							 WHERE j2.job_id = j1.job_id)) lastrun
		ON j.job_id = lastrun.job_id
	WHERE j.name like 'Copy Matrix%' AND j.Enabled = 1
	order by CONVERT(DATETIME, RTRIM(NULLIF(js.next_run_date, 0)) + ' '
			+ STUFF(STUFF(REPLACE(STR(RTRIM(js.next_run_time),6,0),
			' ','0'),3,0,':'),6,0,':'))
--	ORDER BY [Job Name]
--END