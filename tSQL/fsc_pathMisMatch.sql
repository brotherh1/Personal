/****** Script for SelectTopNRows command from SSMS  ******/
SELECT *
  FROM [SnapBackupDB].[dbo].[LogCopyConfig]
 where destpath NOT like '%'+ Left(Name, CharIndex('\',Name) - (len(name)-CharIndex('\',Name)+1) ) +'\'+ Left(Name, CharIndex('\',Name) - 1 ) +'%'
 and Name like '%\%'
 order by name

 -- select * from  [SnapBackupDB].[dbo].[LogCopyConfig] where name  like 'ATL1P04C027%'

/*
begin tran -- commit
  update [SnapBackupDB].[dbo].[LogCopyConfig] 
  SET destpath = REPLACE(destPath,'ATL1P04C027\ATL1P04C027','StandAloneInstances\ATL1P04C027')
  WHERE logCopyConfigID in (613,614)
  
 */  