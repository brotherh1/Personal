USE [SQLMonitor]
GO

/****** Object:  Table [dbo].[InstanceSAN]    Script Date: 8/25/2017 10:38:36 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[InstanceSAN]') AND type in (N'U')) 
BEGIN 
	CREATE TABLE [dbo].[InstanceSAN](
		[CSID] [int] IDENTITY(1,1) NOT NULL,
		[InstanceID] [int] NULL,
		[SANID] [int] NULL,
		[Ports] [varchar](128) NULL,
		[Affiliationtype] [tinyint] NULL,
		[Connection_live_date] [datetime] NULL,
		[IsOn] [bit] NULL,
		[createdate] [datetime] NULL CONSTRAINT [DF_InstanceSAN_createdate]  DEFAULT (getdate()),
		[createdby] [varchar](128) NULL,
		[lastupdated] [datetime] NULL,
		[lastupdateby] [varchar](128) NULL,
	 CONSTRAINT [PK_InstanceSAN] PRIMARY KEY CLUSTERED 
		(
			[CSID] ASC
		) ON [FG1],
	 CONSTRAINT [UQ_InstanceSAN] UNIQUE NONCLUSTERED 
		(
			[InstanceID] ASC,
			[SANID] ASC
		) ON [FG1]
	) ON [FG1]
END
GO

SET ANSI_PADDING OFF
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_InstanceSAN_createdate]') AND type = 'D') 
BEGIN 
	ALTER TABLE [dbo].[InstanceSAN] ADD  CONSTRAINT [DF_InstanceSAN_createdate]  DEFAULT (getdate()) FOR [createdate] 
END 

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_InstanceSAN_Cluster]') AND parent_object_id = OBJECT_ID(N'[dbo].[InstanceSAN]')) 
BEGIN
	ALTER TABLE [dbo].[InstanceSAN]  WITH CHECK ADD CONSTRAINT [FK_InstanceSAN_Cluster] FOREIGN KEY([Instanceid]) REFERENCES [dbo].[Instance] ([InstanceID])
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_InstanceSAN_Cluster]') AND parent_object_id = OBJECT_ID(N'[dbo].[InstanceSAN]')) 
BEGIN
	ALTER TABLE [dbo].[InstanceSAN]  WITH CHECK ADD  CONSTRAINT [FK_InstanceSAN_SAN] FOREIGN KEY([SANID]) REFERENCES [dbo].[SAN] ([SANID])
END

