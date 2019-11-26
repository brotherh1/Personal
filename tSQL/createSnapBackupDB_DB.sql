USE [master]
GO

/****** Object:  Database [SnapBackupDB]    Script Date: 3/9/2018 12:18:05 PM ******/
DECLARE @targetDB VARCHAR(100) = 'SnapBackupDB'; -- <targetDB>
DECLARE @databasePath VARCHAR(100), @createStatement VARCHAR(MAX);

SELECT @databasePath = UTILITY.dbo.getDriveLetter () +':\SQL\';  --OR should it be getInstanceDriveLetter ???
SELECT @databasePath = @databasePath + UTILITY.dbo.getConfig('Instance.InstanceName', '') +'\Utility\';
--PRINT @databasePath 

IF NOT EXISTS (SELECT name FROM SYS.databases WHERE name = @targetDB )
BEGIN
	SELECT @createStatement = 'CREATE DATABASE ['+ @targetDB +']
	 CONTAINMENT = NONE
	 ON  PRIMARY 
	( NAME = N'''+ @targetDB +''', FILENAME = NN'''+  @databasePath +'\'+ @targetDB +'.mdf'' , SIZE = 4096KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
	 LOG ON 
	( NAME = N'''+ @targetDB +'_log'', FILENAME = N'''+  @databasePath +'\'+ @targetDB +'_log.ldf'', SIZE = 18240KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
	';
	SELECT @createStatement;
	EXEC(@createStatement);

	DECLARE @alterStatement VARCHAR(100), @execStatement VARCHAR(100);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET COMPATIBILITY_LEVEL = '+ CONVERT(VARCHAR(5), MAX( cmptLevel ) ) +';' FROM sysdatabases;
	SELECT @alterStatement;
	EXEC(@alterStatement);

	IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
	begin
		SELECT @execStatement = 'EXEC ['+ @targetDB +'].[dbo].[sp_fulltext_database] @action = ''enable'';';
		SELECT @execStatement
		EXEC(@execStatement);
	end

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET ANSI_NULL_DEFAULT OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET ANSI_NULLS OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET ANSI_PADDING OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET ANSI_WARNINGS OFF;'; 
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET ARITHABORT OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET AUTO_CLOSE OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET AUTO_SHRINK OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET AUTO_UPDATE_STATISTICS ON;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET CURSOR_CLOSE_ON_COMMIT OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET CURSOR_DEFAULT  GLOBAL;'; 
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET CONCAT_NULL_YIELDS_NULL OFF;'; 
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET NUMERIC_ROUNDABORT OFF;'; 
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET QUOTED_IDENTIFIER OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET RECURSIVE_TRIGGERS OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET  DISABLE_BROKER;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET AUTO_UPDATE_STATISTICS_ASYNC OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET DATE_CORRELATION_OPTIMIZATION OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET TRUSTWORTHY OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET ALLOW_SNAPSHOT_ISOLATION OFF;'; 
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET PARAMETERIZATION SIMPLE;'; 
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET READ_COMMITTED_SNAPSHOT OFF;'; 
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET HONOR_BROKER_PRIORITY OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET RECOVERY SIMPLE;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET  MULTI_USER;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET PAGE_VERIFY CHECKSUM;';  
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET DB_CHAINING OFF;';
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF );'; 
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET TARGET_RECOVERY_TIME = 0 SECONDS;'; 
	SELECT @alterStatement;
	EXEC(@alterStatement);

	SELECT @alterStatement = 'ALTER DATABASE ['+ @targetDB +'] SET  READ_WRITE;'; 
	SELECT @alterStatement;
	EXEC(@alterStatement);
END;

　
 /*####################################################################
Purpose:  
     This script dynamically builds the SnapBackupDB database based on instance values. 
History:  
     20180410 hbrotherton W-####### Created
     
     YYYYMMDD USERID W-000000000 This is what I changed.
Comments:
     Anything you feel is important to share that is not the "purpose"
Quip Documentaion:
     HTTP://
######################################################################*/

GO
　