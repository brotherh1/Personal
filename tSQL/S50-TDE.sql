USE MASTER;

---select @@servername
DECLARE @targetDB varchar(100) = 'ExactTarget50028'
DECLARE @safenetPassword varchar(100) = '4aZ5xt@KuZSOtP7q' -- GET This from ERPM
DECLARE @dryRun int = 0 --change to 0 when happy.

-- If the credential does not exist, create the Credential. Each database
-- will have a different credential
-- safenet password will be in ERPM (ERPM account name is: "S50 - Safenet Pswd")
-- The password is likely the same for all HSM setups in the same POD

-- add EKM mapping
IF EXISTS ( SELECT c.name FROM sys.server_principal_credentials pc
			INNER JOIN sys.credentials c
				ON pc.credential_id = c.credential_id
			WHERE name = 'TDE_'+ @targetDB +'_18Q4' AND principal_id IN 
			(
				SELECT principal_id FROM sys.server_principals 
				WHERE name = 'TDE_'+ @targetDB +'_18Q4'
			) )
	BEGIN
		PRINT '-- EKM Credential Mapping to server Logon exists'
	END
ELSE
	BEGIN
		IF Exists( select * from sys.credentials where name = 'TDE_'+ @targetDB +'_18Q4' )
			BEGIN
				PRINT '-- Credential Exists'
			END
		ELSE
			BEGIN
				PRINT '-- Credential Missing'

				DECLARE @createCredSQL varchar(1000) = ( SELECT '
				CREATE CREDENTIAL [TDE_'+ @targetDB +'_18Q4] -- yyQx
				WITH IDENTITY=''fra3s50encbkup01'', SECRET = '''+ @safenetPassword +'''
				FOR CRYPTOGRAPHIC PROVIDER [safenetSQLEKM]' )

				IF( @dryRun = 1 )
					BEGIN
						PRINT '---- DryRun'
						PRINT @createCredSQL
					END
				ELSE
					BEGIN
						EXEC(@createCredSQL)
					END
			END

		-- Create your Login for CT user, if it does not exist already
		DECLARE @createLoginSQL varchar(1000)
		IF EXISTS (select * from sys.server_principals where name = system_user)
			BEGIN
				PRINT '-- Login exists'
			END
		ELSE
			BEGIN
				PRINT '-- Login missing'

				SET @createLoginSQL = 'CREATE LOGIN ['+ system_user +'] FROM WINDOWS WITH DEFAULT_DATABASE=[master];'
				IF( @dryRun = 1 )
					BEGIN
						PRINT '---- DryRun'
						PRINT @createLoginSQL
					END
				ELSE
					BEGIN
						EXEC(@createLoginSQL)
					END
			END

		-- Map your Login to the Credential  DECLARE @targetDB varchar(100) = 'ExactTarget50028'
		DECLARE @alterLoginSQL varchar(100)
		IF EXISTS ( SELECT c.name FROM sys.server_principal_credentials pc
					INNER JOIN sys.credentials c
						ON pc.credential_id = c.credential_id
					WHERE name = 'TDE_'+ @targetDB +'_18Q4' AND principal_id IN 
					(
						SELECT principal_id FROM sys.server_principals 
						WHERE name = (SELECT system_user) --ORIGINAL_LOGIN()
					) )
			BEGIN
				PRINT '-- Mapping exists'
			END
		ELSE
			BEGIN
				PRINT '-- Mapping missing'

				SET @alterLoginSQL = (SELECT '
						ALTER LOGIN ['+ system_user +'] ADD CREDENTIAL [TDE_'+ @targetDB +'_18Q4];')
				IF( @dryRun = 1 )
					BEGIN
						PRINT '---- DryRun'
						PRINT @alterLoginSQL
					END
				ELSE
					BEGIN
						EXEC(@alterLoginSQL)
					END
			END

		-- Create the Asymmetric Key
		-- The Provider Key Name will be created based on the database name team
		DECLARE @createAsymKey varchar(1000)
		IF EXISTS( select * from sys.asymmetric_keys WHERE name = 'TDE_'+ @targetDB +'_18Q4' )
			BEGIN
				PRINT '-- Asymetric MASTER Key exists'
			END
		ELSE
			BEGIN
				PRINT '-- Asymetric MASTER Key Missing - creating'

				IF( (select isnull(agRole, 0) from [Utility].[Info].[fnInstanceAGRole](@targetDB)) > 1)
				BEGIN
					SET @createAsymKey = ( SELECT ' --secondary AG
				CREATE ASYMMETRIC KEY [TDE_'+ @targetDB +'_18Q4]
				FROM Provider [safenetSQLEKM]
				WITH PROVIDER_KEY_NAME = ''TDE_'+ @targetDB +'_18Q4'', -- Use name of your Provider Key
				CREATION_DISPOSITION=OPEN_EXISTING; -- use this if the key already exists
				-- ALGORITHM = RSA_2048,
				-- CREATION_DISPOSITION=CREATE_NEW; -- use these parameters if the key is new' )
				END
				ELSE
				BEGIN
					SET @createAsymKey = ( SELECT ' --primary AG OR non AG
				CREATE ASYMMETRIC KEY [TDE_'+ @targetDB +'_18Q4]
				FROM Provider [safenetSQLEKM]
				WITH PROVIDER_KEY_NAME = ''TDE_'+ @targetDB +'_18Q4'', -- Use name of your Provider Key
				-- CREATION_DISPOSITION=OPEN_EXISTING; -- use this if the key already exists
				ALGORITHM = RSA_2048,
				CREATION_DISPOSITION=CREATE_NEW; -- use these parameters if the key is new' )
				END

				IF( @dryRun = 1 )
					BEGIN
						PRINT '---- DryRun'
						PRINT @createAsymKey
					END
				ELSE
					BEGIN
						EXEC(@createAsymKey)
					END
			END


		-- Create EKM Login
		IF EXISTS ( select * from sys.server_principals where name = 'TDE_'+ @targetDB +'_18Q4' )
			BEGIN
				PRINT '-- EKM Login exists'
			END
		ELSE
			BEGIN
				PRINT '-- EKM Login missing'

				SET @createLoginSQL = '
				CREATE LOGIN [TDE_'+ @targetDB +'_18Q4]
				FROM ASYMMETRIC KEY [TDE_'+ @targetDB +'_18Q4]; -- Use name of your Provider Key'
				IF( @dryRun = 1 )
					BEGIN
						PRINT '---- DryRun'
						PRINT @createLoginSQL
					END
				ELSE
					BEGIN
						EXEC(@createLoginSQL)
					END
			END

		-- Change Credential mapping to EKM Login
		-- remove usermapping
		IF EXISTS ( SELECT c.name FROM sys.server_principal_credentials pc
					INNER JOIN sys.credentials c
						ON pc.credential_id = c.credential_id
					WHERE name = 'TDE_'+ @targetDB +'_18Q4' AND principal_id IN 
					(
						SELECT principal_id FROM sys.server_principals 
						WHERE name = (SELECT system_user) --ORIGINAL_LOGIN()
					) )
			BEGIN
				PRINT '-- Mapping needs to be removed from user'

				SET @alterLoginSQL = (SELECT '
						ALTER LOGIN ['+ system_user +'] DROP CREDENTIAL [TDE_'+ @targetDB +'_18Q4];' )

				IF( @dryRun = 1 )
					BEGIN
						PRINT '---- DryRun'
						PRINT @alterLoginSQL
					END
				ELSE
					BEGIN
						EXEC(@alterLoginSQL)
					END
			END
		ELSE
			BEGIN
				PRINT '-- Credential Mapping gone ...somehow...DryRun?'
			END

---- add EKM mapping
--IF EXISTS ( SELECT c.name FROM sys.server_principal_credentials pc
--			INNER JOIN sys.credentials c
--				ON pc.credential_id = c.credential_id
--			WHERE name = 'TDE_'+ @targetDB +'_18Q4' AND principal_id IN 
--			(
--				SELECT principal_id FROM sys.server_principals 
--				WHERE name = 'TDE_'+ @targetDB +'_18Q4'
--			) )
--	BEGIN
--		PRINT '-- EKM Credential Mapping to server Logon exists'
--	END
--ELSE
--	BEGIN
	-- add EKM mapping 
		PRINT '-- EKM Credential Mapping missing'

		SET @alterLoginSQL = '
				ALTER LOGIN [TDE_'+ @targetDB +'_18Q4] ADD CREDENTIAL [TDE_'+ @targetDB +'_18Q4];'
		IF( @dryRun = 1 )
			BEGIN
				PRINT '---- DryRun'
				PRINT @alterLoginSQL
			END
		ELSE
			BEGIN
				EXEC(@alterLoginSQL)
			END
--	END

-- Delete your Login
		DECLARE @dropLoginSQL varchar(100)
		IF EXISTS (select * from sys.server_principals where name = system_user)
			BEGIN
				PRINT '-- Login exists - needs to be removed'
		
				SET @dropLoginSQL = (SELECT '
						DROP LOGIN ['+ system_user +'];')
				IF( @dryRun = 1 )
					BEGIN
						PRINT '---- DryRun'
						PRINT @dropLoginSQL
					END
				ELSE
					BEGIN
						EXEC(@dropLoginSQL)
					END
			END
		ELSE
			BEGIN
				PRINT '-- Login removed....somehow....DryRun?'
			END
END
-- run all of the above steps on the secondary  select * from [Utility].[Info].[fnInstanceAGRole]('ExactTarget50028')
IF( (select isnull(agRole, 0) from [Utility].[Info].[fnInstanceAGRole](@targetDB)) > 1)
	BEGIN 
		--  check secondary recovery status
		EXEC master.dbo.xp_readerrorlog 0, 1, N'recovery'

		-- monitor the status of the AG after secondary is fully recovered
		select * from  sys.dm_hadr_availability_group_states
		-- it should say HEALTHY

		-- ensure trn log backups are successful at secondary
		SELECT TOP 10 backup_finish_date
		FROM msdb.dbo.backupset
		WHERE database_name = 'ExactTarget50004' AND type = 'L'
		ORDER BY backup_finish_date DESC
	END
ELSE
	BEGIN
		---- BEFORE CONTINUING, on the primary run 
		DECLARE @alterDBSQL varchar(1000)

		IF( (SELECT isNull(is_suspended,0) FROM sys.dm_hadr_database_replica_states where is_Local = 1 AND DB_NAME(database_ID) = @targetDB) = 0 )
			BEGIN
				PRINT '-- HADR needs to be suspended'

				SET @alterDBSQL = (SELECT '
				alter database '+ @targetDB +' set HADR suspend;') -- alter database ExactTarget50028 set HADR resume;
				IF( @dryRun = 1 )
					BEGIN
						PRINT '---- DryRun'
						PRINT @alterDBSQL
					END
				ELSE
					BEGIN
						EXEC(@alterDBSQL)
					END
			END
		ELSE
			BEGIN
				PRINT '-- HADR is suspended'
			END

		-- DO NOT RUN THESE STEPs ON THE SECONDARY
		-- Create Database Encryption Key
		--DECLARE @ResultInt int; 
		--DECLARE @sqlCMD nvarchar(1000) = 'select @results = isNull(count(*),0) from '+ @targetDB +'.sys.asymmetric_keys WHERE name = ''TDE_'+ @targetDB +'_18Q4''' 
		--print @sqlcmd
		--EXEC sp_executeSQL @sqlCMD, N'@results int OUTPUT',@results=@ResultInt OUTPUT

		--DECLARE @ResultInt int; EXEC @ResultInt = ( select * from ExactTarget50028.sys.asymmetric_keys )
		--print @resultInt
		IF Exists ( SELECT percent_complete FROM sys.dm_database_encryption_keys WHERE db_name(database_ID) = @targetDB AND encryptor_type = 'ASYMMETRIC KEY' )
			BEGIN
				PRINT '-- Asymetric DB Key exists'
			END
		ELSE
			BEGIN
				PRINT '-- Asymetric DB Key Missing - creating'

				SET @alterDBSQL = '
				Use ['+ @targetDB +'];
				CREATE DATABASE ENCRYPTION KEY
				WITH ALGORITHM = AES_256
				ENCRYPTION BY SERVER ASYMMETRIC KEY TDE_'+ @targetDB+'_18Q4;'

				IF( @dryRun = 1 )
					BEGIN
						PRINT '---- DryRun'
						PRINT @alterDBSQL
					END
				ELSE
					BEGIN
						EXEC(@alterDBSQL)
					END
			END

		IF EXISTS ( SELECT percent_complete FROM sys.dm_database_encryption_keys WHERE db_name(database_ID) = @targetDB AND (Encryption_state = 2 or Encryption_state = 3) )
			BEGIN
				PRINT 'Database is Encrypted or being encrypted'
			END
		ELSE
			BEGIN
				PRINT 'Database is not Encrypted...yet'

				SET @alterDBSQL = '
					ALTER DATABASE ['+ @targetDB +'] SET ENCRYPTION ON;'
				IF( @dryRun = 1 )
					BEGIN
						PRINT '---- DryRun'
						PRINT @alterDBSQL
					END
				ELSE
					BEGIN
						EXEC(@alterDBSQL)
					END
			END
			------------------------------------------------------------------
			-- resume once the encryption is started
		IF EXISTS ( SELECT percent_complete FROM sys.dm_database_encryption_keys WHERE db_name(database_ID) = @targetDB AND (Encryption_state = 2 or Encryption_state = 3) )
			BEGIN
				PRINT 'Database is Encrypted or being encrypted'

			IF( (SELECT isNull(is_suspended,0) FROM sys.dm_hadr_database_replica_states where is_Local = 1 AND DB_NAME(database_ID) = @targetDB) = 0 )
				BEGIN
					PRINT '-- HADR is running'
				END
			ELSE
				BEGIN
					PRINT '-- HADR needs to be resumed'

					SET @alterDBSQL= '
						use master;alter database '+ @targetDB +' set HADR resume;'
					IF( @dryRun = 1 )
						BEGIN
							PRINT '---- DryRun'
							PRINT @alterDBSQL
						END
					ELSE
						BEGIN
							EXEC(@alterDBSQL)
						END
				END
			END
		ELSE
			BEGIN
				PRINT 'Database is not Encrypted...rerun'
			END
	END

SELECT DB_NAME(database_id) AS DatabaseName, encryption_state,
encryption_state_desc =
CASE encryption_state
         WHEN '0'  THEN  'No database encryption key present, no encryption'
         WHEN '1'  THEN  'Unencrypted'
         WHEN '2'  THEN  'Encryption in progress'
         WHEN '3'  THEN  'Encrypted'
         WHEN '4'  THEN  'Key change in progress'
         WHEN '5'  THEN  'Decryption in progress'
         WHEN '6'  THEN  'Protection change in progress (The certificate or asymmetric key that is encrypting the database encryption key is being changed.)'
         ELSE 'No Status'
         END,
percent_complete,encryptor_thumbprint, encryptor_type  FROM sys.dm_database_encryption_keys
