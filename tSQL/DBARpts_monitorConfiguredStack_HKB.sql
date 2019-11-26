USE [DBA]
GO
/****** Object:  StoredProcedure [dbo].[DBARpts_monitorConfiguredStack]    Script Date: 10/4/2018 3:22:12 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*####################################################################
$$Author: Brennan Lindamood
$$Purpose: 
$$ Call Example:  [dbo].[DBARpts_monitorConfiguredStack] 'blindamood@salesforce.com'
$$Modfied: 11/15/2015 Created
######################################################################*/
--ALTER procedure [dbo].[DBARpts_monitorConfiguredStack_HKB] (@pod varchar(10) = '', @notify bit = 1, @email varchar(250) = '') as

set nocount on
set transaction isolation level read uncommitted

declare @body varchar(max), @subject varchar(250), @myCreateTable varchar(100), @myWhereClause varchar(100), @SQL varchar(8000)
select  @body = ''
declare  @email varchar(250), @notify bit = 1
select @email = 'hbrotherton@salesforce.com'
DECLARE @pod varchar(10) = 'P5'

SELECT @myCreateTable = 'DBARpts_'+ @pod +'_ConfiguredStack'
SELECT @myWhereClause = 'where  serverType <> ''Down'' and podName = '''+ REPLACE(@pod, 'P','POD ') +''''

IF OBJECT_ID('tempdb..#currErrs') IS NOT NULL DROP TABLE #currErrs

create TABLE #currErrs ( [srv] nvarchar(128), [instanceStack] nvarchar(3000), [systemDBStack] nvarchar(3000) )

	exec dbo.DBARpts_execAllServers @noColumns =2, 
	@createTable = @myCreateTable,
	@inCmd ='exec ?serverName.utility.dbo.DBARpts_retrieveConfiguredStack',
	@renameColumns = 'srv, column1 instanceStack, column2 systemDBStack',
	@retry = 1, @errorEmail = 'junk@salesforce.com',
	@serverWhereClause = @myWhereClause

-- now pickup the errors
SELECT @SQL = 'delete from dbarpts_'+ @pod +'_ConfiguredStack where instanceStack = ''?error connecting'''
	EXEC (@SQL)
SELECT @SQL = 'delete from dbarpts_'+ @pod +'_configuredstack where instancestack = systemdbstack'
	EXEC (@SQL)
SELECT @SQL = 'delete from dbarpts_'+ @pod +'_ConfiguredStack where srv like ''%dba01%'' or srv like ''%db001%'' or srv like ''%ma%'' or srv like ''%ops%'''
	EXEC (@SQL)
SELECT @SQL = 'delete from dbarpts_'+ @pod +'_configuredstack where systemDBstack = '''' or instancestack = ''[s100]'''
	EXEC (@SQL)

SELECT @SQL = 'update exacttargetsqlinstallations 
set serverdescription = replace(serverdescription, instanceStack, systemDBstack)
from exacttargetsqlinstallations i
join DBARpts_'+ @pod +'_configuredStack s
on i.sqlinstallation = s.srv
where instancestack like ''%s0%'' and systemdbstack like ''%s%'''
	EXEC (@SQL)

SELECT @SQL = 'delete from dbarpts_'+ @pod +'_ConfiguredStack where instancestack like ''%s0%'' and systemdbstack like ''%s%'''
	EXEC (@SQL)

SELECT @SQL = 'update exacttargetsqlinstallations 
set serverdescription = systemdbstack + '' ''+isnull(serverdescription,'''')
from exacttargetsqlinstallations i
join DBARpts_'+ @pod +'_configuredStack s
on i.sqlinstallation = s.srv
where instancestack = '''' and systemdbstack like ''%s%'''
	EXEC (@SQL)

SELECT @SQL = 'delete from dbarpts_'+ @pod +'_ConfiguredStack where instancestack = '''' and systemdbstack like ''%s%'''
	EXEC (@SQL)

SELECT @SQL = 'select * from DBARpts_'+ @pod +'_ConfiguredStack'
INSERT #CurrErrs
	EXEC (@SQL)

IF NOT EXISTS ( select * FROM #currErrs ) 
	BEGIN
		print 'no problems found'
		RETURN
	END
ELSE
	BEGIN
		select @body = @body + cast('Instance' as char(9))+cast('SystemDB' as char(9)) + char(13)
		select @body = @body + cast(' Stack' as char(9))+cast(' Stack' as char(9)) + 'Server' +char(13)

		select @body = @body + cast(instanceStack as char(9))+cast(systemDBstack as char(9))+ srv + '-'+serverdescription + char(13)
			from #currErrs as s
			join exacttargetsqlinstallations i
			on s.srv = i.sqlinstallation

		select @body = @body + char(13)
		select @body = @body + 'https://salesforce.quip.com/KmIVAzdbm0lx' +char(13)
	
		

		if isnull(@email,'') = ''
			select @email = utility.dbo.getConfig('Email.Notification','dbinformation@exacttarget.com')

			SELECT @Subject ='ALERT - '+ @pod +' Stack mismatch'

		IF( @notify = 1 )
			BEGIN
				EXEC master.dbo.sp_SEND_SMTPMail
					 @sTo = @email,
					 @sSubject = @subject,
					 @sBody = @body
			END
		ELSE
			BEGIN
				print @body
			END

		return
	END


