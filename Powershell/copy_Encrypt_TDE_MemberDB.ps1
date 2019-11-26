<#

Purpose : 
          Create Keys, Certficate and Enable TDE in MemberDB. 
          Create Keys, Certficate only in Standby

Create by  : Praveen T

Created on : 02/15/2017

#>

cls


# Run SQL based on the input
function RunSql ($ServerInstance, $Database, $Query)
{
    try
    {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $Query -Database $Database -OutputSqlErrors $true -AbortOnError -ErrorAction stop -Verbose -QueryTimeout 0 | Format-Table -HideTableHeaders|  Out-String
    }
    catch
    {
    throw $_.Exception.Message ;
    }
}

function RunSqlwithResultsHeader ($ServerInstance, $Database, $Query)
{
    try
    {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $Query -Database $Database -OutputSqlErrors $true -AbortOnError -ErrorAction stop -Verbose -QueryTimeout 0 | Format-Table -AutoSize -Wrap |  Out-String
    }
    catch
    {
    throw $_.Exception.Message ;
    }
}


function getDriveLetterByInstance($InstanceName)
{

 $AllInstanceList = @{
            'I1' = 'E';
            'I2' = 'F';
            'I3' = 'G';
            'I4' = 'H';
            'I5' = 'J';
            'I6' = 'K';
            'I7' = 'L';
            'I8' = 'M';
            'I9' = 'N';
            'I01' = 'E';
            'I02' = 'F';
            'I03' = 'G';
            'I04' = 'H';
            'I05' = 'J';
            'I06' = 'K';
            'I07' = 'L';
            'I08' = 'M';
            'I09' = 'N';
            'I10' = 'O';
            'I11' = 'P';
            'I12' = 'S';
            'I13' = 'U';
            'I14' = 'V';
            'I15' = 'W';
            'I16' = 'X';
        };

 return ($AllInstanceList.get_Item($InstanceName)) 

}

function BackupCertificate($SourceSQLInstance,$CertificateName,$CertSource,$KeySource,$SAPassword)
{
    
    $BackupCertFromSource_SQL = $null

    $BackupCertFromSource_SQL = "USE MASTER; BACKUP CERTIFICATE $CertificateName TO FILE = '$CertSource'  WITH PRIVATE KEY(FILE = '$KeySource', ENCRYPTION BY PASSWORD = '$SAPassword')"


    # Backup the certificate from Source Server
    runsql -ServerInstance $SourceSQLInstance -Database 'master' -Query $BackupCertFromSource_SQL
}


function CreateMasterKeyEncryption ($TargetSQLInstance,$SAPassword)
{
    # Create if master key encryption if not exists
    $MasterKeyEncrypt_SQL = "

	    -- Create Master KEY encryption
	    IF NOT EXISTS (SELECT * FROM SYS.SYMMETRIC_KEYS WHERE NAME LIKE '%DATABASEMASTERKEY%')
	    BEGIN
			    CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$SAPassword' ;
	    END
	    ELSE
	     PRINT 'Master Key exists already....';

 

    -- ENCRYPT THE MASTER KEY
         --OPEN MASTER KEY DECRYPTION BY PASSWORD = ''
         ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY;
         CLOSE MASTER KEY ;"

    # Create if master key encryption if not exists
    runsql -ServerInstance $TargetSQLInstance -Database 'master' -Query $MasterKeyEncrypt_SQL
}


 function CreateCertificateonMaster ($TargetSQLInstance, $CertificateName, $CertSource, $KeySource, $SAPassword)
 {

    # Create Certificate on Master DB
    $CertificateOnMasterDB_SQL = "

    USE [MASTER];

    IF NOT EXISTS (SELECT 'x' FROM MASTER.SYS.CERTIFICATES WHERE NAME = '$CertificateName')
	    BEGIN

		    -- CREATE CERIFICATE
		    CREATE CERTIFICATE $CertificateName
		    FROM FILE = '$CertSource'
		      WITH PRIVATE KEY (FILE = '$KeySource',
		    DECRYPTION BY PASSWORD = '$SAPassword');

	    END
	    ELSE
	    BEGIN
	     PRINT 'Cerificate $CertificateName Exists. Skipping Certificate Creation Process'; 
	    END

    "
     # Create Certificate on Master if not exists
    runsql -ServerInstance $TargetSQLInstance -Database 'master' -Query $CertificateOnMasterDB_SQL

}


function CreateEncryptionKeyonMemberDB ($TargetSQLInstance,$TargetDatabase,$CertificateName,$CertTarget,$KeyTarget,$SAPassword)
{
   $MemberDB_EncryptionKey_SQL = "

        USE $TargetDatabase;
	    IF NOT EXISTS( SELECT 'X' FROM SYS.DM_DATABASE_ENCRYPTION_KEYS WHERE DATABASE_ID = DB_ID('$TargetDatabase'))
	    BEGIN
	    CREATE DATABASE ENCRYPTION KEY WITH ALGORITHM = AES_256  ENCRYPTION BY SERVER CERTIFICATE $CertificateName;

	    USE MASTER; BACKUP CERTIFICATE $CertificateName 
	     TO FILE = '$CertTarget'
	    WITH PRIVATE KEY (FILE = '$KeyTarget',
	    ENCRYPTION BY PASSWORD = '$SAPassword');

	    END 
	    ELSE
	    BEGIN
	      Print 'Database encryption key is exists already' 
	    end      
    "

    # Creating Encryption Key on MemberDB 
    runsql -ServerInstance $TargetSQLInstance -Database $TargetDatabase -Query $MemberDB_EncryptionKey_SQL
}

function EncryptDB ($TargetSQLInstance,$TargetDatabase)
{
    $EncryptMemberDB_SQL = "

      USE $TargetDatabase;
    IF EXISTS (SELECT 'X' FROM SYS.DM_DATABASE_ENCRYPTION_KEYS WHERE DATABASE_ID = DB_ID('$TargetDatabase') AND ENCRYPTION_STATE in (0,1))
	    BEGIN
		    ALTER DATABASE $TargetDatabase SET ENCRYPTION ON;
		    Print 'Database Encryption is in Progress. Showing the Current Status '
	    END
	    else
	      Print 'Database Encryption is Enabled already'
    "

    # Encrypt MemberDB 
    runsql -ServerInstance $TargetSQLInstance -Database $TargetDatabase -Query $EncryptMemberDB_SQL
}

function CheckEncryptionStatus($TargetSQLInstance,$TargetDatabase)
{
$checkEncryptionStatus = "

        waitfor delay '00:00:10'

        IF EXISTS (SELECT 'X' FROM SYS.DM_DATABASE_ENCRYPTION_KEYS WHERE DATABASE_ID = DB_ID('$TargetDatabase'))
        BEGIN
            SELECT DB_NAME(DATABASE_ID) AS DATAABSENAME,CASE ENCRYPTION_STATE WHEN 0 THEN 'NO DATABASE ENCRYPTION KEY PRESENT, NO ENCRYPTION'

            WHEN 1 THEN 'UNENCRYPTED'

            WHEN 2 THEN 'ENCRYPTION IN PROGRESS'

            WHEN 3 THEN 'ENCRYPTED'

            WHEN 4 THEN 'KEY CHANGE IN PROGRESS'

            WHEN 5 THEN 'DECRYPTION IN PROGRESS'

            WHEN 6 THEN 'PROTECTION CHANGE IN PROGRESS (THE CERTIFICATE OR ASYMMETRIC KEY THAT IS ENCRYPTING THE DATABASE ENCRYPTION KEY IS BEING CHANGED)' 
            END AS ENCRYPTION_STATE , 
            PERCENT_COMPLETE FROM SYS.DM_DATABASE_ENCRYPTION_KEYS WHERE DATABASE_ID = DB_ID('$TargetDatabase')
        END
        ELSE
           SELECT '$TargetDatabase' AS DATAABSENAME, 'UNENCRYPTED' AS ENCRYPTION_STATE, 0 AS PERCENT_COMPLETE;


    "


    RunSqlwithResultsHeader -ServerInstance $TargetSQLInstance -Database $TargetDatabase -Query $checkEncryptionStatus

}

function SetEncryptionCertificate_Standby  (
      [parameter(Mandatory=$True)] $PrimarySQLInstance, 
      [parameter(Mandatory=$True)] $StandbySQLInstance,
      [parameter(Mandatory=$True)] $SAPassword,
                                   $CertificateName = "ETDB_CERT_$($database)"

    )
{

   
    if ($PrimarySQLInstance -eq $StandbySQLInstance)
    {
    throw "Primary [$PrimarySQLInstance] and Standby [$StandbySQLInstance] Instance can not be same "
    }


    write-host "Get the Standby Instance Name and validate the Instance & Database "
    $InstanceName =  runsql -ServerInstance $StandbySQLInstance -Database 'Master' -Query "SELECT @@servicename"


    write-host "Get the Standby SQL Server Instance Current Node Name"
    $NodeName=  runsql -ServerInstance $StandbySQLInstance -Database 'Master' -Query "exec Utility.dbo.whereAmI"


    $NodeName = $NodeName.Trim()

    $InstanceName = $InstanceName.Trim()

    $TargetDrive = getDriveLetterByInstance($InstanceName)

    $CertSourcePath = "\\$NodeName\$TargetDrive$\SQL\$InstanceName\Bak1\keys"
    $KeySourcePath = "\\$NodeName\$TargetDrive$\SQL\$InstanceName\Bak1\keys"

    try {
    if (-not(Test-path "filesystem::$CertSourcePath" -PathType Container))
    {
      Write-Host "Create Keys Folder under [\\$NodeName\$TargetDrive$\SQL\$InstanceName\Bak1\]" 
      New-Item "filesystem::$CertSourcePath" -ItemType Container
    }
    }
    catch
    {
      throw $_.Exception.Message ;
    }
    
  

    $srctmp = $PrimarySQLInstance.Split("\")[0]

    $currDateTime = get-date -Format s | Out-String
    $currDateTime = $currDateTime -replace ":","_"
    $currDateTime = $currDateTime.Trim()


    $tartmp = $StandbySQLInstance.Split("\")[0]
    
    $CertTarget = "$CertSourcePath\$($CertificateName)_$($tartmp)_$currDateTime"
    $KeyTarget = "$KeySourcePath\$($CertificateName)_PK_$($tartmp)_$currDateTime"

    $CertificateName_Standby = "$($CertificateName)_Standby"

    $CertStandby = "$CertSourcePath\$($CertificateName_Standby)_$($tartmp)_$currDateTime"
    $KeyStandby = "$KeySourcePath\$($CertificateName_Standby)_PK_$($tartmp)_$currDateTime"

    #$CertTarget
    #$KeyTarget 

    #$CertStandby
    #$KeyStandby

    Write-host "********************* Encryption Keys & Certificate Creation Process are Starting in Standby Server [$StandbySQLInstance] *************************"

    Write-Host "Backup the certificate from Primary Server [$PrimarySQLInstance] and keeping it in Standby Server Path [$CertSourcePath]" 
    BackupCertificate -SourceSQLInstance $PrimarySQLInstance  -CertificateName $CertificateName -CertSource $CertTarget  -KeySource $KeyTarget -SAPassword $SAPassword 
    

    Write-Host  "Create master key encryption if not exists"
    CreateMasterKeyEncryption -TargetSQLInstance $StandbySQLInstance  -SAPassword $SAPassword

    Write-Host  "Create Certificate from Backup on MasterDB if not exists"
    CreateCertificateonMaster -TargetSQLInstance $StandbySQLInstance -CertificateName $CertificateName -CertSource $CertTarget -KeySource $KeyTarget -SAPassword $SAPassword


    Write-Host "Backup the certificate from Standby Server [$StandbySQLInstance] and keeping it in Standby Server Path [$CertSourcePath]" 
    BackupCertificate -SourceSQLInstance $StandbySQLInstance  -CertificateName $CertificateName -CertSource $CertStandby  -KeySource $KeyStandby -SAPassword $SAPassword 

    
    Write-host "********************* Encryption Keys & Certificate Creation Process are Completed in Standby Server [$StandbySQLInstance] *************************"


 }

function EncryptMemberDB_Primary  (
                                   $SourceSQLInstance = $null, 
      [parameter(Mandatory=$True)] $TargetSQLInstance,
      [parameter(Mandatory=$True)] $TargetDatabase,
                                   $SAPassword = $null,
                                   $CertificateName = "ETDB_CERT",
                                   $GetEncryptionStatusOnly = 1,
                                   $StandbySQLInstance = $null

    )
{

    if ($GetEncryptionStatusOnly -eq 0)
    {
     
     if ($SourceSQLInstance -eq $null -or $SourceSQLInstance -eq "")
     {
       $SourceSQLInstance = Read-host -Verbose "Enter Value for Source SQL Instance"
     }

      if ($SAPassword -eq $null -or $SAPassword  -eq "")
     {
       $SAPassword = Read-host -Verbose "Enter Value for SA Password"
     }

    }

    write-host "Get the Target Instance Name and validate the Instance & Database "
    $InstanceName =  runsql -ServerInstance $TargetSQLInstance -Database $TargetDatabase -Query "SELECT @@servicename"


    write-host "Get the Target SQL Server Instance Current Node Name"
    $NodeName=  runsql -ServerInstance $TargetSQLInstance -Database $TargetDatabase -Query "exec Utility.dbo.whereAmI"


    $NodeName = $NodeName.Trim()

    $InstanceName = $InstanceName.Trim()

    $TargetDrive = getDriveLetterByInstance($InstanceName)

    $CertSourcePath = "\\$NodeName\$TargetDrive$\SQL\$InstanceName\Bak1\keys"
    $KeySourcePath = "\\$NodeName\$TargetDrive$\SQL\$InstanceName\Bak1\keys"

    try {
    if (-not(Test-path "filesystem::$CertSourcePath" -PathType Container))
    {
      Write-Host "Create Keys Folder under [\\$NodeName\$TargetDrive$\SQL\$InstanceName\Bak1\]" 
      New-Item "filesystem::$CertSourcePath" -ItemType Container
    }
    }
    catch
    {
      throw $_.Exception.Message ;
    }



    if ($GetEncryptionStatusOnly -eq 0)
    {

        if ($SourceSQLInstance -eq $TargetSQLInstance)
        {
        throw "Source [$SourceSQLInstance] and Target Instance [$TargetSQLInstance] can not be same "
        }

    $srctmp = $SourceSQLInstance.Split("\")[0]

    $currDateTime = get-date -Format s | Out-String
    $currDateTime = $currDateTime -replace ":","_"
    $currDateTime = $currDateTime.Trim()


    $CertSource = "$CertSourcePath\$($CertificateName)_$($srctmp)_$currDateTime"
    $KeySource = "$KeySourcePath\$($CertificateName)_PK_$($srctmp)_$currDateTime"

    $tartmp = $TargetSQLInstance.Split("\")[0]
    
    $CertTarget = "$CertSourcePath\$($CertificateName)_$($tartmp)_$currDateTime"
    $KeyTarget = "$KeySourcePath\$($CertificateName)_PK_$($tartmp)_$currDateTime"

    Write-host "********************* Encryption Process is Starting in Primary Server [$TargetSQLInstance] *************************"

    Write-Host "Backup the certificate from Source Server [$SourceSQLInstance] and keeping it in Target Path [$CertSourcePath]" 
    BackupCertificate -SourceSQLInstance $SourceSQLInstance  -CertificateName $CertificateName -CertSource $CertSource  -KeySource $KeySource -SAPassword $SAPassword 

    Write-Host  "Create master key encryption if not exists"
    CreateMasterKeyEncryption -TargetSQLInstance $TargetSQLInstance  -SAPassword $SAPassword

    Write-Host  "Create Certificate on Master if not exists"
    CreateCertificateonMaster -TargetSQLInstance $TargetSQLInstance -CertificateName $CertificateName -CertSource $CertSource -KeySource $KeySource -SAPassword $SAPassword

    Write-Host  "Creating Encryption Key on MemberDB [$TargetDatabase]"
    CreateEncryptionKeyonMemberDB  -TargetSQLInstance $TargetSQLInstance -TargetDatabase $TargetDatabase -CertificateName $CertificateName -CertTarget $CertTarget -KeyTarget $KeyTarget -SAPassword $SAPassword
 
    Write-Host "Start the Encryption Process on MemberDB [$TargetDatabase]"
    EncryptDB -TargetSQLInstance $TargetSQLInstance -TargetDatabase $TargetDatabase  

    Write-host "********************* Encryption Process is Completed in Primary Server [$TargetSQLInstance] *************************"

    }

    Write-Host "Current Encryption Status is .................."
    CheckEncryptionStatus -TargetSQLInstance $TargetSQLInstance -TargetDatabase $TargetDatabase

    if ($GetEncryptionStatusOnly -eq 0)
    {
      if ($StandbySQLInstance -ne $null -and $StandbySQLInstance -ne "")
      {

       if ($SourceSQLInstance -eq $StandbySQLInstance)
        {
        throw "Source [$SourceSQLInstance] and Standby Instance [$StandbySQLInstance] can not be same "
        }

       SetEncryptionCertificate_Standby -PrimarySQLInstance $TargetSQLInstance -StandbySQLInstance $StandbySQLInstance  -CertificateName $CertificateName -SAPassword $SAPassword -Verbose 
      }
      else
      {
       write-host "Standby Instance [$StandbySQLInstance] is not valid. Skipping Setting Encryption Kyes in Standby Instance"
      }
    }
}

function SetEncryptionCertificate_Primary_Standby  (
                                   $SourceSQLInstance = $null, 
      [parameter(Mandatory=$True)] $TargetSQLInstance,
      [parameter(Mandatory=$True)] $TargetDatabase,
                                   $SAPassword = $null,
                                   $CertificateName = "ETDB_CERT",
                                   $GetEncryptionStatusOnly = 1,
                                   $StandbySQLInstance = $null

    )
{

    if ($GetEncryptionStatusOnly -eq 0)
    {
     
     if ($SourceSQLInstance -eq $null -or $SourceSQLInstance -eq "")
     {
       $SourceSQLInstance = Read-host -Verbose "Enter Value for Source SQL Instance"
     }

      if ($SAPassword -eq $null -or $SAPassword  -eq "")
     {
       $SAPassword = Read-host -Verbose "Enter Value for SA Password"
     }

    }

    write-host "Get the Target Instance Name and validate the Instance & Database "
    $InstanceName =  runsql -ServerInstance $TargetSQLInstance -Database $TargetDatabase -Query "SELECT @@servicename"


    write-host "Get the Target SQL Server Instance Current Node Name"
    $NodeName=  runsql -ServerInstance $TargetSQLInstance -Database $TargetDatabase -Query "exec Utility.dbo.whereAmI"


    $NodeName = $NodeName.Trim()

    $InstanceName = $InstanceName.Trim()

    $TargetDrive = getDriveLetterByInstance($InstanceName)

    $CertSourcePath = "\\$NodeName\$TargetDrive$\SQL\$InstanceName\Bak1\keys"
    $KeySourcePath = "\\$NodeName\$TargetDrive$\SQL\$InstanceName\Bak1\keys"

    try {
    if (-not(Test-path "filesystem::$CertSourcePath" -PathType Container))
    {
      Write-Host "Create Keys Folder under [\\$NodeName\$TargetDrive$\SQL\$InstanceName\Bak1\]" 
      New-Item "filesystem::$CertSourcePath" -ItemType Container
    }
    }
    catch
    {
      throw $_.Exception.Message ;
    }



    if ($GetEncryptionStatusOnly -eq 0)
    {

        if ($SourceSQLInstance -eq $TargetSQLInstance)
        {
        throw "Source [$SourceSQLInstance] and Target Instance [$TargetSQLInstance] can not be same "
        }

    $srctmp = $SourceSQLInstance.Split("\")[0]

    $currDateTime = get-date -Format s | Out-String
    $currDateTime = $currDateTime -replace ":","_"
    $currDateTime = $currDateTime.Trim()


    $CertSource = "$CertSourcePath\$($CertificateName)_$($srctmp)_$currDateTime"
    $KeySource = "$KeySourcePath\$($CertificateName)_PK_$($srctmp)_$currDateTime"

    $tartmp = $TargetSQLInstance.Split("\")[0]
    
    $CertTarget = "$CertSourcePath\$($CertificateName)_$($tartmp)_$currDateTime"
    $KeyTarget = "$KeySourcePath\$($CertificateName)_PK_$($tartmp)_$currDateTime"

    Write-host "********************* Certificates copy process is Starting in Primary Server [$TargetSQLInstance] *************************"

    Write-Host "Backup the certificate from Source Server [$SourceSQLInstance] and keeping it in Target Path [$CertSourcePath]" 
    BackupCertificate -SourceSQLInstance $SourceSQLInstance  -CertificateName $CertificateName -CertSource $CertSource  -KeySource $KeySource -SAPassword $SAPassword 

    Write-Host  "Create master key encryption if not exists"
    CreateMasterKeyEncryption -TargetSQLInstance $TargetSQLInstance  -SAPassword $SAPassword

    Write-Host  "Create Certificate on Master if not exists"
    CreateCertificateonMaster -TargetSQLInstance $TargetSQLInstance -CertificateName $CertificateName -CertSource $CertSource -KeySource $KeySource -SAPassword $SAPassword

    Write-Host  "Creating Encryption Key on MemberDB [$TargetDatabase]"
    CreateEncryptionKeyonMemberDB  -TargetSQLInstance $TargetSQLInstance -TargetDatabase $TargetDatabase -CertificateName $CertificateName -CertTarget $CertTarget -KeyTarget $KeyTarget -SAPassword $SAPassword
 
    #Write-Host "Start the Encryption Process on MemberDB [$TargetDatabase]"
    #EncryptDB -TargetSQLInstance $TargetSQLInstance -TargetDatabase $TargetDatabase  

    #Write-host "********************* Encryption Process is Completed in Primary Server [$TargetSQLInstance] *************************"

    }

    Write-Host "Current Encryption Status is .................."
    CheckEncryptionStatus -TargetSQLInstance $TargetSQLInstance -TargetDatabase $TargetDatabase

    if ($GetEncryptionStatusOnly -eq 0)
    {
      if ($StandbySQLInstance -ne $null -and $StandbySQLInstance -ne "")
      {

       if ($SourceSQLInstance -eq $StandbySQLInstance)
        {
        throw "Source [$SourceSQLInstance] and Standby Instance [$StandbySQLInstance] can not be same "
        }

       SetEncryptionCertificate_Standby -PrimarySQLInstance $TargetSQLInstance -StandbySQLInstance $StandbySQLInstance  -CertificateName $CertificateName -SAPassword $SAPassword -Verbose 
      }
      else
      {
       write-host "Standby Instance [$StandbySQLInstance] is not valid. Skipping Setting Encryption Kyes in Standby Instance"
      }
    }
}


<#  USAGE : Get the current Encryption status. 

EncryptMemberDB_Primary -verbose -GetEncryptionStatusOnly  1 -TargetSQLInstance '<TargetSQLInstance>' -TargetDatabase '<TargetDatabase>' 

# Default certificate Name is ETDB_CERT. If you need to change, Add the Paramenter -CertificateName '<CertificateName>'

#>


<#  USAGE : Encrypt the MemberDB (without Standby). 

EncryptMemberDB_Primary -verbose -GetEncryptionStatusOnly  0 -SourceSQLInstance '<SourceSQL>' -TargetSQLInstance '<TargetSQL>' -TargetDatabase '<TargetDatabase>' -SAPassword '<SAPassword>'

# Default certificate Name is ETDB_CERT. If you need to change, Add the Paramenter -CertificateName '<CertificateName>'

#>


<#  USAGE : Encrypt the MemberDB (with Standby). 

EncryptMemberDB_Primary -verbose -GetEncryptionStatusOnly  0 -SourceSQLInstance '<SourceSQL>' -TargetSQLInstance '<TargetSQL>' -TargetDatabase '<TargetDatabase>' -SAPassword '<SAPassword>' -StandbySQLInstance '<StandbySQLInstance>'

# Default certificate Name is ETDB_CERT. If you need to change, Add the Paramenter -CertificateName '<CertificateName>'

#>

<#  USAGE : Set Encryption Keys & Certificate only on the Primary and Standby Instance. 

SetEncryptionCertificate_Primary_Standby -verbose -GetEncryptionStatusOnly  0 -SourceSQLInstance '<SourceSQL>' -TargetSQLInstance '<TargetSQL>' -TargetDatabase '<TargetDatabase>' -SAPassword '<SAPassword>' -StandbySQLInstance '<StandbySQLInstance>'

# Default certificate Name is ETDB_CERT. If you need to change, Add the Paramenter -CertificateName '<CertificateName>'

#>


<#  USAGE : Set Encryption Keys & Certificate only on the Standby Instance. 

SetEncryptionCertificate_Standby -verbose -PrimarySQLInstance <PrimarySQLInstance> -StandbySQLInstance <StandbySQLInstance>   -SAPassword '<SAPassword>' -Verbose 

# Default certificate Name is ETDB_CERT. If you need to change, Add the Paramenter -CertificateName '<CertificateName>'

#>


#SetEncryptionCertificate_Standby -PrimarySQLInstance 'ATL1S11C010I04\I04' -StandbySQLInstance 'ATL1S11CB010I04\I04'   -SAPassword '#e=2.302585...!' -Verbose 


#.\createNewStandby.ps1 -targetDB 'ExactTarget11106' -oldPROD 'ATL1S11C010I04\I04' -newStandBY 'ATL1S11CB010I04\I04' -SkipCopy 1 -dryRun 0


#SetEncryptionCertificate_Standby -PrimarySQLInstance 'ATL1S11C010I04\I04' -StandbySQLInstance 'ATL1S11CB010I04\I04'   -SAPassword '' -Verbose 

