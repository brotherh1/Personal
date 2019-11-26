SET NOCOUNT ON

DECLARE @maxLog      INT,
        @searchStr   VARCHAR(256),
        @startDate   DATETIME;

DECLARE @errorLogs   TABLE (
    LogID    INT,
    LogDate  DATETIME,
    LogSize  BIGINT   );

DECLARE @logData      TABLE (
    LogDate     DATETIME,
    ProcInfo    VARCHAR(64),
    LogText     VARCHAR(MAX)   );

SELECT  @searchStr = 'Stack Dump being sent',
        @startDate = getDate() - 7;

INSERT INTO @errorLogs
EXEC sys.sp_enumerrorlogs;

SELECT TOP 1 @maxLog = LogID
FROM @errorLogs
WHERE [LogDate] <= @startDate
ORDER BY [LogDate] DESC;

WHILE @maxLog >= 0
BEGIN
    INSERT INTO @logData
    EXEC sys.sp_readerrorlog @maxLog, 1, @searchStr;
    
    SET @maxLog = @maxLog - 1;
END

SELECT [LogDate], [LogText]
FROM @logData
WHERE [LogDate] >= @startDate
ORDER BY [LogDate];