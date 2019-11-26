
USE Master;
GO
DECLARE @BakPath varchar(256)
DECLARE @SQL varchar(1024)
DECLARE @cmd varchar(2048)
SELECT @BakPath = SystemPath+ '\Audit\' FROM Utility.dbabackup.BackupPath WHERE BackupPathID = 
  (SELECT MIN(BackupPathID) FROM Utility.dbabackup.BackupPath bp
    JOIN Utility.dbabackup.BackupPathSet bps ON bp.BackupPathSetID = bps.BackupPathSetID
    WHERE bps.name = 'DefaultSystem')
SELECT @cmd = 'powershell.exe -c "if (-not( test-path ''' + @bakpath + ''')) { mkdir ''' + @bakpath + '''}'
EXEC xp_cmdshell @cmd
SELECT @BakPath = @BakPath + '\Cmdshell\'
SELECT @cmd = 'powershell.exe -c "if (-not( test-path ''' + @bakpath + ''')) { mkdir ''' + @bakpath + '''}'
EXEC xp_cmdshell @cmd
IF NOT EXISTS (SELECT * FROM sys.dm_server_audit_status WHERE Name = 'Audit_Cmdshell')
BEGIN
  SELECT @SQL = 'USE master; CREATE SERVER AUDIT Audit_Cmdshell
  TO FILE (FILEPATH = ''' + @BakPath + ''', MAXSIZE = 4GB, MAX_ROLLOVER_FILES = 20)
  WITH (ON_FAILURE = CONTINUE, QUEUE_DELAY=1000);'
  EXEC (@SQL);
END
IF NOT EXISTS (SELECT * FROM sys.database_audit_specifications WHERE Name = 'Audit_Cmdshell_spec')
BEGIN
  CREATE DATABASE AUDIT SPECIFICATION Audit_Cmdshell_Spec
  FOR SERVER AUDIT Audit_Cmdshell
   	ADD (EXECUTE ON OBJECT::[dbo].[xp_cmdshell] by public)
	WITH (STATE=ON);
END

ALTER DATABASE AUDIT SPECIFICATION Audit_Cmdshell_Spec WITH (STATE=ON)
ALTER SERVER AUDIT Audit_Cmdshell
WITH (STATE = ON);