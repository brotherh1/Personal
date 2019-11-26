USE [CommServ];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS
(
    SELECT *
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[CommVaultTapeDrivesOfflineAlert]')
          AND type IN ( N'P', N'PC' )
)
BEGIN
    EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CommVaultTapeDrivesOfflineAlert] AS RETURN 0;';
END;
GO
ALTER PROCEDURE [dbo].[CommVaultTapeDrivesOfflineAlert]
(
	@SeverityOneThresholdOfTapeDrivesOffline INT = 7,
	@SeverityTwoThresholdOfTapeDrivesOffline INT = 6,
	@SeverityThreeThresholdOfTapeDrivesOffline INT = 3,
	@SeverityFourThresholdOfTapeDrivesOffline INT = 2,
	@SeverityFiveThresholdOfTapeDrivesOffline INT = 1,
	@dryrun int = 1
)
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
	DECLARE @AlertName VARCHAR(100),
			@AlertDetail VARCHAR(MAX)='',
			@NewLine VARCHAR(2) = CHAR(13) + CHAR(10),
			@libMaxID INT,
			@libCounter INT = 1,
			@tapeMaxID INT,
			@tapeCounter INT = 1,
			@offlinedrivecount INT,
			@Severity INT,
			@DriveStatus VARCHAR(100),
			@DriveAliasName VARCHAR(100),
			@LibAliasName  VARCHAR(100)
	    
	/* Drop code left for manual testing */
	IF OBJECT_ID('tempdb..#TapeDrives') IS NOT NULL
		DROP TABLE #TapeDrives
		 
	CREATE TABLE #TapeDrives
	(
	    ID INT IDENTITY(1, 1) PRIMARY KEY CLUSTERED,
		offlinedrivecount int,
		DriveStatus VARCHAR(100),
		DriveAliasName VARCHAR(100),
		LibAliasName  VARCHAR(100)
	)
	WITH (DATA_COMPRESSION = PAGE);
	   
	INSERT INTO #TapeDrives
	SELECT count(*) over (partition by LibAliasName) AS offlinedrivecount,DriveStatus,DriveAliasName,LibAliasName
	FROM (SELECT Distinct CLSPV.DriveAliasName,CLI.LibAliasName,CLSPV.DriveStatus
	      FROM CommServ.dbo.CommcellLibraryInfo CLI INNER JOIN CommServ.dbo.CommcellDriveInfo CLSPV ON CLI.LibName = CLSPV.LibName 
	      WHERE LibAliasName LIKE '%TLIB%' AND drivestatus <> 'enable') AS offlinedrivecount;
		
    /* Drop code left for manual testing */
	IF OBJECT_ID('tempdb..#distinctlibraries') IS NOT NULL
		DROP TABLE #distinctlibraries
	    
	    
	CREATE TABLE #distinctlibraries
	(
	    ID INT IDENTITY(1, 1) PRIMARY KEY CLUSTERED,
		LibAliasName  VARCHAR(100)
	)
	WITH (DATA_COMPRESSION = PAGE);
	   
	INSERT INTO #distinctlibraries SELECT DISTINCT LibAliasName FROM #TapeDrives	

	/*Get the MaxID*/
	SELECT @libMaxID = Max(ID)
	FROM #distinctlibraries;
	    
	WHILE( @libMaxID >= @libcounter )
	BEGIN
	 
		/* SET Subject for library */
		SELECT @AlertName = LibAliasName+' has offline drives' 
		FROM #distinctLibraries 
		where ID = @libCounter;

		/* Get the MinID */
		SELECT @tapeCounter = Min(ID)
		FROM #TapeDrives
		WHERE LibAliasName =(SELECT LibAliasName FROM #distinctLibraries WHERE ID = @libCounter);

		/*Get the MaxID*/
		SELECT @tapeMaxID = Max(ID)
		FROM #TapeDrives
		WHERE LibAliasName =(SELECT LibAliasName FROM #distinctLibraries WHERE ID = @libCounter);
	    
		/* Setting alert subject and detail header */  
		SELECT @offlinedrivecount = offlinedrivecount,
			    @AlertDetail =  LibAliasName+ ' has '+Cast(@offlinedrivecount AS VARCHAR(20))+' '+'offline drives'+ @NewLine+
							   'Please bring them online. '+@NewLine+'The offline drives are'+ @NewLine	       
		FROM #TapeDrives
		WHERE ID = @tapeCounter;

		/*Get the Severity*/
		SELECT @Severity = CASE
	                        WHEN (@offlinedrivecount >= @SeverityOneThresholdOfTapeDrivesOffline)   THEN 1 
	                        WHEN (@offlinedrivecount >= @SeverityTwoThresholdOfTapeDrivesOffline)   THEN 2
	                        WHEN (@offlinedrivecount >= @SeverityThreeThresholdOfTapeDrivesOffline) THEN 3
	                        WHEN (@offlinedrivecount >= @SeverityFourThresholdOfTapeDrivesOffline)  THEN 4
	                        WHEN (@offlinedrivecount >= @SeverityFiveThresholdOfTapeDrivesOffline)  THEN 5
	                        ELSE -1
	                    END;

		WHILE (@tapeMaxID >= @tapeCounter)
			BEGIN
				/*Get Details*/
				SELECT @AlertDetail =  @AlertDetail+ DriveAliasName +@Newline
				FROM #TapeDrives
				WHERE ID = @tapeCounter;
		
				/*Increment Counter*/
				SELECT @tapeCounter += 1;
			END; --WHILE (@maxid >= @counter) 

		/* Adding runbook to detail */
		SELECT @AlertDetail=@AlertDetail+@Newline+ 'Run Book: https://docs.google.com/document/d/1CK4A8SM2rZ1W6LZ44QHp-m82i3eCu7joPb5eWyEgjbQ/edit#heading=h.lcjb0l293tn7';
	   
		IF (@dryrun =0)
			BEGIN
				/*Resolve or Send Alert*/
				IF (@Severity <> -1)
					BEGIN
						EXEC Utility.dbo.Send_Alert @alertName = @AlertName,
													@detail = @AlertDetail,
													@severity = @Severity,
													@sourceDomain = 'Recoverability';
					END;
				ELSE
					BEGIN
						EXEC Utility.dbo.Send_Alert @alertName = @AlertName,
													@sourceDomain = 'Recoverability',
													@eventType = 'resolve';
						END;
			END;
		ELSE
			BEGIN
				PRINT 'Alert name: '+ @alertname
				PRINT 'Alert detail: '+ @alertdetail
				PRINT 'Alert severity: '+ cast(@severity as varchar(20))
			END; 

		/*Increment Counter*/
		SELECT @libCounter += 1;

	END; --WHILE( @libMaxID >= @libcounter )

END;
/*###############################################################################
Purpose:
	This procedure alerts on tape drives offline on the media libraries.   
History:
		20190703 abarai		W-6161813	Created
		20190708 abarai     W-6161813   Updated tabs and consistent use of capitalization.

		yyyymmdd user  work item  details
Comments:
	
#################################################################################*/


	