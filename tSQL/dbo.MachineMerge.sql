USE [SQLMonitor_Test]
GO
/****** Object:  StoredProcedure [dbo].[MachineMerge]    Script Date: 10/30/2017 11:09:12 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
alter PROCEDURE [dbo].[MachineMerge]
            @node varchar(128), --MachineName  UPPER CASE
            @sockets int, --Sockets
            -- NULL,  --Cores
            @ramGB int, --RAMM GB
            @cDriveSize int, --C drive GB
            @dDriveSize int, --D drive GB
            @nicCount int, --Number of Nics
            @PODName int, --POD
            @primaryStack int,  --Stack_primary
            --Stack_split -- no longer required
            @clusterID int , --ClusterID
            --isProduction  -- altered later
            @isQA bit, --IsQA
            --isStaging   -- no longer required
            --isPreview   -- no longer required
            @isON bit, --IsOn
            @osBuildDate datetime, --OS Build date
            @userName varchar(128), --Last updated by
            @manufacturer varchar(128), --hardware
            --Processor Type
            @isStandby bit --Standby
            --HBA Capacity MB - storage speed.

AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;
	-- select * from dbo.machine

MERGE dbo.machine AS old
USING (VALUES (  @node , --MachineName  UPPER CASE
				@sockets , --Sockets
				-- NULL,  --Cores
				@ramGB , --RAMM GB
				@cDriveSize , --C drive GB
				@dDriveSize , --D drive GB
				@nicCount , --Number of Nics
				@PODName , --POD
				@primaryStack ,  --Stack_primary
				@clusterID  , --ClusterID
				@isQA , --IsQA
				@isON , --IsOn
				@osBuildDate , --OS Build date
				@userName , --Last updated by
				@manufacturer , --hardware
				--Processor Type
				@isStandby )) AS new(	machineName,
										sockets, --changed to table column name.
										-- Cores
										RAM_GB ,
										CdriveGB ,
										DdriveGB ,
										NIC ,
										Pod,
										Stack_primary ,
										ClusterID ,
										isQA ,
										isON ,
										BuildDate ,
										userName ,
										hardware ,
										-- Processor Type
										isStandby )
ON new.machineName = old.machineName
WHEN MATCHED THEN --Do we only want to update fields that are null?
  UPDATE SET old.sockets = ISNULL(old.sockets,new.sockets), --new.sockets,
			 old.RAM_GB = ISNULL(old.RAM_GB,new.RAM_GB), --new.RAM_GB,
			 old.CdriveGB = ISNULL(old.CdriveGB,new.CdriveGB), --new.CdriveGB,
			 old.DdriveGB = ISNULL(old.DdriveGB,new.DdriveGB), --new.DdriveGB,
			 old.NIC = ISNULL(old.NIC,new.NIC), --new.NIC,
             old.pod = ISNULL(old.pod,new.pod), --new.pod,
			 old.Stack_primary = ISNULL(old.Stack_primary,new.Stack_primary), --new.Stack_primary,
			 old.isQA = ISNULL(old.isQA,new.isQA), --new.isQA,
			 old.isON = ISNULL(old.isON,new.isON), --new.isON,
			 old.lastUpdated = GETDATE(),
			 old.lastUpdateBy = ISNULL(old.lastUpdateBy,new.userName), --new.userName,
			 old.hardware = ISNULL(old.hardware,new.hardware), --new.hardware,
			 old.isStandby = ISNULL(old.isStandby,new.isStandby) --new.isStandby
WHEN NOT MATCHED THEN
  INSERT(machineName,
		 sockets,
		 RAM_GB,
		 CdriveGB,
		 DdriveGB,
		 NIC,
		 Pod,
		 Stack_primary,
		 ClusterID,
		 isQA,
		 isON,
		 BuildDate ,
		 createDate,
		 createdBy,
		 hardware,
		 isStandby)
  VALUES(new.machineName,
         new.sockets,
		 new.RAM_GB,
		 new.CdriveGB,
		 new.DdriveGB,
		 new.NIC,
		 new.POD,
		 new.Stack_primary,
		 new.ClusterID,
		 new.isQA,
		 new.isOn,
		 new.buildDate,
		 GETDATE(),
		 new.userName,
		 new.hardware,
		 new.isStandby);

END

