USE [Utility];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON
GO
IF NOT EXISTS
(
    SELECT *
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[policy].[logShippingDisabled]')
          AND type IN ( N'P', N'PC' )
)
BEGIN
    EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [policy].[logShippingDisabled] AS';
END;
GO
ALTER procedure [dbo].[DemoPoLP] (@Debug TINYINT = 0)
AS 
BEGIN

    SET ANSI_NULLS ON 
    SET QUOTED_IDENTIFIER ON
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @PVJ AS ParameterValueToJSON, @ProcedureName NVARCHAR(128);  
  
    /*
        Each parameter value should be added below so it is recorded as part of the execution.

        If the parameter is expected to contain sensitive information (Passwords, keys, etc.)
        replace the value with '##Sensitive##' so we do not record these values in the log
    */
    INSERT INTO @PVJ (ParameterName, ParameterValue)  
    VALUES
    --('p1', CAST(@p1 AS nvarchar(max))),
    --('p2', CAST(@p2 AS nvarchar(max))),
    --('p3', CAST('##Sensitive##' AS nvarchar(max))),
    ('Debug', CAST(@Debug AS nvarchar(max)));  

    SELECT @ProcedureName = QUOTENAME(DB_NAME())+'.'+QUOTENAME(OBJECT_SCHEMA_NAME(@@PROCID, DB_ID()))+'.'+QUOTENAME(OBJECT_NAME(@@PROCID, DB_ID()))

    DECLARE @PolpLogID bigint
    EXEC Utility.dbo.PoLPLogIns
    @ProcedureName = @ProcedureName, 
    @ParameterValue = @PVJ,
    @PoLPLogID = @PoLPLogID OUTPUT

    BEGIN TRY  

        /*do the work of the proc*/
		-- DECLARE @Debug TINYINT = 1;
		DECLARE @instanceName varchar(10), @myFile varchar(100), @domainName varchar(100), @File_Exists INT;
		DECLARE @CommentString varchar(4000), @Action tinyint = 0, @Result varchar(500) = '';  
		DECLARE @myTAB varchar(100) = '	', @connectionString  NVARCHAR(MAX) = '', @selectSQL nvarchar(4000);
		DECLARE @InstanceType varchar(100), @powershellCMD varchar(1000), @command varchar(1000),@psCommand varchar(1000);
		DECLARE @IsStandby INT, @IsDisabled INT;

	/* BUILD RETURN OBJECT
		SELECT * FROM #logShipStatus
		SELECT * FROM #logSpace
		SELECT * FROM sys.databases
	*/
		SELECT @selectSQL = 'use [?]; IF( ''?'' NOT IN (''MASTER'',''MODEL'',''MSDB'',''TEMPDB'',''UTILITY'',''WORKTABLEDB''))
			BEGIN
				select ''?'' AS dbName
					, DB_ID()
					, SUM(CASE WHEN [type] = 0 THEN space_used END) as logSizeMB
					, SUM(CASE WHEN [type] = 0 THEN space_free END) as logFreeSpaceMB
					, SUM(CASE WHEN [type] = 1 THEN space_used END) as dataSizeMB
					, SUM(CASE WHEN [type] = 1 THEN space_free END) as DataFreeSpaceMB
				FROM (
					SELECT s.[type], space_used = SUM(FILEPROPERTY(s.name, ''SpaceUsed'') / 128),
									 space_free = (SUM(size)/128) - (sum(CAST(FILEPROPERTY(s.name,''SpaceUsed'') AS DEC))/128)
					FROM sys.database_files AS S
					GROUP BY s.[type]
				) t;
			END;'

		IF( OBJECT_ID('tempdb..#logspace') IS NOT NULL )
			BEGIN
				DROP TABLE #logspace;
			END;

		CREATE TABLE #logspace ( dbName varchar(max), 
								 dbID INT, 
								 logSizeMB varchar(100),
								 logFreeSpaceMB varchar(100),
								 dataSizeMB varchar(100),
								 DataFreeSpaceMB varchar(100)
								);

		INSERT INTO #logspace
			EXECUTE master.sys.sp_MSforeachdb @selectSQL;

		DELETE FROM #logspace WHERE logSizeMB is NULL;

		-- Warning: Null value is eliminated by an aggregate or other SET operation.
				IF( OBJECT_ID('tempdb..#objDatabase') IS NOT NULL )
			BEGIN
				DROP TABLE #objDatabase;
			END;

		CREATE TABLE #objDatabase ( dbName varchar(max), 
								 State varchar(100), 
								 DataSizeMB varchar(100),
								 DataFreeSpaceMB varchar(100),
								 LogSizeMB varchar(100),
								 LogFreeSpaceMB varchar(100),
								 ServerType varchar(100),
								 ReplicationStatus varchar(100)
								);
		INSERT INTO #objDatabase
		SELECT --LEFT(column1, charIndex( ' = ', column1)) AS NAME, 
			name as Name,
			state_desc AS State,
			IsNULL(dataSizeMB,0) AS DataSizeMB,
			IsNULL(dataFreeSpaceMB,0) AS DataFreeSpaceMB,
			IsNULL(logSizeMB,0) AS LogSizeMB,
			IsNULL(logFreeSpaceMB,0) AS LogFreeSpaceMB,
			(SELECT [dbo].[GetConfig]('Instance.ServerType','')) AS ServerType, --@InstanceType AS ServerType,
			IsNULL(RIGHT(column1, LEN(column1) - charIndex( ' = ', column1) -1),'') AS ReplicationStatus 
		FROM sys.databases AS DB 
		 LEFT JOIN #logSpace AS LS ON ( db.Name = LS.dbname )
		 LEFT JOIN #logShipStatus AS LSS ON ( LS.dbname = LEFT(column1, charIndex( ' = ', column1)) )
		WHERE name NOT IN ('MASTER','MODEL','MSDB','TEMPDB','UTILITY','WORKTABLEDB')

		SELECT @instanceName = REPLACE(confValue,'0','') from systemConfig where confKey = 'Instance.instanceName';

		SELECT @myFile = CASE
			WHEN @instanceName like '%I1' THEN 'E:'
			WHEN @instanceName like '%I2' THEN 'F:'
			WHEN @instanceName like '%I3' THEN 'G:'
			WHEN @instanceName like '%I4' THEN 'H:'
			WHEN @instanceName like '%I5' THEN 'J:'
			WHEN @instanceName like '%I6' THEN 'K:'
			WHEN @instanceName like '%I7' THEN 'L:'
			WHEN @instanceName like '%I8' THEN 'M:'
			WHEN @instanceName like '%I9' THEN 'N:'
			WHEN @instanceName like '%I10' THEN 'O:'
			WHEN @instanceName like '%I11' THEN 'P:'
			WHEN @instanceName like '%I12' THEN 'S:'
			WHEN @instanceName like '%I13' THEN 'U:'
			WHEN @instanceName like '%I14' THEN 'V:'
			WHEN @instanceName like '%I15' THEN 'W:'
			WHEN @instanceName like '%I16' THEN 'X:'
		END +'\StandbyUtil\BIN\master-dsn.txt';

		SELECT @selectSQL = 'SELECT @domain = [dbo].[GetConfig](''Instance.domainName'','''')';
		IF( @Debug = 1 )
			BEGIN
				PRINT 'Get local server domain: '
				PRINT @myTAB + @selectSQL;
			END;
		EXECUTE sp_EXECUTESQL @selectSQL, N'@domain nVARCHAR(1000) output', @domainName output;

		SELECT @selectSQL = 'SELECT @ServerType = [dbo].[GetConfig](''Instance.ServerType'','''')';
		IF( @Debug = 1 )
			BEGIN
				PRINT 'Get local server type: '
				PRINT @myTAB + @selectSQL;
			END;
		EXECUTE sp_EXECUTESQL @selectSQL, N'@ServerType nVARCHAR(1000) output', @InstanceType output;
--MORE TESTING VALUES 
--SELECT @InstanceType = 'Restore';
--END TESTING VALUES		
		IF( @instanceType <> 'Restore' )
			BEGIN
				SELECT @isStandby = 0;
				IF( @Debug = 1 )
					BEGIN
						PRINT 'Sever Type: NotRestore ';
						SELECT @instanceType = 'NotRestore';
						PRINT @myTab +'Setting IsStandby = '+ convert(varchar(10),@IsStandby);
					END;
			END;
		ELSE
			BEGIN
				SELECT @isStandby = 1;
				IF( @Debug = 1 )
					BEGIN
						PRINT 'Sever Type: '+ @InstanceType;
						PRINT @myTab +'Setting IsStandby = '+ convert(varchar(10),@IsStandby);
					END;

				EXEC xp_fileexist @myFile, @File_Exists OUT

				SELECT @selectSQL = 'SELECT @FileContent=BulkColumn FROM   OPENROWSET(BULK'''+ @myFile +''',SINGLE_CLOB) x;';
				IF( @Debug = 1 )
					BEGIN
						PRINT 'Get standbyDBmanager connection string from: '+ @myFile;
						PRINT @myTAB + @selectSQL;
					END;
				EXECUTE sp_EXECUTESQL @selectSQL, N'@FileContent nVARCHAR(1000) output', @connectionString output;

				IF( @File_Exists = 0 )
					BEGIN
						PRINT 'FAILED TO LOAD master-dsn.txt - CRASH OUT RETURN 2'
					END;
				ELSE
					BEGIN
						SELECT @powershellCMD = 'powershell.exe -c "Add-PSSnapin SqlServerCmdletSnapin100;invoke-sqlcmd '+ REPLACE(REPLACE(LEFT(@connectionString,CHARINDEX(';Persist', @connectionString)-1) ,'Data Source=','-ServerInstance '''),';Initial Catalog=',''' -Database ') +' -Query ';
						IF( @Debug = 1 )
							BEGIN
								--PRINT 'Target standbyDBmanager : '+ @connectionString;
								PRINT 'Target powershell cmd: ' + @powershellCMD;
							END;

						SELECT @selectSQL = '''SELECT targetDBname +'''' = ''''+ status FROM [StandbyDBManager].[dbo].[StandbyConfig] AS SC LEFT JOIN [StandbyDBManager].[dbo].[TargetInstance] AS TI on (SC.TargetInstanceID = TI.TargetInstanceID ) Where TI.InstanceName like '''''+ confValue+'.'+ @domainName +'%'''' group by targetDBname,status'' '
						FROM systemconfig where confkey = 'Instance.serverName';
--MORE TESTING VALUES 
--SELECT @selectSQL = REPLACE(@selectSQL ,'XTINDBA01','XTINP2CB02D8');
--END TESTING VALUES
						IF( @Debug = 1 )
							BEGIN
								PRINT 'Target powershell SQL: ' +  @selectSQL;
							END;

						SELECT @command = @powershellCMD + @selectSQL;

						IF( OBJECT_ID('tempdb..#logShipStatus') IS NOT NULL )
							BEGIN
								DROP TABLE #logShipStatus;
							END;

						CREATE TABLE #logShipStatus ( column1 varchar(max) );

						INSERT #logShipStatus 
							EXEC xp_cmdshell  @command ;

						UPDATE #logShipStatus SET column1 = rtrim(column1);

				/* update RETURN object */
						UPDATE #objDatabase
							SET ReplicationStatus = RIGHT(column1, LEN(column1) - charIndex( ' = ', column1) -1)
							FROM #objDatabase
							INNER JOIN #logShipStatus
							ON dbName = LEFT(column1, charIndex( ' = ', column1))
			
						IF EXISTS ( SELECT * FROM #logShipStatus WHERE column1 like '% = DISABLED' )
							BEGIN
								IF @Debug = 1
									BEGIN
										PRINT 'Log Shipping Status: DISABLED';

										SELECT @IsDisabled = 1;
									END;
							END;
						ELSE
							BEGIN
								IF( @Debug = 1 )
									BEGIN
										PRINT 'Log Shipping Status: Not Disabled';

										SELECT @IsDisabled = 0;
									END;
							END;
						PRINT @myTAB +'Setting IsDisabled = '+ convert(varchar(10),@IsDisabled);
					END; -- File exists
			END; --IsStandby

		IF( @IsStandby = 0 )
			BEGIN
				PRINT 'Not Standby - should have no log shipping';
				SELECT @Action = 0 ;
			END;
		ELSE IF ( @IsStandby = 1 AND @IsDisabled = 1)
			BEGIN
				PRINT 'Standby and log shipping is disabled.';
				SELECT @ACtion = 0;
			END;
		ELSE IF ( @IsStandby = 1 and @IsDisabled = 0)
			BEGIN
				PRINT 'Standby and log shipping NOT disabled.';
				SELECT @Action = 2;
			END;
		ELSE
			BEGIN
				PRINT 'What happened? '
				SELECT @Action = 1;
			END;
		PRINT @myTAB +'Setting RETURN = '+ convert(varchar(10), @action );

        /*work is complete - return resultset for digestion*/
		SELECT * FROM #objDatabase

        /*Update Complete date in the log*/
        EXEC Utility.dbo.PoLPLogUpd @PoLPLogID = @PoLPLogID

			/* RETURN state */
			RETURN @Action
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
            @PoLPErrorMessage nvarchar(4000);

        /*Assign variables to error-handling functions that 
         capture information for RAISERROR.*/
        SELECT  @ErrorNumber=ERROR_NUMBER(),
                @ErrorSeverity=ERROR_SEVERITY(),
                @ErrorState=ERROR_STATE(),
                @ErrorLine=ERROR_LINE(),
                @ErrorProcedure=ISNULL(ERROR_PROCEDURE(), '-');

        /*Build the message string that will contain original
         error information.*/
        SELECT  @ErrorMessage=N'Error %d, Level %d, State %d, Procedure %s, Line %d, '+'Message: '+ERROR_MESSAGE();
    
        SELECT @PoLPErrorMessage = @ErrorMessage;
        SELECT @PoLPErrorMessage = STUFF(@PoLPErrorMessage, CHARINDEX('%d', @PoLPErrorMessage), 2, @ErrorNumber);
        SELECT @PoLPErrorMessage = STUFF(@PoLPErrorMessage, CHARINDEX('%d', @PoLPErrorMessage), 2, @ErrorSeverity);
        SELECT @PoLPErrorMessage = STUFF(@PoLPErrorMessage, CHARINDEX('%d', @PoLPErrorMessage), 2, @ErrorState);
        SELECT @PoLPErrorMessage = STUFF(@PoLPErrorMessage, CHARINDEX('%s', @PoLPErrorMessage), 2, @ErrorProcedure);
        SELECT @PoLPErrorMessage = STUFF(@PoLPErrorMessage, CHARINDEX('%d', @PoLPErrorMessage), 2, @ErrorLine);

        /*Update the Polp log with complete time and error message*/
        EXEC dbo.PoLPLogUpd @PoLPLogID = @PoLPLogID, @error = @PoLPErrorMessage

        /*Return Resultset for Digestion*/
        SELECT * FROM #objDatabase

        /*Raise an error: msg_str parameter of RAISERROR will contain
         the original error information.*/
        RAISERROR 
            (
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
            RETURN 3
       
    
    END CATCH

/*###############################################################################
Purpose:
	This procedure returns the state of logshipping on a target.
History:
	20180314	hbrotherton		W-4793558	Created
Quip Documentation:
	https://salesforce.quip.com/tpr8AsPt7cij
Comments:

	EXEC policy.logShippingDisabled @debug = 1
	EXEC policy.logShippingDisabled @debug = 0
#################################################################################*/
END;
GO

/*Sign procedure*/
ADD SIGNATURE TO [policy].[logShippingDisabled]
BY  CERTIFICATE [SFMCDBA_PoLPExecution]; 
GO

/*Grant Execute DBA4*/
GRANT EXECUTE ON [policy].[logShippingDisabled] TO DBA4;
GO