USE [Utility];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS
(
    SELECT *
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[policy].[DatabaseAcceptingConnections]')
          AND type IN ( N'P', N'PC' )
)
BEGIN
    EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [policy].[DatabaseAcceptingConnections] AS';
END;
GO
ALTER PROCEDURE [policy].[DatabaseAcceptingConnections] (@Debug TINYINT = 0)
AS
BEGIN
    SET ANSI_NULLS ON;
    SET QUOTED_IDENTIFIER ON;
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @PVJ AS ParameterValueToJSON,
            @ProcedureName NVARCHAR(128),
            @SQLVersion NVARCHAR(128),
            @SQLCmd NVARCHAR(MAX),
            @ServerType NVARCHAR(50),
            /*Set the defualt to 0: OK state*/
            @DatabaseStatus TINYINT = 0;

    INSERT INTO @PVJ
    (
        ParameterName,
        ParameterValue
    )
    VALUES
    ('Debug', CAST(@Debug AS NVARCHAR(MAX)));

    SELECT @ProcedureName
        = QUOTENAME(DB_NAME()) + '.' + QUOTENAME(OBJECT_SCHEMA_NAME(@@PROCID, DB_ID())) + '.'
          + QUOTENAME(OBJECT_NAME(@@PROCID, DB_ID()));

    DECLARE @PolpLogID BIGINT;
    EXEC Utility.dbo.PoLPLogIns @ProcedureName = @ProcedureName,
                                @ParameterValue = @PVJ,
                                @PoLPLogID = @PolpLogID OUTPUT;

    BEGIN TRY
        /*Get the SQL Version*/
        SELECT @SQLVersion = CONVERT(NVARCHAR, SERVERPROPERTY('ProductVersion'));

        /*Get the Server Type*/
        SELECT @ServerType = Utility.dbo.GetConfig('Instance.ServerType', '');

        /*Get the correct T-SQL select statement to run based on SQL Version*/
        IF (@SQLVersion >= '11.0')
        BEGIN
            SELECT @SQLCmd
                = 'SELECT db.[name],
       CONVERT(NVARCHAR, DATABASEPROPERTYEX(db.[name], ''Status'')),
       CASE COALESCE(DATABASEPROPERTYEX(db.[name], ''Collation''), ''CollationIsNULL'')
           WHEN ''CollationIsNULL'' THEN
               ''CANNOT Accept Connections''
           ELSE
               ''CAN Accept Connections''
       END,
       ag.synchronization_state_desc
FROM sys.databases AS db
    LEFT JOIN sys.dm_hadr_database_replica_states AS ag
        ON db.database_id = ag.database_id;';
        END;
        ELSE
        BEGIN
            SELECT @SQLCmd
                = 'SELECT [name],
       CONVERT(NVARCHAR, DATABASEPROPERTYEX([name], ''Status'')),
       CASE COALESCE(DATABASEPROPERTYEX([name], ''Collation''), ''CollationIsNULL'')
           WHEN ''CollationIsNULL'' THEN
               ''CANNOT Accept Connections''
           ELSE
               ''CAN Accept Connections''
       END,
	   NULL
FROM sys.databases';
        END;

        /*Print Version and Command to be executed*/
        IF (@Debug > 0)
        BEGIN
            PRINT 'SQL Version: ' + @SQLVersion + CHAR(10);
            PRINT 'Command to be ran: ' + @SQLCmd + CHAR(10);
        END;

        /*Create a temp table to store the final results to present to user*/
        CREATE TABLE #FinalResults
        (
            [ID] INT IDENTITY(1, 1) PRIMARY KEY CLUSTERED,
            [DatabaseName] sysname,
            [DatabaseState] NVARCHAR(50),
            [AcceptingUserConnection] NVARCHAR(75),
            [SynchronizationState] NVARCHAR(75)
        )
        WITH (DATA_COMPRESSION = PAGE);

        /*Create temp table containing database name, state, accepting connection, synchronization state*/
        CREATE TABLE #DatabaseStatuses
        (
            [ID] INT IDENTITY(1, 1) PRIMARY KEY CLUSTERED,
            [DatabaseName] sysname,
            [DatabaseState] NVARCHAR(50),
            [AcceptingUserConnection] NVARCHAR(75),
            [SynchronizationState] NVARCHAR(75)
        )
        WITH (DATA_COMPRESSION = PAGE);
        INSERT INTO #DatabaseStatuses
        EXEC (@SQLCmd);

        /*Check ServerType if it Build, Down, or Unused.  If so, return State Value: OK State*/
        IF (
               @ServerType <> 'Build'
               AND @ServerType <> 'Down'
               AND @ServerType <> 'Unused'
           )
        BEGIN
            /*Check if any databases not ONLINE or CANNOT Accept Connections*/
            --IF EXISTS
            --(
            --    SELECT 1
            --    FROM #DatabaseStatuses
            --    WHERE [DatabaseState] <> 'ONLINE'
            --          OR [AcceptingUserConnection] <> 'CAN Accept Connections'
            --)
            --BEGIN
                /*Set Value to 2: Critical State*/
                SELECT @DatabaseStatus = 2;

                /*Insert record(s) into FinalResults temp table*/
                IF (@ServerType <> 'Restore')
                BEGIN
                    INSERT INTO #FinalResults
                    SELECT [DatabaseName],
                           [DatabaseState],
                           [AcceptingUserConnection],
                           [SynchronizationState]
                    FROM #DatabaseStatuses
                    --WHERE DatabaseState <> 'ONLINE'
                    --      OR [AcceptingUserConnection] <> 'CAN Accept Connections';

                    IF (@Debug > 0)
                    BEGIN
                        PRINT 'Record inserted into the Final Results Table.  This is not a Standby SQL instance';
                    END;
                END;

                IF (@Debug > 0)
                BEGIN
                    PRINT 'One or more database(s) is RESTORING, RECOVERING, RECOVERY_PENDING, SUSPECT, EMERGENCY, OFFLINE or CANNOT Accept Connections';
                END;

                /*Check if the SQL instance is a Standby, RESTORING and ONLINE State acceptable*/
                IF (@ServerType = 'Restore')
                BEGIN
                    /*Reset State Value: OK State*/
                    SELECT @DatabaseStatus = 0;

                    IF (@Debug > 0)
                    BEGIN
                        PRINT 'This is a Standby SQL Instance, RESTORING and ONLINE states are accepteable';
                    END;

                    /*Check if any databases are not ONLINE, RESTORING, or Cannot Accept Connections*/
                    --IF EXISTS
                    --(
                    --    SELECT 1
                    --    FROM #DatabaseStatuses
                    --    WHERE [DatabaseState] <> 'RESTORING'
                    --          AND [DatabaseState] <> 'ONLINE'
                    --          OR [AcceptingUserConnection] <> 'CAN Accept Connections'
                    --)
                    --BEGIN
                        /*Set Value to 2: Critical State*/
                        SELECT @DatabaseStatus = 2;

                        /*Insert record(s) into FinalResults temp table*/
                        INSERT INTO #FinalResults
                        SELECT [DatabaseName],
                               [DatabaseState],
                               [AcceptingUserConnection],
                               [SynchronizationState]
                        FROM #DatabaseStatuses
                        --WHERE [DatabaseState] <> 'RESTORING'
                        --      AND [DatabaseState] <> 'ONLINE'
                        --      OR [AcceptingUserConnection] <> 'CAN Accept Connections';

                        IF (@Debug > 0)
                        BEGIN
                            PRINT 'Record inserted into the Final Results Table.  This is a Standby SQL instance';
                            PRINT 'There is still one or more database(s) that is RECOVERING, RECOVERY_PENDING, SUSPECT, EMERGENCY, OFFLINE or CANNOT Accept Connections';
                        END;
                    --END;
                    --ELSE
                    --BEGIN
                    --    IF (@Debug > 0)
                    --    BEGIN
                    --        PRINT 'All Database are in an OK state for the StandbySQL Instance. Return an OK state';
                    --    END;
                    --END;
                END;
            --END;
            --ELSE
            --BEGIN
            --    IF (@Debug > 0)
            --    BEGIN
            --        PRINT 'All Database are in an OK state. Return an OK state';
            --    END;
            --END;
        END;
        ELSE
        BEGIN
            /*Return State Value: OK State.  SQL instance is either a new build, down, or unused*/
            IF (@Debug > 0)
            BEGIN
                PRINT 'SQL Instance is either a new Build, Down, or Unused.  Return an OK state.';
            END;
        END;

        /*Present result set if the state is not OK*/
        --IF (@DatabaseStatus > 0)
        --BEGIN
            SELECT *  FROM #FinalResults;
        --END;
        /*Print state value if in debug mode*/
        IF (@Debug > 0)
        BEGIN
            PRINT 'The state value to be returned is: ' + CAST(@DatabaseStatus AS VARCHAR(3));
        END;

        /*Update Complete date in the log*/
        EXEC Utility.dbo.PoLPLogUpd @PoLPLogID = @PolpLogID;

        /*Return the state value*/
        RETURN @DatabaseStatus;

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
        SELECT @Debug AS DebugValue;

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
	This procedure does a check to validate if there are currently any databases
	that are not in a state of ONLINE, and a state of ONLINE or RESTORING for
	Standby SQL instances. It also verifies that each database can accept connections
	It will return a state of 0 if no databases are in a state of RECOVERING,
	RECOVERY_PENDING, SUSPECT, EMERGENCY, or OFFLINE for the SQL instance and can
	accept connections.
History:
	20180312	jpopejoy		W-4747372	Created
Comments:

	EXEC [policy].[DatabaseStatus] @debug = 1
#################################################################################*/
GO

--/*Sign procedure*/
--ADD SIGNATURE TO [policy].[DatabaseStatus]
--BY  CERTIFICATE [SFMCDBA_PoLPExecution];
--GO

--/*Grant Excute rights*/
--GRANT EXECUTE ON [policy].[DatabaseStatus] TO DBA4;
--GO