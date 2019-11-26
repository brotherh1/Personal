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
    WHERE object_id = OBJECT_ID(N'[action].[enableLogShipping]')
          AND type IN ( N'P', N'PC' )
)
BEGIN
    EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [action].[enableLogShipping] AS';
END;
GO
ALTER procedure [action].[enableLogShipping] (@force TINYINT = 0, @whatIF TINYINT = 0, @Debug TINYINT = 0)
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
    ('p1', CAST(@force AS nvarchar(max))),
    ('p2', CAST(@whatIF AS nvarchar(max))),
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
		DECLARE @CommentString varchar(4000), @Action tinyint = 45, @Result varchar(500) = '',@updateSQL nvarchar(1000);  
		DECLARE @myTAB varchar(100) = '	', @connectionString  NVARCHAR(MAX) = '', @selectSQL nvarchar(4000);
		DECLARE @InstanceType varchar(100), @powershellCMD varchar(1000), @command varchar(1000),@psCommand varchar(1000);
		DECLARE @IsUnPausable INT = 1, @IsPaused INT, @InMaintenance INT;

	

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

		IF( @force = 0 )
			BEGIN
				IF( @Debug = 1 )
					BEGIN
						PRINT ' ';
						PRINT 'FORCE = 0 (DEFAULT) - Killing with Guardrails';
						PRINT ' ';
					END
	/* GUARDRAIL 1 - Is the instance in Maintenance */
				SELECT @selectSQL = 'SELECT  @InMaint = [dbo].[GetConfig] (''Instance.InMaintenance'' , 0);';
				IF( @Debug = 1 )
					BEGIN
						PRINT 'Verify Instance is in maintenance';
						PRINT @myTAB + @selectSQL;
					END;
				EXECUTE sp_EXECUTESQL @selectSQL, N'@InMaint nVARCHAR(1000) output', @InMaintenance output;
--TESTING
		SET @InMaintenance = 1
-- END TESTING
				IF( @InMaintenance = 1 )
					BEGIN
						IF( @Debug = 1 )
							BEGIN
								PRINT 'InMaintenance mode is ON';
								PRINT @myTAB +'IF( @IsUnPausable <> 0 ) SELECT @IsUnPausable = '+ convert(varchar(10), @InMaintenance) +';';
							END
						IF( @IsUnPausable <> 0 ) SELECT @IsUnPausable = @InMaintenance;
						
						SELECT @selectSQL = 'SELECT @domain = [dbo].[GetConfig](''Instance.domainName'','''')';
						IF( @Debug = 1 )
							BEGIN
								PRINT 'Get local server domain: ';
								PRINT @myTAB + @selectSQL;
							END;
						EXECUTE sp_EXECUTESQL @selectSQL, N'@domain nVARCHAR(1000) output', @domainName output;

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
								IF( @Debug = 1 )
									BEGIN
										PRINT 'FAILED TO LOAD master-dsn.txt - CRASH OUT RETURN 2';
										PRINT @myTAB +'IF( @IsUnPausable <> 0 ) SELECT @IsUnPausable = '+ convert(varchar(10),@file_Exists) +';';
									END;
								SELECT @Action = 2;
							END;
						ELSE
							BEGIN
								SELECT @powershellCMD = 'powershell.exe -c "Add-PSSnapin SqlServerCmdletSnapin100;invoke-sqlcmd '+ REPLACE(REPLACE(LEFT(@connectionString,CHARINDEX(';Persist', @connectionString)-1) ,'Data Source=','-ServerInstance '''),';Initial Catalog=',''' -Database ') +' -Query ';
								IF( @Debug = 1 )
									BEGIN
										PRINT 'Target powershell cmd: ' + @powershellCMD;
										PRINT @myTAB +'IF( @IsUnPausable <> 0 ) SELECT @IsUnPausable = '+ convert(varchar(10),@file_Exists) +';';
									END;
							END; -- File exists
						IF( @IsUnPausable <> 0 ) SELECT @IsUnPausable = @file_Exists ;
					END; --InMaintenance
				END; --FORCE = 1
			ELSE
				BEGIN
					IF( @debug = 1 )
						BEGIN
							PRINT 'FORCE = 1 No guradrails'
							PRINT @myTAB +'IF( @IsUnPausable <> 0 ) SELECT @IsUnPausable = 1;';
						END;
					IF( @IsUnPausable <> 0 ) SELECT @IsUnPausable = 1;
				END;
			
			SELECT @updateSQL = '''UPDATE [StandbyDBManager].[dbo].[StandbyConfig] SET STATUS = ''''ACTIVE'''' WHERE STATUS =''''PAUSED'''' AND TargetInstanceID IN ( SELECT TargetInstanceID FROM TargetInstance WHERE InstanceName like '''''+ confValue+'.'+ @domainName +'%'''')''"'
			FROM systemconfig WHERE confkey = 'Instance.serverName';

			IF( @IsUnPausable = 1 )
				BEGIN
					SELECT @command = @powershellCMD + @selectSQL;
						If( (@whatIF = 1) AND (@Debug = 1) )
							BEGIN
								PRINT '[WHAT IF] Target powershell SQL: ' + @updateSQL;
							END;
						ELSE
							BEGIN
								EXEC xp_cmdshell  @command ;
							END;
				END;
			ELSE
				BEGIN
					IF( @debug = 1 )
						BEGIN
							PRINT 'Not UnPausable'
						END;
				END;

        /*work is complete - return resultset for digestion*/
		EXEC @Action = policy.logShippingEnabled @debug 

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
        EXEC policy.logShippingEnabled @Debug

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
	This procedure pauses logshipping on for a target instance.
History:
	20180314	hbrotherton		W-4793558	Created
Quip Documentation:
	https://salesforce.quip.com/ihjFAxAU56gm
Comments:

	EXEC action.enableLogShipping @debug = 1, @whatIf = 1
	
#################################################################################*/
END;
GO

/*Sign procedure*/

--ADD SIGNATURE TO [action].[pauseLogShipping]
--BY  CERTIFICATE [SFMCDBA_PoLPExecution]; 
--GO

--/*Grant Execute DBA4*/
--GRANT EXECUTE ON [action].[pauseLogShipping] TO DBA4;
--GO