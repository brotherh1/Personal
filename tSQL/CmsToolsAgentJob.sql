
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

SET NOCOUNT ON ;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

DECLARE @DBID INT,
	@ScheduleId BIGINT,
	@ScheduleDate DATETIME,
	@StatusMessage VARCHAR(MAX) = '',
	@IsRevert BIT = 0,
	@MidInclusionList VARCHAR(MAX) = '',
	@MidExclusionList VARCHAR(MAX) = '',
	@SuccessfulMids VARCHAR(MAX) = '',
	@FailedMids VARCHAR(MAX) = '',
	@Status_ReadyToProcess TINYINT = 1,
	@Status_InProgress TINYINT = 2,
	@Status_Complete TINYINT = 3,
	@Status_Error TINYINT = 99

-- Find the current dbid
SELECT @DBID = [DBID] FROM ConfigDB.dbo.DBServers WHERE DatabaseName = DB_NAME();

--Note that the default StatusId=0 means 'Draft' and won't be picked up
SELECT TOP 1 @ScheduleId = ScheduleId, @ScheduleDate = ScheduleDate, @IsRevert = IsRevert, @MidInclusionList = MidInclusionList, @MidExclusionList = MidExclusionList
	FROM SystemDBServer.SystemDB.dbo.CmsToolsSchedule
	WHERE DatabaseID = @DBID AND StatusId = @Status_ReadyToProcess AND ScheduleDate < GETDATE()
	ORDER BY ScheduleDate ASC;
	
WHILE (ISNULL(@ScheduleId,0) > 0)
BEGIN
	BEGIN TRY
		UPDATE SystemDBServer.SystemDB.dbo.CmsToolsSchedule 
		SET StatusId = @Status_InProgress, StatusMessage = 'In Progress', ModifiedDate = GETDATE()
		WHERE ScheduleId = @ScheduleId;
		
		IF (@IsRevert = 0)
		BEGIN
			exec Cms_EnableNewTools @ScheduleId, @MidInclusionList, @MidExclusionList, @SuccessfulMids output, @FailedMids output;
			SET @StatusMessage = 'Complete [ Success: ' + @SuccessfulMids + '] [ Failed: ' + @FailedMids + ']';
			
			UPDATE SystemDBServer.SystemDB.dbo.CmsToolsSchedule 
			SET StatusId = @Status_Complete, StatusMessage = @StatusMessage, ModifiedDate = GETDATE()
			WHERE ScheduleId = @ScheduleId;
		END
		ELSE
		BEGIN
			exec Cms_RevertNewTools @ScheduleId, @SuccessfulMids output, @FailedMids output;
			SET @StatusMessage = 'Reverted [ Success: ' + @SuccessfulMids + '] [ Failed: ' + @FailedMids + ']';
			
			UPDATE SystemDBServer.SystemDB.dbo.CmsToolsSchedule 
			SET StatusId = @Status_Complete, StatusMessage = @StatusMessage, ModifiedDate = GETDATE(), RevertDate = GETDATE()
			WHERE ScheduleId = @ScheduleId;	
		END
	END TRY
	BEGIN CATCH
		UPDATE SystemDBServer.SystemDB.dbo.CmsToolsSchedule 
		SET StatusId = @Status_Error, StatusMessage = 'Error - ' + ISNULL ( ERROR_MESSAGE(), '' ), ModifiedDate = GETDATE()
		WHERE ScheduleId = @ScheduleId;
	END CATCH
	
	--PRINT 'Schedule ' + CAST(@ScheduleId AS varchar(10)) + ' - ' + @StatusMessage + '. ';
	SELECT @ScheduleId = NULL, @StatusMessage = '', @SuccessfulMids = '', @FailedMids = '';
	
	SELECT TOP 1 @ScheduleId = ScheduleId, @ScheduleDate = ScheduleDate, @IsRevert = IsRevert, @MidInclusionList = MidInclusionList, @MidExclusionList = MidExclusionList
	FROM SystemDBServer.SystemDB.dbo.CmsToolsSchedule
	WHERE DatabaseID = @DBID AND StatusId = @Status_ReadyToProcess AND ScheduleDate < GETDATE()
	ORDER BY ScheduleDate ASC;
END
GO

/*######################################################################################################
$$Author:	Scott McDaniel
$$Database: ExactTarget
$$Purpose: 	SQL AGENT JOB
			Monitor the SystemDB table CmsToolsSchedule for newly planned upgrades to CMS
$$Revisions:
$$ 2016-04-08	SMcDaniel	EMAILFLOW-2566 : Created
######################################################################################################*/
