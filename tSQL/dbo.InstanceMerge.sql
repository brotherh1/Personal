USE [SQLMonitor_test]
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[InstanceMerge]') AND type in (N'P', N'PC'))
BEGIN
	DECLARE @SQL NVARCHAR(4000)
	SELECT @SQL = 'CREATE PROCEDURE [dbo].[InstanceMerge] AS RETURN 0;' -- Create dummy sproc 
	EXEC(@SQL);
END
GO
ALTER PROCEDURE [dbo].[InstanceMerge]
	@FQDN varchar(128),
	@rootname varchar(50),
	@InstanceName varchar(50),
	@InstanceNumber varchar(10),
	@domain varchar(50),
	@IPAddress varchar(32),
	@InstancePort varchar(10),
	@Stack int,
	@Clusterid int,
	@Current_host int,
	@IsOn bit,
	--isProduction  -- altered later
	@IsStandby bit,
	--isStaging   -- no longer required
	@IsQA bit,
	--isPreview   -- no longer required
	@Builddate datetime,
	@Min_SQL_RAM_MB int,
	@Max_SQL_RAM_MB int,
	--@OS varchar(128),  NULL is default hardcoded
	--@DB_Platform varchar(128), -- Default is MSSQL hardcoded
	@Engine_version varchar(128),
	--@createdate datetime,
	@userName varchar(128),
	--@lastupdated datetime,
	--@lastupdateby varchar(128),
	-- @Tenants varchar(255),   -- Need Logic to update this automatically
	-- @Ignite_DBID smallint,   -- Need Logic to update this automatically
	-- @IsDTC bit, --NOT NULL CONSTRAINT [DF_Instance_IsDTC]  DEFAULT ((0)),
	@IsMonitored bit, --NOT NULL CONSTRAINT [DF_Instance_IsMonitored]  DEFAULT ((1)),
	-- @Ignite_URL varchar(100), -- Need Logic to update this automatically
	@Environmentid tinyint --NOT NULL CONSTRAINT [DF_Instance_Environmentid]  DEFAULT ((0)),

AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;
	-- select * from dbo.machine

MERGE dbo.instance AS old
USING (VALUES ( @FQDN ,
				@rootname ,
				@InstanceName ,
				@InstanceNumber ,
				@domain ,
				@IPAddress ,
				@InstancePort ,
				@Stack ,
				@Clusterid ,
				@Current_host ,
				@IsOn ,
				@IsStandby ,
				@IsQA ,
				@Builddate ,
				@Min_SQL_RAM_MB ,
				@Max_SQL_RAM_MB ,
				--@OS ,  NULL is default hardcoded
				--@DB_Platform , -- Default is MSSQL hardcoded
				@Engine_version ,
				@userName ,
				--@lastupdated ,
				--@lastupdateby ,
				-- @Tenants ,   -- Need Logic to update this automatically
				-- @Ignite_DBID ,   -- Need Logic to update this automatically
				-- @IsDTC , --NOT NULL CONSTRAINT [DF_Instance_IsDTC]  DEFAULT ((0)),
				@IsMonitored , --NOT NULL CONSTRAINT [DF_Instance_IsMonitored]  DEFAULT ((1)),
				-- @Ignite_URL , -- Need Logic to update this automatically
				@Environmentid  )) AS new(	FQDN ,
											rootname ,
											InstanceName ,
											InstanceNumber ,
											domain ,
											IPAddress ,
											InstancePort ,
											Stack ,
											Clusterid ,
											Current_host ,
											IsOn ,
											IsStandby ,
											IsQA ,
											Builddate ,
											Min_SQL_RAM_MB ,
											Max_SQL_RAM_MB ,
											--@OS varchar(128),  NULL is default hardcoded
											--@DB_Platform varchar(128), -- Default is MSSQL hardcoded
											Engine_version ,
											--@createdate datetime,
											userName ,
											--@lastupdated datetime,
											--@lastupdateby varchar(128),
											-- @Tenants varchar(255),   -- Need Logic to update this automatically
											-- @Ignite_DBID smallint,   -- Need Logic to update this automatically
											-- @IsDTC bit, --NOT NULL CONSTRAINT [DF_Instance_IsDTC]  DEFAULT ((0)),
											IsMonitored , --NOT NULL CONSTRAINT [DF_Instance_IsMonitored]  DEFAULT ((1)),
											-- @Ignite_URL varchar(100), -- Need Logic to update this automatically
											Environmentid )
ON new.FQDN = old.FQDN
WHEN MATCHED AND ( (ISNULL(old.rootname,new.rootname) IS NULL ) OR (ISNULL(old.InstanceName,new.InstanceName) IS NULL ) OR 
				   (ISNULL(old.InstanceNumber,new.InstanceNumber) IS NULL ) OR (ISNULL(old.domain,new.domain) IS NULL ) OR 
				   (ISNULL(old.IPAddress,new.IPAddress) IS NULL ) OR (ISNULL(old.InstancePort,new.InstancePort) IS NULL ) OR 
				   (ISNULL(old.Stack,new.Stack) IS NULL ) OR (ISNULL(old.Clusterid,new.Clusterid) IS NULL ) OR 
				   (ISNULL(old.Current_host,new.Current_host) IS NULL ) OR (ISNULL(old.isON,new.isON) IS NULL ) OR 
				   (ISNULL(old.isStandby,new.isStandby) IS NULL ) OR (ISNULL(old.isQA,new.isQA) IS NULL ) OR 
				   (ISNULL(old.Builddate,new.Builddate) IS NULL ) OR (ISNULL(old.Min_SQL_RAM_MB,new.Min_SQL_RAM_MB) IS NULL ) OR 
				   (ISNULL(old.Max_SQL_RAM_MB,new.Max_SQL_RAM_MB) IS NULL ) OR (ISNULL(old.Engine_version,new.Engine_version) IS NULL ) OR
				   (ISNULL(old.IsMonitored,new.IsMonitored) IS NULL ) OR (ISNULL(old.Environmentid,new.Environmentid) IS NULL )
				 ) THEN
	UPDATE SET old.rootname = new.rootname,
		old.InstanceName = new.InstanceName,
		old.InstanceNumber = new.InstanceNumber,
		old.domain = new.domain,
		old.IPAddress = new.IPAddress,
        old.InstancePort = new.InstancePort,
		old.Stack = new.Stack,
		old.Clusterid = new.Clusterid,
		old.Current_host = new.Current_host,
		old.isON = new.isON,
		old.isStandby = new.isStandby,
		old.isQA = new.isQA,
		old.Builddate = new.Builddate,
		old.Min_SQL_RAM_MB = new.Min_SQL_RAM_MB,
		old.Max_SQL_RAM_MB = new.Max_SQL_RAM_MB,
		old.Engine_version = new.Engine_version,
		old.IsMonitored = new.IsMonitored,
		old.Environmentid = new.Environmentid,
		old.lastUpdated = GETDATE(),
		old.lastUpdateBy = new.userName
WHEN NOT MATCHED THEN
	INSERT( FQDN,
			rootname,
			InstanceName,
			InstanceNumber,
			domain,
			IPAddress,
			InstancePort,
			Stack,
			Clusterid,
			Current_host,
			isON,
			isStandby,
			isQA,
			Builddate,
			Min_SQL_RAM_MB,
			Max_SQL_RAM_MB,
			DB_Platform,
			Engine_version,
			IsMonitored,
			Environmentid,
			createDate,
			CreatedBy )
	VALUES( new.FQDN,
			new.rootname,
			new.InstanceName,
			new.InstanceNumber,
			new.domain,
			new.IPAddress,
			new.InstancePort,
			new.Stack,
			new.Clusterid,
			new.Current_host,
			new.isON,
			new.isStandby,
			new.isQA,
			new.Builddate,
			new.Min_SQL_RAM_MB,
			new.Max_SQL_RAM_MB,
			'MSSQL',
			new.Engine_version,
			new.IsMonitored,
			new.Environmentid,
			GETDATE(),
			new.userName

  )