USE [SQLMonitor_Test]
GO
/****** Object:  StoredProcedure [dbo].[ClusterMerge]    Script Date: 10/30/2017 11:09:12 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[ClusterMerge]
            @clusterName varchar(100),
            @nodeCount int,
            @pod int,
			@primaryStack int,
			-- splitStack  -- no longer required
            -- isPolyServe -- no longer required
            -- isProduction -- altered later
			@isQA int,
			-- isStaging   -- no longer required
            -- isPreview   -- no longer required
			@buildDate datetime, 
			@isON int,
			-- deactivatedDate
			@userName varchar(100),
			@isStandby int

AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;
	-- select * from dbo.cluster

MERGE dbo.cluster AS old
USING (VALUES ( @clusterName ,
				@nodeCount ,
				@pod ,
				@primaryStack ,
				@isQA ,
				@buildDate ,
				@isON ,
				-- deactivatedDate
				@userName ,
				@isStandby )) AS new(	clusterName,
										nodes, --changed to table column name.
										pod ,
										primaryStack ,
										isQA ,
										buildDate ,
										isON ,
										-- deactivatedDate
										userName ,
										isStandby )
ON new.clusterName = old.clusterName
WHEN MATCHED THEN --Updates if the old field does not equal the new.
  UPDATE SET old.nodes = ISNULL(NULLIF(new.nodes,old.nodes),new.nodes), --new.nodes,
             old.pod = ISNULL(NULLIF(new.pod,old.pod),new.pod), --new.pod,
			 old.primaryStack = ISNULL(NULLIF(new.primaryStack,old.primaryStack),new.primaryStack), --new.primaryStack,
			 old.isQA = ISNULL(NULLIF(new.isQA,old.isQA),new.isQA), --new.isQA,
			 old.isON = ISNULL(NULLIF(new.isON,old.isON),new.isON), --new.isON,
			 old.lastUpdated = GETDATE(),
			 old.lastUpdateBy = ISNULL(NULLIF(new.userName,old.lastUpdateBy),new.userName), --new.userName,
			 old.isStandby = ISNULL(NULLIF(new.isStandby,old.isStandby),new.isStandby) --new.isStandby
WHEN NOT MATCHED THEN
  INSERT(clusterName,
		 nodes,
         pod,
		 primaryStack,
		 isQA,
		 buildDate,
		 isON,
		 createDate,
		 createdBy,
		 isStandby)
  VALUES(new.clusterName,
         new.nodes,
         new.pod,
		 new.primaryStack,
		 new.isQA,
		 new.buildDate,
		 new.isOn,
		 GETDATE(),
		 new.userName,
		 new.isStandby);

END

