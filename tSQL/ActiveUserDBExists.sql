USE [Utility];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS
(
    SELECT *
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[policy].[ActiveUserDBExists]')
          AND type IN ( N'P', N'PC' )
)
BEGIN
    EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [policy].[ActiveUserDBExists] AS';
END;
GO

ALTER PROCEDURE [policy].[ActiveUserDBExists] (@Debug TINYINT = 0, @SuppressDetail TINYINT = 0)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @PVJ AS ParameterValueToJSON,
            @ProcedureName NVARCHAR(128),
            /*Set the defualt to 0: OK state*/
            @ActiveUserDBExists TINYINT = 0;

    INSERT INTO @PVJ
    (
        ParameterName,
        ParameterValue
    )
    VALUES
    ('Debug', CAST(@Debug AS NVARCHAR(MAX))),
    ('SuppressDetail', CAST(@SuppressDetail AS nvarchar(max)));

    SELECT @ProcedureName
        = QUOTENAME(DB_NAME()) + '.' + QUOTENAME(OBJECT_SCHEMA_NAME(@@PROCID, DB_ID())) + '.'
          + QUOTENAME(OBJECT_NAME(@@PROCID, DB_ID()));

    DECLARE @PolpLogID BIGINT;
    EXEC Utility.dbo.PoLPLogIns @ProcedureName = @ProcedureName,
                                @ParameterValue = @PVJ,
                                @PoLPLogID = @PolpLogID OUTPUT;
    BEGIN TRY
		
		-- DO WE CARE ABOUT THE STATE THAT THE DATABASE IS IN OTHER THAN ONLINE(0) ( RESTORING, RECOVERING, RECOVERY_PENDING,  SUSPECT, EMERGENCY, OFFLINE). 

		SELECT @ActiveUserDBExists=CASE WHEN COUNT(*) > 0  THEN 1 ELSE 0 END 
		FROM 
			SYS.DATABASES 
		WHERE 
			NAME NOT IN ('MASTER','MODEL','MSDB','TEMPDB','WORKTABLEDB','UTILITY') AND
			STATE=0;

		IF(@ActiveUserDBExists =1 AND @DEBUG=1)
		BEGIN
			PRINT 'One or more user DB exists other than  WorkTableDB/Utility';
		END;

		IF(@ActiveUserDBExists =0 AND @DEBUG=1)
		BEGIN
			PRINT 'No user DB exists other than  WorkTableDB/Utility';
		END;

  
    /*work is complete - return resultset for digestion*/
    IF @SuppressDetail = 0
      BEGIN
        EXEC Utility.INFO.Database
      END
    ELSE
      BEGIN
          IF( @debug = 1 )
            BEGIN
                PRINT 'Detail has been suppressed as desired.';
            END;
      END;

    /*Update Complete date in the log*/
    EXEC Utility.dbo.PoLPLogUpd @PoLPLogID = @PoLPLogID;

    /*RETURN STATE*/

		RETURN @ActiveUserDBExists;

    END TRY
    BEGIN CATCH
        /*If anything is open - we need to rollback*/
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000),
                @ErrorNumber INT,
                @ErrorSeverity INT,
                @ErrorState INT,
                @ErrorLine INT,
                @ErrorProcedure NVARCHAR(200),
                @PoLPErrorMessage NVARCHAR(4000);

        /*Assign variables to error-handling functions that
         capture information for RAISERROR.*/
        SELECT @ErrorNumber = ERROR_NUMBER(),
               @ErrorSeverity = ERROR_SEVERITY(),
               @ErrorState = ERROR_STATE(),
               @ErrorLine = ERROR_LINE(),
               @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-');

        /*Build the message string that will contain original
         error information.*/
        SELECT @ErrorMessage = N'Error %d, Level %d, State %d, Procedure %s, Line %d, ' + 'Message: ' + ERROR_MESSAGE();

        SELECT @PoLPErrorMessage = @ErrorMessage;
        SELECT @PoLPErrorMessage = STUFF(@PoLPErrorMessage, CHARINDEX('%d', @PoLPErrorMessage), 2, @ErrorNumber);
        SELECT @PoLPErrorMessage = STUFF(@PoLPErrorMessage, CHARINDEX('%d', @PoLPErrorMessage), 2, @ErrorSeverity);
        SELECT @PoLPErrorMessage = STUFF(@PoLPErrorMessage, CHARINDEX('%d', @PoLPErrorMessage), 2, @ErrorState);
        SELECT @PoLPErrorMessage = STUFF(@PoLPErrorMessage, CHARINDEX('%s', @PoLPErrorMessage), 2, @ErrorProcedure);
        SELECT @PoLPErrorMessage = STUFF(@PoLPErrorMessage, CHARINDEX('%d', @PoLPErrorMessage), 2, @ErrorLine);

        /*Return Resultset for Digestion*/

        EXEC Utility.INFO.Database

        /*Update the Polp log with complete time and error message*/
        EXEC dbo.PoLPLogUpd @PoLPLogID = @PolpLogID, @Error = @PoLPErrorMessage;

        /*Raise an error: msg_str parameter of RAISERROR will contain
         the original error information.*/
        RAISERROR(
                     @ErrorMessage,
                     @ErrorSeverity,
                     1,
                     @ErrorNumber,
                     @ErrorSeverity,
                     @ErrorState,
                     @ErrorProcedure,
                     @ErrorLine
                 );

        /*a return of 3 designates an UNKNOWN if the severity does not stop execution*/
        RETURN 3;

    END CATCH;
END;

/*###############################################################################
Purpose:
	This procedure returns if there are any user databases other than worktabledb/utility.
	This is part of baselining guard rails to check if any database exists before you restart an instance
History:
	20180312	mrajagopal		W-5094277	Created
Comments:
#################################################################################*/
GO

/*Sign procedure*/
ADD SIGNATURE TO [policy].[ActiveUserDBExists]
BY  CERTIFICATE [SFMCDBA_PoLPExecution];
GO

/*Grant Excute rights*/
GRANT EXECUTE ON [policy].[ActiveUserDBExists] TO DBA4;
GO

