USE [Utility];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
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
    ('p1', CAST(@p1 AS nvarchar(max))),
    ('p2', CAST(@p2 AS nvarchar(max))),
    ('p3', CAST('##Sensitive##' AS nvarchar(max))),
    ('Debug', CAST(@Debug AS nvarchar(max)));  

    SELECT @ProcedureName = QUOTENAME(DB_NAME())+'.'+QUOTENAME(OBJECT_SCHEMA_NAME(@@PROCID, DB_ID()))+'.'+QUOTENAME(OBJECT_NAME(@@PROCID, DB_ID()))

    DECLARE @PolpLogID bigint
    EXEC Utility.dbo.PoLPLogIns
    @ProcedureName = @ProcedureName, 
    @ParameterValue = @PVJ,
    @PoLPLogID = @PoLPLogID OUTPUT

    BEGIN TRY  --select * from systemconfig

        /*do the work of the proc*/
		-- DECLARE @Debug TINYINT = 1
		DECLARE @instanceName varchar(10), @myFile varchar(100), @bulkInsert varchar(100)
		DECLARE @CommentString varchar(4000), @Action tinyint = 0, @Result varchar(500) = '';  
		DECLARE @myTAB varchar(100) = '	', @connectionString  NVARCHAR(MAX), @selectSQL nvarchar(4000), @killCMD varchar(100);
		DECLARE @InstanceType varchar(100), @powershellCMD varchar(1000), @command varchar(1000),@psCommand varchar(1000),@binary					VARBINARY(max)

		SELECT @instanceName = REPLACE(confValue,'0','') from systemConfig where confKey = 'Instance.instanceName'

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
		END +'\StandbyUtil\BIN\master-dsn.txt'

		SELECT @selectSQL = 'SELECT @FileContent=BulkColumn FROM   OPENROWSET(BULK'''+ @myFile +''',SINGLE_CLOB) x;'
		IF @Debug = 1
			BEGIN
				PRINT 'Get standbyDBmanager connetion string from: '+ @myFile;
				PRINT @myTAB + @selectSQL;
			END;

		EXECUTE sp_EXECUTESQL @selectSQL, N'@FileContent nVARCHAR(1000) output', @connectionString output
		--SELECT @powershellCMD = 'invoke-sqlcmd '+ REPLACE(REPLACE(REPLACE(@connectionString ,'Data Source=','-ServerInstance "'),';Initial Catalog=','" -Database '),';Persistent Security Info=True;Integrated Security=True;',' -Query "SELECT @@SERVERNAME"')
		SELECT @powershellCMD = 'invoke-sqlcmd -h -1 -b '+ REPLACE(REPLACE(LEFT(@connectionString,CHARINDEX(';Persist', @connectionString)-1) ,'Data Source=','-ServerInstance "'),';Initial Catalog=','" -Database ') +' -Query '
		IF @Debug = 1
			BEGIN
				PRINT 'Target standbyDBmanager : '+ @connectionString;
				PRINT 'Target powershell cmd : ' + @powershellCMD
			END;
		
		SELECT @selectSQL = 'SELECT @ServerType = [dbo].[GetConfig](''Instance.ServerType'','''')'
		IF @Debug = 1
			BEGIN
				PRINT 'Get local server type: '+ @myFile;
				PRINT @myTAB + @selectSQL;
			END;
		EXECUTE sp_EXECUTESQL @selectSQL, N'@ServerType nVARCHAR(1000) output', @InstanceType output

		IF( @instanceType = '' )
			BEGIN
				IF @Debug = 1
					BEGIN
						PRINT 'Sever Type: UNDEFINED !!!!'+ @InstanceType;
						PRINT 'Setting Test Value : Restore '
						SELECT @instanceType = 'Restore'
					END;
				SELECT @Action = 45;
			END
		ELSE
			BEGIN
				IF @Debug = 1
					BEGIN
						PRINT 'Sever Type: '+ @InstanceType;
					END;
			END
		-- select * from systemconfig

			SELECT @selectSQL = '"SET NOCOUNT ON;SELECT status
								  FROM [StandbyDBManager].[dbo].[StandbyConfig] AS SC
								  LEFT JOIN [StandbyDBManager].[dbo].[TargetInstance] AS TI on (SC.TargetInstanceID = TI.TargetInstanceID )
								  Where TI.InstanceName like '''+ confValue +'%''
								 group by status"'
					FROM systemconfig where confkey = 'Instance.serverName'
--MORE TESTING VALUES 
			SELECT @selectSQL = REPLACE(@selectSQL ,'XTINDBA01','XTINP2CB02D8')
					PRINT 'Target powershell cmd : ' + @powershellCMD + @selectSQL	
		SELECT @psCommand = @powershellCMD + @selectSQL
			
			
		SELECT @binary = convert(varbinary(max), @psCommand);
		SELECT @command = 'powershell.exe -EncodedCommand ' + cast('' as xml).value('xs:base64Binary(sql:variable("@binary"))', 'varchar(max)');
		SELECT @command = 'sqlcmd -h -1 -b -W -S "IND2Q00DBA02.QA.LoCaL\I2,3535" -d StandbyDBmanager -Q "SET NOCOUNT ON;select @@serverName"';
			
		PRINT @command
		EXEC @result = xp_cmdshell @command--, no_output						
		print 'Results '+ @result


		SELECT   [dbo].[GetConfig]('Instance.ServerType','')

        /*work is complete - return resultset for digestion*/
 --       SELECT @var AS MyValue, @p1 AS MyOtherValue, @p2 AS MyOtherOtherValue

        /*Update Complete date in the log*/
        EXEC Utility.dbo.PoLPLogUpd @PoLPLogID = @PoLPLogID
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
--        SELECT @var AS MyValue, @p1 AS MyOtherValue, @p2 AS MyOtherOtherValue

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
	This procedure returns the state of logshippinh on a target.
History:
	20180314	hbrotherton		W-4793558	Created
Quip Documentation:
	https://salesforce.quip.com/tpr8AsPt7cij
Comments:

	EXEC action.killSPID @spid = 41, @force = 1, @whatIf = 1, @debug = 1
	EXEC action.killSPID @spid = 41, @force = 0, @whatIf = 0, @debug = 1
	EXEC action.killSPID @spid = 41, @force = 0, @whatIf = 0, @debug = 0
	EXEC action.killSPID @spid = 51, @force = 0, @whatIf = 1, @debug = 1
	EXEC action.killSPID @spid = 57, @force = 0, @whatIf = 1, @debug = 0
	EXEC action.killSPID @spid = 57, @force = 0, @whatIf = 1, @debug = 0
	EXEC action.killSPID @spid = 57, @force = 0, @whatIf = 1, @debug = 0
				SELECT * FROM sys.sysprocesses WHERE open_tran = 1
				SELECT * FROM sys.dm_exec_Sessions  WHERE open_tran = 1
#################################################################################*/
END;
GO

/*Sign procedure*/
ADD SIGNATURE TO [dbo].[DemoPoLP]
BY  CERTIFICATE [SFMCDBA_PoLPExecution]; 
GO

/*Grant Execute DBA4*/
GRANT EXECUTE ON [dbo].[DemoPoLP] TO DBA4;
GO