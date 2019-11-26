USE [CommServ]
GO
/****** Object:  StoredProcedure [dbo].[CommVaultJobAlert]    Script Date: 8/13/2019 3:59:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--ALTER PROCEDURE [dbo].[CommVaultJobAlert] ( @sourceDomain VARCHAR(20) = 'Recoverability', @className VARCHAR(20)= 'CommVault', @sendGOC INT = 3, @dryRun INT = 1 )--> SEV3 > 12 hours - SEV2 >24 hours  SEV1 >48 hours
--AS
--BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DECLARE @dryRun INT = 1 -- Default to not send GOC++
	DECLARE @sendGOC int = 3 -- threshold to sent GOC++
	DECLARE @sourceDomain VARCHAR(20) = 'Recoverability'
	DECLARE @className VARCHAR(20)= 'CommVault'

    DECLARE @MaxID INT,
            @Counter INT = 1,
            @AlertName VARCHAR(100),
            @AlertDetail VARCHAR(MAX),
            @JobId INT,
            @NewLine VARCHAR(2) = CHAR(13) + CHAR(10),
            @StoragePolicy VARCHAR(500),
            @MediaAgentName VARCHAR(500),
            @SubclientName VARCHAR(250),
            @ErrorCode VARCHAR(100),
            @DelayReason VARCHAR(MAX),
            @Status VARCHAR(50),
			@DelayDuration VARCHAR(100),
			@severity int = 5, -- Default to lowest Severity
			@SEV1 INT = 48, --hours
			@SEV2 INT = 24,
			@SEV3 INT = 12,
			@SEV4 INT,
			@SEV5 INT;

	IF OBJECT_ID('tempdb..#RunningBackups') IS NOT NULL
		DROP TABLE #RunningBackups

    CREATE TABLE #RunningBackups
    (
        ID INT IDENTITY(1, 1) PRIMARY KEY CLUSTERED,
        JobID INT,
        StoragePolicy VARCHAR(500),
        MediaAgentName VARCHAR(250),
        SubclientName VARCHAR(250),
        ErrorCode VARCHAR(100),
        DelayReason VARCHAR(MAX),
        [Status] VARCHAR(50),
		JobElapsedTime DEC(20,2),
		Severity INT
    )
    WITH (DATA_COMPRESSION = PAGE);

    INSERT INTO #RunningBackups
    SELECT RB.JobID,
           RB.CurrentPolicyName,
           RB.ShortMediaAgent,
           RB.SubClientName,
           CAST(ELM.SubsystemID AS VARCHAR(20)) + ':' + CAST(ELM.MessageNum AS VARCHAR(20)) AS ErrorCode,
           RB.DelayReason,
           CASE
               WHEN RB.State = 0 THEN
                   'Not Avaliable'
               WHEN RB.State = 1 THEN
                   'Running'
               WHEN RB.State = 2 THEN
                   'Pending'
               WHEN RB.State = 3 THEN
                   'Waiting'
               WHEN RB.State = 4 THEN
                   'Completed'
               WHEN RB.State = 5 THEN
                   'Suspended'
               WHEN RB.State = 6 THEN
                   'Kill Pending'
               WHEN RB.State = 7 THEN
                   'Suspended Pending'
               WHEN RB.State = 8 THEN
                   'Interrupt Pending'
               WHEN RB.State = 9 THEN
                   'Completed'
               WHEN RB.State = 10 THEN
                   'Failed'
               WHEN RB.State = 11 THEN
                   'Killed'
               WHEN RB.State = 12 THEN
                   'Completed w/ one or more errors'
               WHEN RB.State = 13 THEN
                   'System Kill Pending'
               WHEN RB.State = 14 THEN
                   'Suspended'
               WHEN RB.State = 15 THEN
                   'Queued'
               WHEN RB.State = 16 THEN
                   'Queued'
               ELSE
                   'Unknown'
           END AS [Status],
		   CAST(RB.jobElapsedTime /3600.00 as DECIMAL(20,2)), -- hours conversion
		   CASE
				WHEN CAST(RB.jobElapsedTime /3600.00 as DECIMAL(20,2)) > @SEV1 THEN '1'
				WHEN CAST(RB.jobElapsedTime /3600.00 as DECIMAL(20,2)) > @SEV2 THEN '2'
				WHEN CAST(RB.jobElapsedTime /3600.00 as DECIMAL(20,2)) > @SEV3 THEN '3'
				WHEN CAST(RB.jobElapsedTime /3600.00 as DECIMAL(20,2)) > @SEV4 THEN '4'
				WHEN CAST(RB.jobElapsedTime /3600.00 as DECIMAL(20,2)) > @SEV5 THEN '5'
				ELSE 6 -- And check previously recorded jobs
			END as Severity
    FROM dbo.RunningBackups AS RB
        INNER JOIN dbo.JMFailureReasonLocaleMsgCache JF
            ON RB.JobID = JF.Jobid
               AND RB.failureReason = JF.reasonCode
        INNER JOIN --dbo.JMFailureReasonMsg JFM
        (
            SELECT JobID,
                   MessageID,
                   ROW_NUMBER() OVER (PARTITION BY JobID ORDER BY id DESC) [rank]
            FROM JMFailureReasonMSG
        ) JFM
            ON JF.Jobid = JFM.JobID
               AND JFM.[rank] = 1
        --AND RB.currentPhase = JFM.phaseNumber
        INNER JOIN EvLocaleMsgs ELM
            ON JF.localeID = ELM.localeID
               AND JFM.MessageID = ELM.MessageID
    WHERE RB.State IN ( 2, 3, 5, 6, 7, 8, 10, 11, 13, 14, 15, 16 );

    /*Remove Alerts we do not care about*/
    DELETE FROM #RunningBackups
    WHERE ErrorCode IN ( '19:2124' );

	/* ADD Alerts we need to clear */
	/* INSERT SELECT * alerts.CommVaultJobStatus WHERE NOT IN #runninBackups SET Severity = 6 */
		-- SELECT * from alerts.CommVaultJobStatus WHERE SubClientName = @SubclientName AND storagePolicy = @StoragePolicy

    /*Get Max ID*/
    SELECT @MaxID = MAX(ID)
    FROM #RunningBackups;

    /*Alert on Jobs in the states we care about*/
    WHILE (@MaxID >= @Counter)
    BEGIN

        /*Get Info*/
        SELECT @JobId = JobID,
               @StoragePolicy = StoragePolicy,
               @MediaAgentName = MediaAgentName,
               @SubclientName = SubclientName,
               @ErrorCode = ErrorCode,
               @DelayReason = DelayReason,
               @Status = [Status],
			   @DelayDuration = JobElapsedTime,
			   @Severity = severity
        FROM #RunningBackups
        WHERE ID = @Counter;

		IF( @Severity > @sendGOC ) 
			BEGIN
				SELECT @AlertName = @SubclientName + ':' + @StoragePolicy,
					@AlertDetail
						=	'Check for previousSeverity and clear GOC if necessary'	+ @NewLine +
						'Otherwise skip - Severity is less than Send to GOC++ threshold '+ convert(CHAR(10), @sendGOC )
			END
		ELSE
			BEGIN
			   SELECT @AlertName = @SubclientName + ':' + @StoragePolicy,
					   @AlertDetail
						   = 'Job Status: ' + @Status + @NewLine + 'Error Duration: ' + @DelayDuration + @NewLine + 'Error Code: ' + @ErrorCode + @NewLine
							 + 'Media Agent Name: ' + @MediaAgentName + @NewLine + 'Storage Policy: ' + @StoragePolicy
							 + @NewLine + 'Subclient: ' + @SubclientName + @NewLine + 'Reason: ' + @DelayReason + @NewLine
							 + @NewLine + 'Runbook: Link Here: https://sfdc.co/CommVaultJobTroubleshooting';
			END;

		IF( @dryRun = 0 )
			BEGIN
				EXEC Utility.dbo.Send_Alert @alertName = @AlertName,
											@detail = @AlertDetail,
											@severity = @Severity,
											@className = @className,
											@sourceDomain = @sourceDomain;
			END
		ELSE
			BEGIN
				PRINT ' '
				PRINT 'Alert Name: '+ @AlertName
				PRINT 'Alert Detail: '
				PRINT @alertDetail
				PRINT 'Severity: '+ convert(char(2), @severity)
				PRINT 'className: '+ @className
				PRINT 'sourceDomain: '+ @sourceDomain
			END;

        SELECT @Counter += 1;
    END;
--END;

/*###############################################################################
Purpose:
	Alerts on various states of Commvault jobs
History:
	20190509	jpopejoy		W-6090452	Created
Comments:
#################################################################################*/
