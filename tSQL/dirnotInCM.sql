USE [DBA]
GO
/****** Object:  StoredProcedure [dbo].[DBARpts_getBackupDirectoriesToCommVault]    Script Date: 1/22/2019 4:02:45 PM ******/

Select * from dbarpts_commVaultAlert 
where type = 's' AND serverGroup like '%XTIN%' or serverGroup like '%IND1%'

Select * from dbarpts_commVaultAlert 
where type = 's' AND serverGroup like '%XTGA%' or serverGroup like '%ATL1%'

Select * from dbarpts_commVaultAlert 
where type = 's' AND serverGroup like '%DFW%'

Select * from dbarpts_commVaultAlert 
where type = 's' AND serverGroup like '%XTIN%' or serverGroup like '%IND1%'