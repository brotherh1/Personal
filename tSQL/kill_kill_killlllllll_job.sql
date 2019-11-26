DECLARE @myCounter int, @jobName varchar(max) = 'Copy Matrix Log Files-Cluster 092I06'
DECLARE @myJOBID UNIQUEIDENTIFIER, @subject_text varchar(255),@body_text nvarchar(max),@infractions int,@myQuery varchar(max)
DECLARE @myFinishDate DATETIME,@runStart datetime,@runStop datetime		

--SET @jobName='Websense_IBT_DRIVER__websense_logdb'
SET @myCounter = -1

DECLARE job_cursor CURSOR FOR		
	select TOP(1) Name, activity.run_requested_Date, activity.stop_execution_date
	from msdb.dbo.sysjobs_view job inner join msdb.dbo.sysjobactivity activity on (job.job_id = activity.job_id)
	where run_Requested_date is not null and job.name=@jobName
	ORDER BY run_requested_date desc

OPEN job_cursor  
	FETCH NEXT FROM job_cursor INTO @jobName,@runStart,@runStop  

	WHILE @@FETCH_STATUS = 0  
	BEGIN

		PRINT 'JobName: '+@jobName
		PRINT 'JobStart: '
			PRINT @runStart 
		PRINT 'JobStop: '
			print @runStop
		SET @myCounter=@myCounter+1
		IF(@runStop IS NULL)
			BEGIN
				WHILE ((select activity.stop_execution_date
						from msdb.dbo.sysjobs_view job inner join msdb.dbo.sysjobactivity activity on (job.job_id = activity.job_id)
						where run_Requested_date =@runStart and job.name=@jobName) IS NULL)
					BEGIN
						PRINT 'The job is running!'
						SET @myCounter=@myCounter+1
						PRINT 'Attemtpting kill: '+CONVERT(VARCHAR(10),@myCounter)
						set @myJOBID=(SELECT job_id FROM msdb.dbo.sysjobs WHERE name=@jobName)
							EXEC msdb.dbo.sp_stop_job @job_ID = @myJOBID 
						-- wait for 1 minute
						--WAITFOR DELAY '00:01'

						-- wait for 10 seconds
						WAITFOR DELAY '00:00:10'	
					END
			END
		FETCH NEXT FROM job_cursor INTO @jobName,@runStart,@runStop 
	END
CLOSE job_cursor;
DEALLOCATE job_cursor;


SELECT @@SERVERNAME  -- confirm your connection