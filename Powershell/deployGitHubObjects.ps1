 <#
	.\deployGitHubObjects.ps1 -targetDB "SnapBackupDB" -sourceRep "C:\SQL\SnapBackupDB-master" -targetHost "localhost\I1" -repoFolder "Auto"
    .\deployGitHubObjects.ps1 -targetDB "SQLmonitor" -targetHost "localhost\I1" -repoRoot "C:\Users\hbrotherton\myGit\Releases\SQLMonitor"  -repoFolder "StoredProcedure"
QA - no phases
    .\deployGitHubObjects.ps1 -targetDB "UTILITY" -phase "STAGING" -repoFolder "StoredProcedure" -dryRun 0 -force 
    .\deployGitHubObjects.ps1 -filter "dbauto_UtilityDB_1.14.0.ZIP" -phase "STAGING" -dryRun 0 -force
 
    .\deployGitHubObjects.ps1 -targetDB "WORKTABLEDB" -phase "STAGING" -dryRun 0 -force 
    .\deployGitHubObjects.ps1 -targetDB "UTILITY" -phase "STAGING" -dryRun 0 -force 
    .\deployGitHubObjects.ps1 -filter "dbauto_UtilityDB_1.14.0.ZIP" -phase "STAGING" -dryRun 0 -force


PROD PHASE 0 - Templates
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "templates"

PROD PHASE 0 - Stack 8
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "stack8"

PROD PHASE 0 - Non Stack DB
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "ActiveBatch"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "Admin"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "Build"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "commVault"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "Confio"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "DBA01"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "DBA01MAchines"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "DBrestores"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "DataWharehouse"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "MediaServers"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "Standby"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "StandbyMgr"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "Templates"
    .\deployGitHubObjects.ps1  -targetDB "utility" -phase "phase0" -cmsGroup "Unused"

PROD PHASE 0 
    .\deployGitHubObjects.ps1 -targetDB "SystemDB" -phase "phase0" -cmsGroup "Unused"

PROD PHASE 1
    .\deployGitHubObjects.ps1 -targetDB "utility" -phase "phase1" -cmsGroup "Stack2"
    .\deployGitHubObjects.ps1 -targetDB "utility" -phase "phase1" -cmsGroup "Stack4"
    .\deployGitHubObjects.ps1 -targetDB "utility" -phase "phase1" -cmsGroup "Stack10"
## shared scripts
    .\deployGitHubObjects.ps1 -targetDB "SystemDB" -phase "phase1" -cmsGroup "Stack2"
    .\deployGitHubObjects.ps1 -targetDB "SystemDB" -phase "phase1" -cmsGroup "Stack4"
    .\deployGitHubObjects.ps1 -targetDB "SystemDB" -phase "phase1" -cmsGroup "Stack10"

PROD PHASE 2
    .\deployGitHubObjects.ps1 -targetDB "utility" -phase "phase2" -cmsGroup "Stack1"
    .\deployGitHubObjects.ps1 -targetDB "utility" -phase "phase2" -cmsGroup "Stack5"
    .\deployGitHubObjects.ps1 -targetDB "utility" -phase "phase2" -cmsGroup "Stack6"
    .\deployGitHubObjects.ps1 -targetDB "utility" -phase "phase2" -cmsGroup "Stack7"
## shared scripts
    .\deployGitHubObjects.ps1 -targetDB "SystemDB" -phase "phase2" -cmsGroup "Stack1"
    .\deployGitHubObjects.ps1 -targetDB "SystemDB" -phase "phase2" -cmsGroup "Stack5"
    .\deployGitHubObjects.ps1 -targetDB "SystemDB" -phase "phase2" -cmsGroup "Stack6"
    .\deployGitHubObjects.ps1 -targetDB "SystemDB" -phase "phase2" -cmsGroup "Stack7"
#>

# $error.clear()

PARAM(
		[string] $targetDB="",
		[string] $targetHost="", #"localhost\I1",
        [string] $phase = "",  # staging(QA) "phase0","phase1","phase2"
        [string] $cmsGroup ="NA", 
		[INT]    $deployID = 0,
        [string] $repoRoot= ( Split-Path -Path $MyInvocation.MyCommand.Definition -Parent )+ "\Releases\"+ $targetDB,
        [string] $repoVersion = "",
		[string] $repoFolder= "Auto",
        [string] $currentDomain = "."+ $env:userDNSdomain -replace('ET','QA') -replace('CT.',''),
       	[string] $filter = '*.sql',
		[int]    $dryRun = 1,
		[switch] $force,
        [switch] $verbose
	)

$ErrorActionPreference="Continue";	
#$VerbosePreference = "Continue";
IF($verbose) { $VerbosePreference = "continue" }

 $dotnetversion = [Environment]::Version            
IF(!($dotnetversion.Major -ge 4 -and $dotnetversion.Build -ge 30319)) 
{            
    write-error "You are not having Microsoft DotNet Framework 4.5 installed. Script exiting"            
    exit(1)            
}            

# Import dotnet libraries            
[Void][Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')            

function checkStatus-online ( [string] $f_targetHost, [string] $f_targetDB, [string] $f_phase, [string] $f_cmsGroup, [int] $f_dryRun )
{
    $selectSQL = " select DB.name as dbName, DB.state_desc as dbState, IsNULL((Select SC.confValue
																                from [Utility].[dbo].[systemconfig] as SC
																                where  confKey = 'instance.ServerType'),'Not configured') as serverType
                    FROM  sys.databases as DB
                    where name = '"+ $f_targetDB +"'"

    $selectSQL = " select @@servername as serverName, '"+ $f_targetDB +"' , 
	            IsNull((SELECT name FROM  sys.databases as DB where name = '"+ $f_targetDB +"'), 'MISSING') as dbState,
	            IsNULL((SELECT SC.confValue from [Utility].[dbo].[systemconfig] as SC where  confKey = 'instance.ServerType'),'Not configured') as serverType "


    $selectSQL = "  IF EXISTS( SELECT name from sys.databases WHERE NAME = '"+ $f_targetDB +"' )
	                    BEGIN
		                    select @@servername as serverName, '"+ $f_targetDB +"' as dbName, 
	                            IsNull((SELECT name FROM  sys.databases as DB where name = '"+ $f_targetDB +"'), 'MISSING') as dbState,
	                            IsNULL((SELECT SC.confValue from [Utility].[dbo].[systemconfig] as SC where  confKey = 'instance.ServerType'),'Not configured') as serverType
	                    END;
                    ELSE
	                    BEGIN
		                    select @@servername as serverName, '"+ $f_targetDB +"' as dbName , 'MISSING' as dbState, 'MISSING' as serverType
	                    END;"

    WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $f_targetHost -Database MASTER  -ErrorAction SilentlyContinue -Query $selectSQL | select serverName, dbName, dbState, serverType "
    TRY
        {
	        Invoke-Sqlcmd -ServerInstance $f_targetHost -Database MASTER  -ErrorAction SilentlyContinue -Query $selectSQL | select serverName, dbName, dbState, serverType

            ## CHECK FOR PREVIOUS ERROR AND REMOVE IT!
            $deleteSQL = "IF EXISTS( SELECT * FROM [deploy].[failedConnection] WHERE deployID = $currentDeployID and failedConnectionDatabase = '"+ $f_targetDB +"' AND failedConnectionInstance = '"+ $f_targetHost +"' ) 
                                    BEGIN
                                        DELETE FROM [deploy].[failedConnection] WHERE deployID = $currentDeployID and failedConnectionDatabase = '"+ $f_targetDB +"' AND failedConnectionInstance = '"+ $f_targetHost +"'
                                     END;"
            
            WRITE-VERBOSE "invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query `"$deleteSQL`" "
            invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $deleteSQL
        }
    CATCH
        {
            WRITE-HOST "[ALERT] Failed to connect to $f_targetHost and query databases."
            $ExceptionMessage = "[FAILED - CONNECTION] .\deployGitHubObjects.ps1 -targetDB $f_targetDB -targetHost $f_targetHost -phase $f_phase -cmsGroup $f_cmsGroup -deployID $currentDeployID -dryRun $f_dryRun -force -verbose"

            $caseRecord = checkStatus-record $deployServer $deployDB "failedConnection" $targetDB $currentHost $currentDeployID $dryRun
                                        
            IF( $caseRecord -eq 0 ) # Not recorded in deploy tables
                {
                    WRITE-VERBOSE "Recording new alert"
                    [void]$ResultsTable.Rows.Add("3", $currentHost, $targetDB, $ExceptionMessage)
                                                
                    ## record in DBautomation database
                    $insertSQL = "IF NOT EXISTS( SELECT * FROM [deploy].[failedConnection] WHERE deployID = $currentDeployID and failedConnectionDatabase = '"+ $f_targetDB +"' AND failedConnectionInstance = '"+ $f_targetHost +"' ) 
                                    BEGIN
                                        INSERT INTO [deploy].[failedConnection] ( [deployID], [failedConnectionDatabase], [failedConnectionInstance], [failedConnectionCommand], [failedConnectionCase] )
                                                VALUES   ( "+ $currentDeployID +", '"+ $targetDB +"', '"+ $currentHost +"', '"+ $ExceptionMessage +"', '' )
                                     END;"

                }
            ELSE # Already recorded - down grading to a warning 
                {
                    WRITE-VERBOSE "Recorded Case = $caseRecord "
                    WRITE-HOST `t"Already recorded $caseRecord and has a work ticket - downgrading to WARNING"
                                        
                    ## record in DBautomation database
                    $insertSQL = "IF NOT EXISTS( SELECT * FROM [deploy].[failedConnection] WHERE deployID = $currentDeployID and failedConnectionDatabase = '"+ $f_targetDB +"' AND failedConnectionInstance = '"+ $f_targetHost +"' ) 
                                    BEGIN
                                        INSERT INTO [deploy].[failedConnection] ( [deployID], [failedConnectionDatabase], [failedConnectionInstance], [failedConnectionCommand], [failedConnectionCase] )
                                                VALUES   ( "+ $currentDeployID +", '"+ $targetDB +"', '"+ $currentHost +"', '"+ $ExceptionMessage +"', '"+ $caseRecord +"' )
                                     END;"

                    [void]$ResultsTable.Rows.Add("2", $currentHost, $targetDB, $ExceptionMessage)
                }
                                        
            IF( ($dryRun -eq 0) -AND ($currentDeployID -ne 0) )
                {
                    WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query `"$insertSQL`" "
                    invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $insertSQL
                }
        }    
}

function checkStatus-Ping ( [string] $f_targetHost, [string] $f_domain )
{
    $f_targetInstance = $f_targetHost.substring(0,$f_targetHost.IndexOf('\'))
    #$f_targetServer = $f_targetInstance + $f_domain
    WRITE-VERBOSE "test-Connection -ComputerName $f_targetInstance -Count 2 -Quiet"
    test-Connection -ComputerName $f_targetInstance -Count 2 -Quiet  
     
}

function checkStatus-record ( [string] $f_deployServer, [string] $f_deployDB, [string] $f_deployTable, [string] $f_targetDB, [string] $f_currentHost, [int] $f_currentDeployID, [int] $f_dryRun ) #not used yet.
{
    $IsRecorded = 0
    $selectSQL = "SELECT COUNT(*) as IsRecorded FROM [deploy].[$f_deployTable] WHERE "+ $f_deployTable +"Database = '"+ $f_targetDB +"' and "+ $f_deployTable +"Instance = '"+ $f_currentHost +"' AND isNULL("+ $f_deployTable +"Case,'') like 'W%' AND IsNULL("+ $f_deployTable +"CaseSTatus,'') <> 'CLOSED'"
    WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $selectSQL "
    IF( ($f_dryRun -eq 0) -AND ($f_currentDeployID -ne 0) )
        {
            WRITE-VERBOSE "invoke-sqlcmd -ServerInstance $f_deployServer -Database $f_deployDB -Query `"$selectSQL`" "
            $returnValue = invoke-sqlcmd -ServerInstance $f_deployServer -Database $f_deployDB -Query $selectSQL | SELECT IsRecorded
            $Isrecorded = $returnValue.IsRecorded
            WRITE-VERBOSE "Isrecorded = $Isrecorded "
        }

    IF( $IsRecorded -eq 0 ) # Not recorded in deploy tables
        {
            WRITE-VERBOSE "Not recorded return ZERO"
            $functionReturn = $isRecorded
        }
    ELSE # Already recorded - down grading to a warning 
        {
            $recordedCase = ""
            $selectSQL = "SELECT top 1 "+ $f_deployTable +"Case as caseNumber FROM [deploy].[$f_deployTable] WHERE "+ $f_deployTable +"Database = '"+ $f_targetDB +"' and "+ $f_deployTable +"Instance = '"+ $f_currentHost +"' AND isNULL("+ $f_deployTable +"Case,'') like 'W%' AND IsNULL("+ $f_deployTable +"CaseSTatus,'') <> 'CLOSED' ORDER BY deployID DESC"
            WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $selectSQL "
            $returnValue = invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $selectSQL | SELECT caseNumber
            $recordedCase = $returnValue.caseNumber
            WRITE-VERBOSE "Recorded Case = $recordedCase "
            $functionReturn = $recordedCase
        }

    RETURN $functionReturn
}

function sendemail-SLACK ([string] $f_deployServer, [string] $f_folder, [string] $f_repoVersion, [string] $f_phase, [string] $f_cmsGroup, [string] $f_status, [int] $f_deployID, [int] $f_dryRun )
{
    $sendBody = " SELECT * FROM [deploy].[vw_deployResults] WHERE deployID = $f_deployID ORDER BY deployID desc,  DeployStatus DESC "
    $sendSubject = "FINISHED: $f_folder STATUS: $f_status VERSION: $f_repoVersion PHASE: $f_phase CMS: $f_cmsGroup "
    #$recipient = "h7e9j7p2s8n2j1m9@sf-mc.slack.com" #mc-db-automation
    $recipient = "z7q6d6j6s8v8z1c1@sf-mc.slack.com" #mc-db-auto-mations
    $sendSQL = "EXEC UTILITY.DBO.send_mail @toAddress = `"$recipient`", @emailSubject = `"$sendSubject`", @emailBody = `"$sendBody`""

    #$sendHost = 'XTINP1DBA01\DBadmin'
    
    $sendDB = 'UTILITY'

    TRY
        {
            WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $f_deployServer -Database $sendDB -DisableVariables -ErrorAction Stop -Query $sendSQL "
	        Invoke-Sqlcmd -ServerInstance $f_deployServer -Database $sendDB -DisableVariables -ErrorAction Stop -Query "$sendSQL"

            $sendBody = "FINISHED: $f_folder STATUS: $f_status VERSION: $f_repoVersion PHASE: $f_phase CMS: $f_cmsGroup "
            $sendSubject = "FINISHED: $f_folder STATUS: $f_status VERSION: $f_repoVersion PHASE: $f_phase CMS: $f_cmsGroup "
            <#$recipient = "hbrotherton@salesforce.com"
            $sendSQL = "EXEC UTILITY.DBO.send_mail @toAddress = `"$recipient`", @emailSubject = `"$sendSubject`", @emailBody = `"$sendBody`""
            Invoke-Sqlcmd -ServerInstance $f_deployServer -Database $sendDB -DisableVariables -ErrorAction Stop -Query "$sendSQL"#>
        }
    CATCH
        {            
            WRITE-HOST `t"[ALERT] !!! Email failed to send !!! "
        }

}

Function CopyFiles-Somewhere ( [string] $f_filter, [string] $f_targetHost, [string] $f_sourceHost, [int] $f_replace )#, [string] $f_targetDB, [string] $f_folder, [string] $f_repoVersion , [int] $f_dryRun )
{

    #WRITE-HOST `t"Source Location: $f_targetDB\$f_folder"
    #WRITE-HOST `t"Files to process: $total"
    #WRITE-HOST `t"[WARNING] Nothing to Process"
    #WRITE-HOST " "

    If( $f_replace -eq 0 )
        {
            WRITE-VERBOSE "Preserving files - not overwriteing"
            $changeDate = (get-date).ToString('yyyyMMdd-hmmss')
            Get-ChildItem -Path $f_sourceHost -Filter $f_filter -Recurse | ForEach-Object {

                $fileName = Join-Path -Path $f_targetHost -ChildPath $_.name
                WRITE-VERBOSE $fileName
                while(Test-Path -Path $fileName)
                {
                   WRITE-VERBOSE "File EXISTS - Renaming with date/Time stamp"
                   $next_fileName = Join-Path $f_targetHost ($_.BaseName + "_$changeDate" + $_.Extension) 
                   WRITE-VERBOSE $next_FileNAme 
                   MOVE-Item -PATH $fileName -Destination $next_FileNAme    
                }

                $_ | COPY-Item -Destination $fileName
            }
        }
    ELSE
        {
            WRITE-VERBOSE "NOT preserving files - overwriting replacing - no in place versioning - rely upon github"

        }

    #TEST for file copy?
    #IF()
    #$WarningMessage = "[WARNING] Nothing to Process in: $f_sqlSourcePath"
    #[void]$ResultsTable.Rows.Add("2", $WarningMessage)
    #[void]$ResultsTable.Rows.Add("2", $f_targetHost, $f_targetDB, $WarningMessage)


}

function process-Zipfile ( [string] $FileName, [string] $f_targetHost, [string] $f_domain, [string] $f_targetDB , [string] $f_folder, [string] $f_cmsGroup , [int] $f_dryRun )
{
    $databaseFolder = $f_targetDB +"\"+ $f_folder +"*"

    $ObjArray = @() 
    $RawFiles = [IO.Compression.ZipFile]::OpenRead($FileName).Entries            
    #$RawFiles = [IO.Compression.ZipFile]::OpenRead($zipFile).Entries.contains("StoredProcedure")
    #$targetRawFiles = $rawFiles.FullName.contains("SQLmonitor\StoredProcedure\") 
    #$rawFiles | Format-Table -AutoSize
    #$FileName
    ForEach( $RawFile in $RawFiles )
    { 
        IF($rawFile.FullName -like "$databaseFolder" )
            { 
                $total++ #; WRITE-HOST "HERE" 
                $object = New-Object -TypeName PSObject            
                $Object | Add-Member -MemberType NoteProperty -Name FileName -Value $RawFile.Name         
                $Object | Add-Member -MemberType NoteProperty -Name FullPath -Value $RawFile.FullName            
                #$Object | Add-Member -MemberType NoteProperty -Name CompressedLengthInKB -Value ($RawFile.CompressedLength/1KB).Tostring("00")            
                #$Object | Add-Member -MemberType NoteProperty -Name UnCompressedLengthInKB -Value ($RawFile.Length/1KB).Tostring("00")            
                #$Object | Add-Member -MemberType NoteProperty -Name FileExtn -Value ([System.IO.Path]::GetExtension($RawFile.FullName))            
                $Object | Add-Member -MemberType NoteProperty -Name ZipFileName -Value $zipfile     
                #$object | Add-Member -MemberType NoteProperty -Name scriptContent -Value        
                $ObjArray += $Object  
            }               
    }


    IF($total -eq 0 -AND ($f_dryRun -eq 1 ) )
        {
            WRITE-HOST `t"Source Location: $f_targetDB\$f_folder"
            WRITE-HOST `t"Files to process: $total"
            WRITE-HOST `t"[WARNING] Nothing to Process"
            WRITE-HOST " "
            $WarningMessage = "[WARNING] Nothing to Process in: $f_sqlSourcePath"
            #[void]$ResultsTable.Rows.Add("2", $WarningMessage)
            [void]$ResultsTable.Rows.Add("2", $f_targetHost, $f_targetDB, $WarningMessage)
        }
    ELSE
        {
            IF($total -ne 0 -or $verbose )
            {
                WRITE-HOST `t"Source Location: $f_targetDB\$f_folder"
                WRITE-HOST `t"Files to process: $total"
                #WRITE-HOST " "
            }

            IF( $force )
                {
                    IF($total -ne 0 -AND ($f_dryRun -eq 0 ) )
                        {
                            WRITE-HOST `t`t"Only making one pass"
                            $failureCounter = $total-1
                        }
                }
            ELSE
                {
                    #WRITE-HOST "Making multiple passes"
                    $failureCounter = 0
                }
            $process = "Started"
            WHILE( $process -ne "Succesful" -AND $failureCounter -lt $total ) # AND attempts less than file count
            {
                $process = "Started"
                #WRITE-HOST "[$process] Attempt "
                #$count++

                foreach($object in $objArray) 
                {            
                    $currentFile = $object.FileName
                    IF($f_dryRun -eq 1  ){ WRITE-HOST `t`t"File: $currentFile" }

                    #$fullPath = $object.ZipFileName +"\"+ $object.FullPath
                    #$fullPath = $object.FullPath
                    #WRITE-HOST "Full Path: $fullPath "

                    $zip = [IO.Compression.ZipFile]::OpenRead($FileName)
                    $file = $zip.Entries | where-object { $_.Name -eq $currentFile }
                    #WRITE-HOST "FILE: $file "

                    $stream = $file.Open()
                    $reader = New-Object IO.StreamReader($stream)
                    $text = $reader.ReadToEnd()
                    $text = $text -replace('\efeff', '')
                    #$text

                    IF($f_dryRun -eq 0)
                        {
                            TRY
                                {
                                    WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB -DisableVariables -ErrorAction Stop -Query $text "
	                                Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB -DisableVariables -ErrorAction Stop -Query "$text" 
                                    IF($process -ne "FAILED"){ $Process = "Succesful" }
                                }
                            CATCH
                                {
                                    $displayCounter = $failureCounter + 1
                                    WRITE-HOST `t"[ALERT] !!! Something broke !!! $currentFile Attempt $displayCounter of $total  !!! Something broke !!! "
                                    $process = "FAILED"
                                }
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB -DisableVariables -ErrorAction Stop -Query $text "
                            IF($process -ne "FAILED"){ $Process = "Succesful" }
                        }

                    $reader.Close()
                    $stream.Close()        
                 
                }   #forEach

                #$ObjArray | Format-Table -AutoSize 
                  
                WRITE-HOST " "
                $failureCounter ++
            } #end WHILE

            If( $process -eq "FAILED" )
                {
                    WRITE-HOST "[ALERT] Failure $failureCounter Total $total"
                    IF($failureCounter -eq $total ) { Write-Host($error) }
                    
                    $ExceptionMessage = "[FAILED -SQLCMD] Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB -ErrorAction Stop -InputFile $f_sqlSourcePath\$currentFile "
                    [void]$ResultsTable.Rows.Add("3", $f_targetHost, $f_targetDB, $ExceptionMessage)
                }
            ELSEIF( $f_dryRun -eq 0 -AND $total -ne 0)
                {
                    WRITE-HOST "[OK] Process was Successful "
                    $SuccessfulMessage = "[Success] Processed: $f_sqlSourcePath"
                    [void]$ResultsTable.Rows.Add("1", $f_targetHost, $f_targetDB, $SuccessfulMessage)
                    #Capture Relase info in systemConfig.

                    WRITE-HOST "[] Recording Value"
                    $execSQL = "EXECUTE [dbo].[SetConfig] 'Release."+ $f_targetDB +"', '"+ $f_repoVersion +"'"

                    WRITE-VERBOSE `t"Invoke-Sqlcmd -ServerInstance $f_targetHost -Database UTILITY -DisableVariables -ErrorAction Stop -Query $execSQL"
                    Invoke-Sqlcmd -ServerInstance $f_targetHost -Database UTILITY  -ErrorAction Stop -Query $execSQL
                }
            $total = 0 
        }
}

function validate-deploy ([string] $f_targetHost, [string] $f_domain, [string] $f_targetDB , [string] $f_targetObject )
{
            $selectSQL = "USE " + $f_targetDB +";
			                SELECT @ServerChecksum = ISNULL(CHECKSUM(OBJECT_DEFINITION(object_id)), 1) FROM ' + QUOTENAME(@DBName)
                              + '.sys.procedures p JOIN ' + QUOTENAME(@DBName)
                              + '.sys.schemas s ON p.schema_id = s.schema_id  WHERE p.name = ' + QUOTENAME(@ObjectName, '''')
                              + ' AND s.name = ' + QUOTENAME(@SchemaName, '''') + ';';
                           EXEC sp_executesql @sql, N'@ServerChecksum int out', @ServerChecksum OUT;"

            $execSQL = "EXECUTE [dbo].[setDatabaseConfig] @databaseName = '"+ $f_targetDB +"' ,@key = 'Database.Repo' ,@val = '1.13.0'"

}

function process-folder ( [string] $f_sqlSourcePath, [string] $f_targetHost, [string] $f_domain, [string] $f_targetDB, [string] $f_folder, [string] $f_cmsGroup , [int] $f_dryRun)
{
    $f_sqlSourcePath = $f_sqlSourcePath + $f_folder
    IF(test-path -path $f_sqlSourcePath)
        {
            get-childitem -recurse -path $f_sqlSourcePath -filter $filter | % {
                $file = $_
                $total ++
                # etc ...
                }
        }
    ELSE
        {
           $total = 0
        }

    IF($total -eq 0 -AND ($f_dryRun -eq 1 ) )
        {
            WRITE-HOST `t"Source Location: $f_sqlSourcePath"
            WRITE-HOST `t"Files to process: $total"
            WRITE-HOST `t"[WARNING] Nothing to Process"
            WRITE-HOST " "
            $WarningMessage = "[WARNING] Nothing to Process in: $f_sqlSourcePath "
            [void]$ResultsTable.Rows.Add("2", $f_targetHost, $f_targetDB, $WarningMessage)
        }
    ELSE
        {
            IF($total -ne 0 )
            {
                WRITE-HOST `t"Source Location: $f_sqlSourcePath"
                WRITE-HOST `t"Files to process: $total"
                #WRITE-HOST " "
            }
           # $error = ""
            IF( $force )
                {
                    IF($total -ne 0 -AND ($f_dryRun -eq 0 ) )
                        {
                            WRITE-HOST `t`t"Only making one pass"
                            $failureCounter = $total-1
                        }
                }
            ELSE
                {
                    #WRITE-HOST "Making multiple passes"
                    $failureCounter = 0
                }

            $process = "Started"
            $scriptFailure = 0
            WHILE( $process -ne "Succesful" -AND $failureCounter -lt $total ) # AND attempts less than file count
            {
                $process = "Started"
                #WRITE-HOST "[$process] Attempt "
                IF($scriptFailure -EQ 1)
                    {
                        WRITE-HOST "[ALERT] LAST CHANCE "
                        $failureCounter = $total-1
                    }
                ELSE
                    {
                        $scriptFailure = 0
                    }
                get-childitem -recurse -path $f_sqlSourcePath -filter $filter | % {
                    $file = $_
	                $currentFile = $file.name
                    IF($f_dryRun -eq 1 -OR $Verbose){ WRITE-HOST `t`t"File: $currentFile" }
	                #$outputFile = $_.BaseName+'.txt'
	                #$count++
                    IF($f_dryRun -eq 0)
                        {
                            
                            TRY
                                {
                                    $sqlFile =  $f_sqlSourcePath +"\"+ $currentFile
                                    WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB -DisableVariables -ErrorAction Stop -InputFile $sqlFile "
	                                Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB -DisableVariables -ErrorAction Stop -InputFile $sqlFile 
                                    IF($process -ne "FAILED"){ $Process = "Succesful" }

                                    ## CHECK FOR PREVIOUS ERROR AND REMOVE IT!
                                    $deleteSQL = "IF EXISTS( SELECT * FROM [deploy].[failedSQL] WHERE deployID = $currentDeployID and failedSQLDatabase = '"+ $f_targetDB +"' AND failedSQLInstance = '"+ $f_targetHost +"' AND failedSQLCommand = '[FAILED - SQLCMD] Invoke-Sqlcmd -ServerInstance "+ $f_targetHost +" -Database "+ $f_targetDB +" -DisableVariables -ErrorAction Stop -InputFile "+ $f_sqlSourcePath +"\"+ $currentFile +" -verbose ' ) 
                                                            BEGIN
                                                                DELETE FROM [deploy].[failedSQL] WHERE deployID = $currentDeployID and failedSQLDatabase = '"+ $f_targetDB +"' AND failedSQLInstance = '"+ $f_targetHost +"' AND failedSQLCommand = '[FAILED - SQLCMD] Invoke-Sqlcmd -ServerInstance "+ $f_targetHost +" -Database "+ $f_targetDB +" -DisableVariables -ErrorAction Stop -InputFile "+ $f_sqlSourcePath +"\"+ $currentFile +" -verbose '
                                                             END;"
            
                                    WRITE-VERBOSE "invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query `"$deleteSQL`" "
                                    invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $deleteSQL

                                }
                            CATCH
                                {
                                    $scriptFailure = $scriptFailure + 1
                                    $displayCounter = $failureCounter + 1
                                    WRITE-HOST `t"[ALERT] !!! Something broke !!! $currentFile Attempt $displayCounter of $total  !!! Something broke !!! "
                                    $process = "FAILED"

                                    IF($displayCounter -eq $total )
                                    {
                                        $ExceptionMessage = "[FAILED - SQLCMD] Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB -DisableVariables -ErrorAction Stop -InputFile $f_sqlSourcePath\$currentFile -verbose "
                                        
                                        $caseRecord = checkStatus-record $deployServer $deployDB "failedSQL" $f_targetDB $f_targetHost $currentDeployID $f_dryRun
                                        
                                        IF( $caseRecord -eq 0 ) # Not recorded in deploy tables
                                            {
                                                WRITE-VERBOSE "Recording new alert"
                                                [void]$ResultsTable.Rows.Add("3", $currentHost, $targetDB, $ExceptionMessage)
                                                
                                                ## record in DBautomation database
                                                $insertSQL = "IF NOT EXISTS( SELECT * FROM [deploy].[failedSQL] WHERE deployID = $currentDeployID and failedSQLDatabase = '"+ $targetDB +"' AND failedSQLInstance = '"+ $currentHost +"' ) 
                                                                BEGIN
                                                                    INSERT INTO [deploy].[failedSQL] ( [deployID], [failedSQLDatabase], [failedSQLInstance], [failedSQLCommand], [failedSQLCase] ) 
                                                                        VALUES   ( "+ $currentDeployID +", '"+ $f_targetDB +"', '"+ $f_targetHost +"', '"+ $ExceptionMessage +"', '' )
                                                                END;"

                                            }
                                        ELSE # Already recorded - down grading to a warning 
                                            {
                                                WRITE-VERBOSE "Recorded Case = $caseRecord "
                                                WRITE-HOST `t"Already recorded $caseRecord and has a work ticket - downgrading to WARNING"
                                        
                                                ## record in DBautomation database
                                                $insertSQL = "IF NOT EXISTS( SELECT * FROM [deploy].[failedSQL] WHERE deployID = $currentDeployID and failedSQLDatabase = '"+ $targetDB +"' AND failedSQLInstance = '"+ $currentHost +"' ) 
                                                    BEGIN
                                                        INSERT INTO [deploy].[failedSQL] ( [deployID], [failedSQLDatabase], [failedSQLInstance], [failedSQLCommand], [failedSQLCase] ) 
                                                            VALUES   ( "+ $currentDeployID +", '"+ $f_targetDB +"', '"+ $f_targetHost +"', '"+ $ExceptionMessage +"', '"+ $caseRecord +"' )
                                                    END;"


                                                [void]$ResultsTable.Rows.Add("2", $currentHost, $targetDB, $ExceptionMessage)
                                            }
                                        
                                        IF( ($dryRun -eq 0) -AND ($currentDeployID -ne 0) )
                                            {
                                                WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query `"$insertSQL`" "
                                                invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $insertSQL
                                            }
                                    }
                                }
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB -DisableVariables  -ErrorAction Stop -InputFile $f_sqlSourcePath\$currentFile -verbose "
                            IF($process -ne "FAILED"){ $Process = "Succesful" }
                        }
                } #end get-childItem
                #WRITE-HOST " "
                $failureCounter ++
            } #end WHILE

            If( $process -eq "FAILED" )
                {
                    WRITE-HOST "[ALERT] Failure $failureCounter Total $total"
                    #IF( ($failureCounter -eq $total) -AND $verbose) { $error }
                    #IF( $failureCounter -eq $total ) { $error }

                    $ExceptionMessage = "[FAILED] .\deployGitHubObjects.ps1 -targetHost $f_targetHost -targetDB $f_targetDB -repoFolder $f_folder -phase $phase -cmsGroup $f_cmsGroup -dryRun $dryRun -force "
                    [void]$ResultsTable.Rows.Add("3", $f_targetHost, $f_targetDB, $ExceptionMessage)
                    <# SHOULD THIS BE RECORDED IN THE DEPLOY RESULT TABLE ???? #>
                }
            ELSEIF( $f_dryRun -eq 0 -AND $total -ne 0)
                {
                    WRITE-HOST "[OK] Process was Successful "
                    $SuccessfulMessage = "[Success] Processed: $f_sqlSourcePath"
                    [void]$ResultsTable.Rows.Add("1", $f_targetHost, $f_targetDB, $SuccessfulMessage)
                }
            $total = 0

        } #end ELSE      
}
	
#clear

#Create Results DataTable
    $ResultsTable = New-Object System.Data.DataTable 
    [void]$ResultsTable.Columns.Add("OrderValue")
    [void]$resultsTable.Columns.Add("targetInstance")
    [void]$resultsTable.Columns.Add("targetDatabase")
    [void]$ResultsTable.Columns.Add("FinalResults")

    #Stop ErrorActionPreference 
    #$ErrorActionPreference = "Stop"   

# variables for script directory
$serverCounter = 0
$total = 0
$currentDeployID = 0
$startTime = get-date -Format g

$filterExtenion = $filter.substring($filter.Length -4) 
IF( $filterExtenion -eq ".zip" -AND $targetDB -eq "") 
    { $repoRoot = $repoRoot + $filter }
ELSEIF( $filterExtenion -eq ".zip" -AND $targetDB -ne "") 
    { $repoRoot = $repoRoot.REPLACE( $targetDB, $filter ) }
$folderArray = @()
IF( $filterExtenion -eq ".ZIP" -and $targetDB -eq "" )
    {
        WRITE-HOST "[] No targetDB specified - gathering all root folders in repo.zip: $repoRoot "
        #$folderArray = @() 
        $rawFolders = [IO.Compression.ZipFile]::OpenRead($repoRoot).Entries
        ForEach( $rawFolder in $rawFolders )
            { 
                $currentFolder = $rawFolder.FullName
                WRITE-VERBOSE $currentFolder
                $rootFolder = $currentFolder.Substring(0,$currentFolder.IndexOf("\"))
                #$rootFolder

                IF($folderArray.Contains($rootFolder) -eq $false) 
                    {
                        $folderArray += $rootFolder
                    }
            }
       
        If( $dryRun -eq 1 )
            { 
                ForEach( $folder in $folderArray )
                    {
                        WRITE-HOST `t"$folder "
                        WRITE-VERBOSE ".\deployGitHubObjects.ps1 -targetDB $folder -filter $filter -repoRoot $repoRoot -repoFolder $repoFolder -phase $phase -cmsGroup $cmsGroup -deployID $currentDeployID -dryRun $dryRun"
                    }
            }
    }
ELSE
    {
         $folderArray += $targetDB
    }

<#######################################################
    Query CMS 2 layers deep - INSTANCE - AUTO group 
#######################################################
$select2SQL = "  select t.name AS [Parent Name], Grps.name AS [Group Name], 'Non-Stack' AS [Stack Name], Srv.name AS [Display Name], 
                    CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                    ELSE Srv.server_name END  AS FQDN, Srv.[description] 
                FROM msdb.dbo.sysmanagement_shared_server_groups as t 
	            LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as grps on grps.parent_id = t.server_group_id --on       grps.parent_id = t.server_group_id 
	            --LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as stack on stack.parent_id = grps.server_group_id
	            LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers as srv ON Srv.server_group_id = stack.server_group_id
                where t.name = 'ByInstance' AND grps.Name = 'Auto-"+ $cmsGroup +"' AND srv.Name is not null
                ORDER BY srv.server_name "
<#######################################################
    Query CMS 3 layers deep - INSTANCE - AUTO group - POD group
#######################################################
$select3SQL = "  select t.name AS [Parent Name], Grps.name AS [Group Name], 'Non-Stack' AS [Stack Name], Srv.name AS [Display Name], 
                    CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                    ELSE Srv.server_name END  AS FQDN, Srv.[description] 
                FROM msdb.dbo.sysmanagement_shared_server_groups as t 
	            LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as grps on grps.parent_id = t.server_group_id --on       grps.parent_id = t.server_group_id 
	            --LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as stack on stack.parent_id = grps.server_group_id
	            LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers as srv ON Srv.server_group_id = stack.server_group_id
                where t.name = 'ByInstance' AND grps.Name = 'Auto-"+ $cmsGroup +"' AND srv.Name is not null
                ORDER BY srv.server_name "
<#######################################################
    Query CMS 4 layers deep - INSTANCE - AUTO group - POD group - STACK
#######################################################
$select4SQL = "  select t.name AS [Parent Name], Grps.name AS [Group Name], stack.Name AS [Stack Name], Srv.name AS [Display Name], 
                    CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                    ELSE Srv.server_name END  AS FQDN, Srv.[description] 
                FROM msdb.dbo.sysmanagement_shared_server_groups as t 
	            LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as grps on grps.parent_id = t.server_group_id 
                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as POD on POD.parent_id = grps.server_group_id
	            LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as stack on stack.parent_id = grps.server_group_id
	            LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers as srv ON Srv.server_group_id = stack.server_group_id
                where t.name = 'Auto-ByInstance' AND grps.Name = 'Auto-PROD' AND srv.Name is not null AND stack.Name = '"+ $cmsGroup +"'  
			    ORDER BY srv.server_name "}
#>
　
ForEach( $folder in $folderArray )
{
    $targetDB = $folder
    IF( ($currentDomain -eq '.XT.LOCAL') -AND ($phase -in ("phase0","phase1","phase2")) )
        {
            WRITE-VERBOSE "SETTING PROD VALUES "
            $targetCMS = "XTINP1DBA01\DBadmin"  #Trusted CMS 
            $targetInvServer = "XTINOPSD2.XT.LOCAL\I2"
            $targetInvDB = "SQLmonitor"
            $scriptNinjaInst = "XTINP1DBA01.XT.LOCAL\I1"
            $scriptNinjaPath = "\\XTINP1DBA01.XT.LOCAL\D$"
            $deployServer = "XTINOPSD2.XT.LOCAL\I2"
            $deployDB = "DBautomation"
            $zargaHost = "INDsomething.XT.LOCAL"

            $level2Groups = @( "ActiveBatch","Admin","commVault","Confio","DBA01","DBrestores","DataWarehouse","MediaServers","StandbyMgr","DBA01MAchines","Templates" )
            $level3Groups = @( "Unused" )
            $level4Groups = @( "Build","Standby" ) #All Live Stack DBs are in level 4.
            $phase1Groups = @( "Stack2", "Stack4", "Stack10" )
            $phase2Groups = @( "Stack1", "Stack5", "Stack6", "Stack7" )
            #IF( $cmsGroup -eq 'NA' -AND $phase -eq "phase0"){ $phaseGroups = @("QA") }  Can't  do this because of how I built the cms query.

            If( ($targetDB.ToUpper() -eq "UTILITY") -OR ($targetDB.ToUpper() -eq "WORKTABLEDB") )
                {
                    switch ($phase) 
                    {
                        ### BAD NAMING - no "AUTO-"
                        {($_ -eq "phase0" ) -AND ($cmsGroup -eq "DBA01MAchines")} {  
                                                                                    WRITE-VERBOSE "Phase0 - level 1";
                                                                                    $selectCMS = "  select t.name AS [Parent Name], Grps.name AS [Group Name], '"+ $cmsGroup +"' AS [Stack Name], Srv.name AS [Display Name], 
                                                                                        CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                                                                                        ELSE Srv.server_name END  AS FQDN, Srv.[description] 
                                                                                    FROM msdb.dbo.sysmanagement_shared_server_groups as t 
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as grps on grps.parent_id = t.server_group_id
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers as srv ON Srv.server_group_id = grps.server_group_id
                                                                                    where t.name = 'ByInstance' AND grps.Name = '"+ $cmsGroup +"' AND srv.Name is not null
                                                                                    ORDER BY srv.server_name ";BREAK}
                        ### BYINSTANCE - AUTO group - instance
                        {($_ -eq "phase0" ) -AND ($cmsGroup -in $level2Groups)} {  
                                                                                    WRITE-VERBOSE "Phase0 - level 2";
                                                                                    $selectCMS = "  select t.name AS [Parent Name], Grps.name AS [Group Name], '"+ $cmsGroup +"' AS [Stack Name], Srv.name AS [Display Name], 
                                                                                        CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                                                                                        ELSE Srv.server_name END  AS FQDN, Srv.[description] 
                                                                                    FROM msdb.dbo.sysmanagement_shared_server_groups as t 
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as grps on grps.parent_id = t.server_group_id
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers as srv ON Srv.server_group_id = grps.server_group_id
                                                                                    where t.name = 'ByInstance' AND grps.Name = 'Auto-"+ $cmsGroup +"' AND srv.Name is not null
                                                                                    ORDER BY srv.server_name ";BREAK}
                        ### BYINSTANCE - AUTO group - POD group - instance
                        {($_ -eq "phase0" ) -AND ($cmsGroup -in $level3Groups)} {  
                                                                                    WRITE-VERBOSE "Phase0 - level 3";
                                                                                    $selectCMS = "  select t.name AS [Parent Name], Grps.name AS [Group Name], pod.Name AS [Stack Name], Srv.name AS [Display Name], 
                                                                                        CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                                                                                        ELSE Srv.server_name END  AS FQDN, Srv.[description] 
                                                                                    FROM msdb.dbo.sysmanagement_shared_server_groups as t 
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as grps on grps.parent_id = t.server_group_id --on       grps.parent_id = t.server_group_id 
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as POD on POD.parent_id = grps.server_group_id
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers as srv ON Srv.server_group_id = POD.server_group_id
                                                                                    where t.name = 'ByInstance' AND grps.Name = 'Auto-"+ $cmsGroup +"' AND srv.Name is not null
                                                                                    ORDER BY srv.server_name ";BREAK}
                        ### BYINSTANCE - AUTO group - POD group - STACK group - instance
                        {($_ -eq "phase0" ) -AND ($cmsGroup -in $level4Groups)} {  
                                                                                    WRITE-VERBOSE "Phase0 - level 4";
                                                                                    $selectCMS = "  select t.name AS [Parent Name], Grps.name AS [Group Name], stack.Name AS [Stack Name], Srv.name AS [Display Name], 
                                                                                        CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                                                                                        ELSE Srv.server_name END  AS FQDN, Srv.[description] 
                                                                                    FROM msdb.dbo.sysmanagement_shared_server_groups as t 
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as grps on grps.parent_id = t.server_group_id 
                                                                                    LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as POD on POD.parent_id = grps.server_group_id
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as stack on stack.parent_id = POD.server_group_id
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers as srv ON Srv.server_group_id = stack.server_group_id
                                                                                    where t.name = 'ByInstance' AND grps.Name = 'Auto-"+ $cmsGroup +"' AND srv.Name is not null
								                                                    ORDER BY srv.server_name ";BREAK}
                        ### BYINSTANCE - AUTO group - POD group - STACK group - instance
                        {($_ -eq "phase0" ) -AND ($cmsGroup -eq "Stack8")} {       
                                                                                WRITE-VERBOSE "Phase0 - $cmsGroup";
                                                                                $selectCMS = "  select t.name AS [Parent Name], Grps.name AS [Group Name], stack.Name AS [Stack Name], Srv.name AS [Display Name], 
                                                                                    CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                                                                                    ELSE Srv.server_name END  AS FQDN, Srv.[description] 
                                                                                FROM msdb.dbo.sysmanagement_shared_server_groups as t 
	                                                                            LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as grps on grps.parent_id = t.server_group_id 
                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as POD on POD.parent_id = grps.server_group_id
	                                                                            LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as stack on stack.parent_id = POD.server_group_id
	                                                                            LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers as srv ON Srv.server_group_id = stack.server_group_id
                                                                                where t.name = 'ByInstance' AND grps.Name = 'Auto-PROD' AND srv.Name is not null AND stack.Name = '"+ $cmsGroup +"'  
								                                                ORDER BY srv.server_name ";BREAK}
                        {($_ -eq "phase1" ) -AND ($cmsGroup -in $phase1Groups) } {       
                                                                                    WRITE-VERBOSE "Phase1 - $cmsGroup";
                                                                                    $selectCMS = "  select t.name AS [Parent Name], Grps.name AS [Group Name], stack.Name AS [Stack Name], Srv.name AS [Display Name], 
                                                                                        CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                                                                                        ELSE Srv.server_name END  AS FQDN, Srv.[description] 
                                                                                    FROM msdb.dbo.sysmanagement_shared_server_groups as t 
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as grps on grps.parent_id = t.server_group_id 
                                                                                    LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as POD on POD.parent_id = grps.server_group_id
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as stack on stack.parent_id = POD.server_group_id
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers as srv ON Srv.server_group_id = stack.server_group_id
                                                                                    where t.name = 'ByInstance' AND grps.Name = 'Auto-PROD' AND srv.Name is not null AND stack.Name = '"+ $cmsGroup +"'  
								                                                    ORDER BY srv.server_name ";BREAK}
                        {($_ -eq "phase2" ) -AND ($cmsGroup -in $phase2Groups) } {  
                                                                                    WRITE-VERBOSE "Phase2 - $cmsGroup";
                                                                                    $selectCMS = "  select t.name AS [Parent Name], Grps.name AS [Group Name], stack.Name AS [Stack Name], Srv.name AS [Display Name], 
                                                                                        CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                                                                                        ELSE Srv.server_name END  AS FQDN, Srv.[description] 
                                                                                    FROM msdb.dbo.sysmanagement_shared_server_groups as t 
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as grps on grps.parent_id = t.server_group_id 
                                                                                    LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as POD on POD.parent_id = grps.server_group_id
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as stack on stack.parent_id = POD.server_group_id
	                                                                                LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers as srv ON Srv.server_group_id = stack.server_group_id
                                                                                    where t.name = 'ByInstance' AND grps.Name = 'Auto-PROD' AND srv.Name is not null AND stack.Name = '"+ $cmsGroup +"'  
								                                                    ORDER BY srv.server_name ";BREAK}
                    
                        default { WRITE-HOST "Failing out"; EXIT }
                    }

                }
            ELSEIF( $targetDB.ToUpper() -eq "SQLMONITOR")
                                {   
                WRITE-VERBOSE "SQLmonitor - $cmsGroup";
                #$selectSQL = "select FQDN from [dbo].[instance] where InstanceID in ( SELECT hostInstance FROM [Database] where databasename like '"+ $targetDB +"' ) and isOn = 1"
                $targetHost = "XTINOPSD2.XT.LOCAL\I2" 
            }
            ELSE
                                                {   
                WRITE-VERBOSE "$targetDB - $cmsGroup";
                $stackNumber = $cmsGroup -REPLACE('stack','')
                $selectSQL = "select FQDN 
                                from [SQLmonitor].[dbo].[instance] where InstanceID in ( SELECT hostInstance FROM [SQLmonitor].[dbo].[Database] 
                                where databasename like '"+ $targetDB +"' AND stack = "+ $stackNumber +" ) and isOn = 1"
                #$cmsDB = "sqlMonitor"
                $targetCMS = "XTINOPSD2.XT.LOCAL\I2" #SQLmonitor instance
            }

            WRITE-VERBOSE "Target CMS: $targetCMS "
            WRITE-VERBOSE "TargetInvDB: $targetInvDB "
            WRITE-VERBOSE "ScriptNinja UNC: $scriptNinjaPath "
        }
    ELSEIF( ($currentDomain -eq '.QA.LOCAL') -AND ($phase.ToUpper() -eq "STAGING") )
        {
        WRITE-VERBOSE "SETTING QA VALUES "
        $targetCMS = "IND2Q00DBA01.QA.LOCAL\I1" #Trusted CMS 
        $targetInvServer = "IND2Q00DBA01.QA.LOCAL\I1"
        $targetInvDB = "SQLmonitor"
        $scriptNinjaInst = "IND2Q00DBA01.QA.LOCAL\I1"
        $scriptNinjaPath = "\\IND2Q00DBA01.QA.LOCAL\D$"
        $deployServer = "IND2Q00DBA01.QA.LOCAL\I1"
        $deployDB = "DBautomation"
        $zargaHost = "IND2Q00DBAPI01.QA.LOCAL"
        #IF( $cmsGroup -eq 'NA' ){ $phaseGroups = @("QA") }

        If( ($targetDB.ToUpper() -eq "UTILITY") -OR ($targetDB.ToUpper() -eq "WORKTABLEDB") )
            {
                $selectCMS = "  select t.name AS [Parent Name], Grps.name AS [Group Name], Stack.name AS [Stack Name], Srv.name AS [Display Name], 
                                     CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                                          ELSE Srv.server_name END  AS FQDN, Srv.[description] 
                                FROM msdb.dbo.sysmanagement_shared_server_groups as t 
	                            LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as grps on grps.parent_id = t.server_group_id --on       grps.parent_id = t.server_group_id 
	                            LEFT JOIN msdb.dbo.sysmanagement_shared_server_groups as stack on stack.parent_id = grps.server_group_id
	                            LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers as srv ON Srv.server_group_id = stack.server_group_id
                                where t.name = 'Auto-ByInstance' and Stack.Name not like '%Use NP domain%' 
								-- AND CASE WHEN charIndex(',',Srv.server_name) !=0 THEN LEFT(Srv.server_name,charIndex(',',Srv.server_name)-1)   
                                --          ELSE Srv.server_name END not IN ('QAIN1DBRPT1.QA.LOCAL\I1' ,'QANV1DBRPT1.qa.local\i1')
                                ORDER BY srv.server_name "

            }
        ELSEIF( $targetDB.ToUpper() -eq "SQLMONITOR") #Not in inventory correctly
            {   
                WRITE-VERBOSE "SQLmonitor - Not in Inventory - hard coded";
                #$selectSQL = "select FQDN from [dbo].[instance] where InstanceID in ( SELECT hostInstance FROM [Database] where databasename like '"+ $targetDB +"' ) and isOn = 1"
                $targetHost = "IND2Q00DBA01.qa.local\i1" 
            }
        ELSEIF( ($targetDB.ToUpper() -eq "STANDARDJOBS") -OR ($targetDB.ToUpper() -eq "SCRIPTNINJA") )
            {
                $targetHost = $scriptNinjaInst
            }
        ELSEIF( $targetDB.ToUpper() -eq "ENDPOINTS" )
            {
                WRITE-VERBOSE "Setting Zarga UNC paths"
                $targetHost = $zargaHost
            }
        ELSE  #Uknown things .... look in 
            {
                WRITE-VERBOSE "$targetDB - $cmsGroup";
                $selectCMS = "select FQDN from [dbo].[instance] where InstanceID in ( SELECT hostInstance FROM [Database] where databasename like '"+ $targetDB +"' ) and isOn = 1"
                #$cmsDB = "sqlMonitor"
                $targetCMS = "IND2Q00DBA01.QA.LOCAL\I1" #SQLmonitor instance
            }
        WRITE-VERBOSE "Target CMS: $targetCMS "
        WRITE-VERBOSE "TargetInvDB: $targetInvDB "
        WRITE-VERBOSE "ScriptNinja UNC: $scriptNinjaPath "
    }
    ELSEIF( ($currentDomain -eq '.XT.LOCAL' -OR $currentDomain -eq '.QA.LOCAL') -AND ($phase -eq "NA" -or $cmsGroup -eq "NA" ) )
        {
            WRITE-HOST "[!!]                                               [!!]"
            WRITE-HOST "[!!] Standalone deploy - targeting single instance [!!]"
            WRITE-HOST "[!!]                                               [!!]"
        }
    ELSE
        {
            WRITE-HOST "[ALERT] BAD COMMAND - OUTOUT what it was and maybe I can figure it out...."
            WRITE-HOST "Targeting a ZIP file:"
            WRITE-HOST ".\deployGitHubObjects.ps1 -filter $filter -phase $phase -cmsGroup $cmsGroup -dryRun $dryRun "; EXIT
        }

    WRITE-HOST "[] Working Domain: $currentDomain "
    WRITE-HOST "[] Target INV Server: $targetInvServer "
    WRITE-HOST "[] Inv Database: $targetInvDB "
 
    IF($targetHost -ne ""){ WRITE-HOST "[] Target Host: $targetHost " }
    IF($targetDB -ne ""  ){ WRITE-HOST "[] Target DB: $targetDB " }

    WRITE-HOST "[] Phase: $phase "
    WRITE-HOST "[] CMS Group: $cmsGroup "

    IF($repoFolder -ne ""  ){ WRITE-HOST "[] Repo SubFolder: $repoFolder " }

    IF( ($dryRun -eq 0) -AND ($deployID -eq 0) )
        {
            WRITE-VERBOSE "Recording new Run"
            #insert new DEPLOY record and get deplotID     
            $insertSQL = "INSERT INTO [deploy].[deploy] ( [deployStart], [deployRepo], [deployExecutedby], [deployFrom], [deployRepoVersion], [deployCMS] ) VALUES ( '$startTime', '$targetDB', '$env:UserName', '$env:computername', '$repoVersion', '$cmsGroup'  )"
            WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $insertSQL "
            invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $insertSQL

            $selectSQL = "SELECT MAX(deployID) AS deployID FROM [deploy].[deploy] WHERE deployStart = '"+ $startTime +"' and deployExecutedBy = '"+ $env:UserName +"' AND deployRepo = '"+ $targetDB +"' and deployCms = '"+ $cmsGroup +"'"
            WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $selectSQL "
            $deploy_ID = invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $selectSQL | select deployID
            $currentDeployID = $deploy_ID.deployID
                                    
        }
    ELSE
        {
            #Giving thought of updating last run outcome here to show running again....
            WRITE-VERBOSE "Rerunning deploy $deployID "
            $currentDeployID = $deployID
        }

    WRITE-HOST "[] Current Deploy: $currentDeployID " 
    WRITE-HOST "[] Filter: $filter  "
    WRITE-HOST "[] DryRun: $dryRun "
    WRITE-VERBOSE ".\deployGitHubObjects.ps1 -targetDB $folder -filter $filter -repoRoot $repoRoot -repoFolder $repoFolder -phase $phase -cmsGroup $cmsGroup -dryRun $dryRun -force" 
    WRITE-HOST " "

#  This is a place holder if we were wanting to cycle through all phase0 groups
#ForEach ( $group in $phaseGroups )
#    {

        IF( ($targetHost -eq "") -AND ($folder.ToUpper() -ne "STANDARDJOBS") )
            {
                WRITE-HOST "[] No target instance supplied - looking at inventory"
                #$selectSQL
                WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $targetCMS -Database master -Query $selectCMS "
                $hostList = @( invoke-sqlcmd -ServerInstance $targetCMS -Database master -Query $selectCMS | select -exp FQDN )
            }
        ELSEIF ( $targetHost -eq "[FAILED - CONNECTION]" )
            {
                WRITE-HOST "[] Reprocessing Failed Connections"
                $selectFailed = " SELECT failedConnectionInstance FROM deploy.failedConnection WHERE failedConnectionDatabase = '"+ $folder +"' AND deployID = $currentDeployID"
                WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $selectFailed "
                $hostList = @( invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $selectFailed | select -exp failedConnectionInstance)
            }
        ELSEIF ( $targetHost -eq "[FAILED - PING]" )
            {
                WRITE-HOST "[] Reprocessing Failed Pings"
                $selectFailed = " SELECT failedPingInstance FROM deploy.failedPing WHERE failedPingDatabase = '"+ $folder +"' AND deployID = $currentDeployID"
                WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $selectFailed "
                $hostList = @( invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $selectFailed | select -exp failedPingInstance)
            }
        ELSEIF ( $folder.ToUpper() -ne "STANDARDJOBS" )
            {
                WRITE-HOST "[] Target instance supplied "
                $hostList = $targetHost
            }

        IF( $dryRun -eq 1 ){ ForEach( $currenthost in $hostList){ WRITE-HOST `t" $currenthost"; WRITE-HOST " " } }

        IF( $targetDB.ToUpper() -eq "STANDARDJOBS" )
            {        
                WRITE-HOST "[] CopyFiles"
                WRITE-HOST `t"Copy to Standard location used by baseline:  $scriptNinjaPath\IBtest\Scripts "
                $serverCount = 1
                IF( $filterExtenion -eq ".sql" )
                    {
                        IF( $dryRun -eq 1 )
                            {
                                WRITE-HOST '[DryRun] copyFiles-somewhere "*.SQL" "'$scriptNinjaPath'\IBtest\Scripts" "'repoRoot'" 0' 
                            }
                        
                        ELSE
                            {
                                copyFiles-somewhere "*.SQL" "$scriptNinjaPath\IBtest\Scripts" "$repoRoot" 0 
                            }
                    }
                ELSE
                    {
                        # Uncertain how to do this....
                        process-zipFile "$repoRoot" $scriptNinjaPath\StandardJobScript  #$folder $targetDB $repoVersion $dryRun
                    }

                
                WRITE-HOST `t"Copy to location used by ScriptNinja: $scriptNinjaPath\StandardJobScript "
                IF( $filterExtenion -eq ".sql" )
                    {
                        IF( $dryRun -eq 1 )
                            {
                                WRITE-HOST '[DryRun] copyFiles-somewhere "*.SQL" "'$scriptNinjaPath'\StandardJobScript" "'repoRoot'" 0' 
                            }
                        
                        ELSE
                            {
                                copyFiles-somewhere "*.SQL" "$scriptNinjaPath\StandardJobScript" "$repoRoot" 0 
                            }
                    }
                ELSE
                    {
                        # Uncertain how to do this....
                        process-zipFile "$repoRoot" $scriptNinjaInst\StandardJobScript  #$folder $targetDB $repoVersion $dryRun
                    }

                If( $filterExtenion -eq ".zip"){ $targetHost = "" }
            }
        ELSEIF( ($targetDB.ToUpper() -eq "SCRIPTNINJA") -OR ($targetDB.ToUpper() -eq "SCRIPTS") )
            {        
                WRITE-HOST "[] CopyFiles"
                WRITE-HOST `t"Copy to Standard location used by baseline:  $scriptNinjaPath\IBTEST "
                IF( ($filterExtenion -eq ".sql") -AND ('PATH' -eq '\Scripts\Baselining') )
                    {
                        IF( $dryRun -eq 1 )
                            {
                                WRITE-HOST '[DryRun] copyFiles-somewhere "*.SQL" "'$scriptNinjaPath'\IBtest" "'repoRoot'" 1' 
                            }
                        
                        ELSE
                            {
                                WRITE-HOST '[DryRun] copyFiles-somewhere "*.SQL" "'$scriptNinjaPath'\IBtest" "'repoRoot'" 1' 
                                #copyFiles-somewhere "*.SQL" "$scriptNinjaPath\IBtest" "$repoRoot" 1 
                            }
                    }
                ELSE
                    {
                        # Uncertain how to do this....
                        process-zipFile "$repoRoot" $scriptNinjaPath\StandardJobScript  #$folder $targetDB $repoVersion $dryRun
                    }

                
                WRITE-HOST `t"Copy to location used by ScriptNinja: $scriptNinjaPath\ScriptNinja\Scripts "
                IF( ($filterExtenion -eq ".sql") -AND ('PATH' -eq '\Scripts') )
                    {
                        IF( $dryRun -eq 1 )
                            {
                                WRITE-HOST '[DryRun] copyFiles-somewhere "*.SQL" "'$scriptNinjaPath'\ScriptNinja\Scripts" "'repoRoot'" 1' 
                            }
                        
                        ELSE
                            {
                                WRITE-HOST '[DryRun] copyFiles-somewhere "*.SQL" "'$scriptNinjaPath'\ScriptNinja\Scripts" "'repoRoot'" 1'
                                #copyFiles-somewhere "*.SQL" "$scriptNinjaPath\ScriptNinja\Scripts" "$repoRoot" 1 
                            }
                    }
                ELSE
                    {
                        # Uncertain how to do this....
                        process-zipFile "$repoRoot" $scriptNinjaInst\StandardJobScript  #$folder $targetDB $repoVersion $dryRun
                    }

                If( $filterExtenion -eq ".zip"){ $targetHost = "" }
            }
        ELSEIF( $targetDB.ToUpper() -eq "ENDPOINTS" )
            {   
                WRITE-HOST "[] CopyFiles"
                WRITE-HOST `t"Copy to Standard location used by baseline: ZARGA HOST AND LOCATION TO BE DETERMINED "
                #process-zipFile "$repoRoot" $scriptNinjaInst $folder $targetDB $repoVersion $dryRun

                If( $filterExtenion -eq ".zip"){ $targetHost = "" }
            }
        ELSE
            {
                $serverCount = $hostList.count
                ForEach ( $currentHost in $hostList )
                    {
                        WRITE-HOST "[] Ping Test: $currentHost "
                        IF( checkStatus-Ping $currentHost $currentDomain ) 
                            {
                                WRITE-HOST "[] DB Test: $targetDB "
                                $targetDBInfo = @( checkStatus-online $currentHost $targetDB $phase $cmsGroup $dryRun )
                                $targetDBInfodbName = $targetDBInfo.dbName
                                $targetDBInfodbState  = $targetDBInfo.dbState 
                                $targetDBInfoserverType = $targetDBInfo.serverType
                                $targetDBInfoCount = $targetDBInfo.Count
                                WRITE-VERBOSE "targetDB: $targetDBInfodbName  "
                                WRITE-VERBOSE "target State: $targetDBInfodbState  "
                                WRITE-VERBOSE "Server Type: $targetDBInfoserverType  "
                                WRITE-VERBOSE "Count: $targetDBInfoCount  "

                                IF( ($targetDBInfo.dbState -ne "RESTORING") -AND ($targetDBInfo.dbState -ne "MISSING") -AND ($targetDBInfoCount -gt 0) )
                                    {
                                        IF( $filterExtenion -eq ".sql" )
                                            {
                                                WRITE-HOST "[] Processing: TSQL" #[string] $f_sqlSourcePath, [string] $f_targetHost, [string] $f_targetDB, [string] $f_folder, [string] $f_repoVersion , [int] $f_dryRun
                                                WRITE-VERBOSE ".\deployGitHubObjects.ps1 -targetDB $targetDB -targetHost $currentHost -phase $phase -cmsGroup $cmsGroup -dryRun $dryRun"
                                                If( $repoFolder -eq "Auto" )
                                                    {	
                                                        process-Folder "$repoRoot\" $currentHost $currentDomain $targetDB "Role"     $cmsGroup $dryRun
                                                        process-Folder "$repoRoot\" $currentHost $currentDomain $targetDB "Schema"   $cmsGroup $dryRun
                                                        process-Folder "$repoRoot\" $currentHost $currentDomain $targetDB "Table"    $cmsGroup $dryRun
                                                        process-Folder "$repoRoot\" $currentHost $currentDomain $targetDB "View"     $cmsGroup $dryRun 
                                                        process-Folder "$repoRoot\" $currentHost $currentDomain $targetDB "Type"     $cmsGroup $dryRun	
                                                        process-Folder "$repoRoot\" $currentHost $currentDomain $targetDB "Synonym"  $cmsGroup $dryRun
                                                        process-Folder "$repoRoot\" $currentHost $currentDomain $targetDB "UserDefinedFunction" $cmsGroup $dryRun
                                                        process-Folder "$repoRoot\" $currentHost $currentDomain $targetDB "StoredProcedure" $cmsGroup $dryRun
                                                        process-Folder "$repoRoot\" $currentHost $currentDomain $targetDB "Init"      $cmsGroup $dryRun
                                                        process-Folder "$repoRoot\" $currentHost $currentDomain $targetDB "AgentJobs" $cmsGroup $dryRun
                                                    }
                                                ELSE
                                                    {
                                                        Process-Folder "$repoRoot\" $currentHost $currentDomain $targetDB $repoFolder $repoVersion $dryRun
                                                    }
                                             }
                                        ELSEIf( $filterExtenion -eq ".zip")
                                            {
 
                                                $repoVersion = $filter.replace(".ZIP", "" )
                                                WRITE-HOST "[] Processing: PowerShell - $repoRoot "
                                                WRITE-VERBOSE ".\deployGitHubObjects.ps1 -targetDB $targetDB -targetHost $currentHost -phase $phase -cmsGroup $cmsGroup -dryRun $dryRun"
                                                IF(Test-Path $repoRoot) 
                                                    {
                                                        If($repoFolder -eq "Auto" ) #-AND $targetDB -eq "" )
                                                            {

                                                                process-zipFile "$repoRoot" $currentHost $currentDomain $folder "Role" $cmsGroup $dryRun
                                                                process-zipFile "$repoRoot" $currentHost $currentDomain $folder "Schema" $cmsGroup $dryRun
                                                                process-zipFile "$repoRoot" $currentHost $currentDomain $folder "Table" $cmsGroup $dryRun
                                                                process-zipFile "$repoRoot" $currentHost $currentDomain $folder "View" $cmsGroup $dryRun 
                                                                process-zipFile "$repoRoot" $currentHost $currentDomain $folder "Type" $cmsGroup $dryRun	
                                                                process-zipFile "$repoRoot" $currentHost $currentDomain $folder "Synonym" $cmsGroup $dryRun
                                                                process-zipFile "$repoRoot" $currentHost $currentDomain $folder "UserDefinedFunction" $cmsGroup $dryRun
                                                                process-zipFile "$repoRoot" $currentHost $currentDomain $folder "StoredProcedure" $cmsGroup $dryRun
                                                                process-zipFile "$repoRoot" $currentHost $currentDomain $folder "Init" $cmsGroup $dryRun
                                                                process-zipFile "$repoRoot" $currentHost $currentDomain $folder "AgentJobs" $cmsGroup $dryRun
                                                            }
                                                        ELSE
                                                            {
                                                                process-zipFile "$repoRoot" $currentHost $currentDomain $targetDB "$repoFolder" $cmsGroup $dryRun
                                                            }
                                                    }
                                                ELSE
                                                    {
                                                        WRITE-WARNING "$FileName File path not found" 
                                                        EXIT
                                                    }

                                            }
                                        ELSEIf( $filterExtenion -eq ".ps1" ) # intended for a Single powershell script
                                            {
                                                $repoRoot = $repoRoot.replace($targetDB, "ScriptNinja" )
                                                WRITE-HOST "[] Processing: PowerShell"
                                                WRITE-VERBOSE ".\deployGitHubObjects.ps1 -targetDB $targetDB -targetHost $currentHost -phase $phase -cmsGroup $cmsGroup -dryRun $dryRun"
                                                If($repoFolder -eq "Auto")
                                                    {	
                                                        processFolder "$repoRoot\Scripts" $currentHost $currentDomain $targetDB $dryRun
                                                    }
                                                ELSE
                                                    {
                                                        ProcessFolder "$repoRoot\$repoFolder" $currentHost $currentDomain $targetDB $dryRun
                                                    }
                                            }

                                        ## CHECK FOR PREVIOUS ERROR AND REMOVE IT!
                                        $deleteSQL = "IF EXISTS( SELECT * FROM [deploy].[missingDatabase] WHERE deployID = $currentDeployID and missingDatabaseDatabase = '"+ $f_targetDB +"' AND missingDatabaseInstance = '"+ $f_targetHost +"' ) 
                                                                BEGIN
                                                                    DELETE FROM [deploy].[missingDatabase] WHERE deployID = $currentDeployID and missingDatabaseDatabase = '"+ $f_targetDB +"' AND missingDatabaseInstance = '"+ $f_targetHost +"'
                                                                 END;"
            
                                        WRITE-VERBOSE "invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query `"$deleteSQL`" "
                                        invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $deleteSQL
                                    }
                                ELSEIF( ($targetDBInfo.dbState -eq "RESTORING") -AND ($targetDBInfo.serverType -eq "Restore") ) #-AND ($targetDBInfo.Count -ne 0)  )
                                    {
                                        WRITE-HOST "[SKIP] Target Host is of Type RESTORE and target DB is in state RESTORING"
                                    }
                                ELSEIF( $targetDBInfo.dbState -eq "MISSING" )  # falsely reports missing DB when instance is unreachable.
                                    {
                                        WRITE-HOST "[ALERT] TargetDatabase does not exist  "
                                        $ExceptionMessage = "[FAILED - missingDB] .\deployGitHubObjects.ps1 -targetDB $targetDB -targetHost $currentHost -phase $phase -cmsGroup $cmsGroup -deployID $currentDeployID -dryRun $dryRun -force -verbose "

                                        $caseRecord = checkStatus-record $deployServer $deployDB "missingDatabase" $targetDB $currentHost $currentDeployID $dryRun
                                        
                                        IF( $caseRecord -eq 0 ) # Not recorded in deploy tables
                                            {
                                                WRITE-VERBOSE "Recording new alert"
                                                [void]$ResultsTable.Rows.Add("3", $currentHost, $targetDB, $ExceptionMessage)
                                                
                                                ## record in DBautomation database
                                                $insertSQL = "IF NOT EXISTS( SELECT * FROM [deploy].[missingDatabase] WHERE deployID = $currentDeployID and missingDatabaseDatabase = '"+ $targetDB +"' AND missingDatabaseInstance = '"+ $currentHost +"' ) 
                                                                BEGIN
                                                                    INSERT INTO [deploy].[missingDatabase] ( [deployID], [missingDatabaseDatabase], [missingDatabaseInstance], [missingDatabaseCommand], [missingDatabaseCase] )
                                                                            VALUES   ( "+ $currentDeployID +", '"+ $targetDB +"', '"+ $currentHost +"', '"+ $ExceptionMessage +"', '' )
                                                                 END;"

                                            }
                                        ELSE # Already recorded - down grading to a warning 
                                            {
                                                WRITE-VERBOSE "Recorded Case = $caseRecord "
                                                WRITE-HOST `t"Already recorded $caseRecord and has a work ticket - downgrading to WARNING"
                                                
                                                ## record in DBautomation database
                                                $insertSQL = "IF NOT EXISTS( SELECT * FROM [deploy].[missingDatabase] WHERE deployID = $currentDeployID and missingDatabaseDatabase = '"+ $targetDB +"' AND missingDatabaseInstance = '"+ $currentHost +"' ) 
                                                                BEGIN
                                                                    INSERT INTO [deploy].[missingDatabase] ( [deployID], [missingDatabaseDatabase], [missingDatabaseInstance], [missingDatabaseCommand], [missingDatabaseCase] )
                                                                            VALUES   ( "+ $currentDeployID +", '"+ $targetDB +"', '"+ $currentHost +"', '"+ $ExceptionMessage +"', '"+ $caseRecord +"' )
                                                                END;"

                                                [void]$ResultsTable.Rows.Add("2", $currentHost, $targetDB, $ExceptionMessage)
                                            }
                                        
                                        IF( ($dryRun -eq 0) -AND ($currentDeployID -ne 0) )
                                            {
                                                WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query `"$insertSQL`" "
                                                invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $insertSQL
                                            }
                                    }
                                ## CHECK FOR PREVIOUS ERROR AND REMOVE IT!
                                $deleteSQL = "IF EXISTS( SELECT * FROM [deploy].[failedPing] WHERE deployID = $currentDeployID and failedPingDatabase = '"+ $f_targetDB +"' AND failedPingInstance = '"+ $f_targetHost +"' ) 
                                                        BEGIN
                                                            DELETE FROM [deploy].[failedPing] WHERE deployID = $currentDeployID and failedPingDatabase = '"+ $f_targetDB +"' AND failedPingInstance = '"+ $f_targetHost +"'
                                                        END;"
            
                                WRITE-VERBOSE "invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query `"$deleteSQL`" "
                                invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $deleteSQL
                            }
                        ELSE
                            {
                                WRITE-HOST `t`t"[ALERT] FAILED TO PING - logging Failure"
                                $ExceptionMessage = "[FAILED - PING] .\deployGitHubObjects.ps1 -targetDB $targetDB -targetHost $currentHost -phase $phase -cmsGroup $cmsGroup -deployID $currentDeployID -dryRun $dryRun "

                                $caseRecord = checkStatus-record $deployServer $deployDB "failedPing" $targetDB $currentHost $currentDeployID $dryRun
                                        
                                IF( $caseRecord -eq 0 ) # Not recorded in deploy tables
                                    {
                                        WRITE-VERBOSE "Recording new alert"
                                        [void]$ResultsTable.Rows.Add("3", $currentHost, $targetDB, $ExceptionMessage)
                                                
                                        ## record in DBautomation database
                                        $insertSQL = "IF NOT EXISTS( SELECT * FROM [deploy].[failedPing] WHERE deployID = $currentDeployID and failedPingDatabase = '"+ $targetDB +"' AND failedPingInstance = '"+ $currentHost +"' ) 
                                                         BEGIN
                                                              INSERT INTO [deploy].[failedPing] ( [deployID], [failedPingDatabase], [failedPingInstance], [failedPingCommand], [failedPingCase] )
                                                                    VALUES   ( "+ $currentDeployID +", '"+ $targetDB +"', '"+ $currentHost +"', '"+ $ExceptionMessage +"', '' )
                                                         END;"

                                    }
                                ELSE # Already recorded - down grading to a warning 
                                    {
                                        WRITE-VERBOSE "Recorded Case = $caseRecord "
                                        WRITE-HOST `t"Already recorded $caseRecord and has a work ticket - downgrading to WARNING"
                                        
                                        ## record in DBautomation database
                                        $insertSQL = "IF NOT EXISTS( SELECT * FROM [deploy].[failedPing] WHERE deployID = $currentDeployID and failedPingDatabase = '"+ $targetDB +"' AND failedPingInstance = '"+ $currentHost +"' ) 
                                                         BEGIN
                                                                INSERT INTO [deploy].[failedPing] ( [deployID], [failedPingDatabase], [failedPingInstance], [failedPingCommand], [failedPingCase] )
                                                                    VALUES   ( "+ $currentDeployID +", '"+ $targetDB +"', '"+ $currentHost +"', '"+ $ExceptionMessage +"', '"+ $caseRecord +"' )
                                                         END;"

                                        [void]$ResultsTable.Rows.Add("2", $currentHost, $targetDB, $ExceptionMessage)
                                    }
                                        
                                IF( ($dryRun -eq 0) -AND ($currentDeployID -ne 0) )
                                    {
                                        WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query `"$insertSQL`" "
                                        invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $insertSQL
                                    }
                            }
                        $serverCounter ++
                        WRITE-HOST "[ $serverCounter of $serverCount ] Instances"
                        WRITE-HOST " "
                    } #forEach Host
            }

#Print results in order of Success, Warning, Failure
#$ResultsTable | Sort-Object @{Expression = "OrderValue"}, @{Expression = "TargetInstance"}  | format-Table -Property targetInstance, targetDatabase, FinalResults -AutoSize  #ForEach-Object {$_.ItemArray[1] +" "+ $_.ItemArray[2]}
    $endTime = get-date -Format g
    #Print final Result of the script

    If($ResultsTable.Select("FinalResults LIKE '*FAILED*'").ItemArray -eq $null)
        {
            $FinalResultMessage = "*** SUCCESS ***"
            IF( $deployID -eq 0 ) #New Run
                {
                    $updateSQL = "UPDATE [deploy].[deploy] SET [deployEnd] = '"+ $endTime +"', [deployServerCount] = "+ $serverCount +", [deployStatus] = 'SUCCESS' WHERE deployID = "+ $currentDeployID +" AND deployStart = '"+ $startTime +"' and deployExecutedBy = '"+ $env:UserName +"'"
                }
            ELSE # OLD RUN RE-RUN - update endtime only
                {
                    $updateSQL = "UPDATE [deploy].[deploy] SET [deployEnd] = '"+ $endTime +"' WHERE deployID = "+ $currentDeployID
                }
        }
    Else
        {
            IF($ResultsTable.Select("OrderValue = 3").ItemArray -eq $null) # no level 3 failures means only warnings.
                {
                    $ResultsTable | where {$_.OrderValue -eq 2} | Sort-Object @{Expression = "OrderValue"}, @{Expression = "TargetInstance"}  | format-Table -Property @{Label="Final Results $cmsGroup"; Expression={ $_.FinalResults }} -WRAP  
                    $FinalResultMessage = "*** SUCCESS w/WARNING ***"
                    IF( $deployID -eq 0 ) #New Run
                        {
                            $updateSQL = "UPDATE [deploy].[deploy] SET [deployEnd] = '"+ $endTime +"', [deployServerCount] = "+ $serverCount +", [deployStatus] = 'WARNING' WHERE deployID = "+ $currentDeployID +" AND deployStart = '"+ $startTime +"' and deployExecutedBy = '"+ $env:UserName +"'"
                        }
                    ELSE # OLD RUN RE-RUN
                        {
                            $updateSQL = "UPDATE [deploy].[deploy] SET [deployEnd] = '"+ $endTime +"' WHERE deployID = "+ $currentDeployID
                        }                
                }
             ELSE #($ResultsTable.Select("OrderValue = 3").ItemArray -eq $null)
                {
                    $ResultsTable | where {$_.OrderValue -eq 3} | Sort-Object @{Expression = "OrderValue"}, @{Expression = "TargetInstance"}  | format-Table -Property @{Label="Final Results $cmsGroup"; Expression={ $_.FinalResults }} -WRAP  
                    $FinalResultMessage = "*** FAILURE ***"
                    IF( $deployID -eq 0 ) #New Run
                        {
                            $updateSQL = "UPDATE [deploy].[deploy] SET [deployEnd] = '"+ $endTime +"', [deployServerCount] = "+ $serverCount +", [deployStatus] = 'FAILURE' WHERE deployID = "+ $currentDeployID +" AND deployStart = '"+ $startTime +"' and deployExecutedBy = '"+ $env:UserName +"'"
                        }
                    ELSE # OLD RUN RE-RUN
                        {
                            $updateSQL = "UPDATE [deploy].[deploy] SET [deployEnd] = '"+ $endTime +"' WHERE deployID = "+ $currentDeployID
                        }
                }
        }

    WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $updateSQL "
    #Print Result Message
    WRITE-HOST $FinalResultMessage

    IF($dryRun -eq 1)
        {
            WRITE-HOST "[DryRun] Finished Deploying: $targetDB $targetHost $phase $cmsGroup  "
        }
    ELSE
        {
            WRITE-HOST "[] Finished Deploy: $currentDeployID $targetDB $targetHost $phase $cmsGroup "
            ## record in DBautomation database
            $status = $FinalResultMessage.replace("*","")
            IF( $force )
                {
                    WRITE-VERBOSE "Not Sending Email"
                }
            ELSE
                {
                    WRITE-HOST "[] Sending email to SLACK: "
                        sendemail-SLACK $deployServer $folder $repoVersion $phase $cmsGroup $status $currentDeployID $dryRun
                }

            IF( ($dryRun -eq 0) -AND ($currentDeployID -ne 0) )
                {
                    invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $updateSQL
                    IF( $deployID -eq 0 )
                        {
                            WRITE-VERBOSE "UPDATING NEW deploy information"
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "UPDATING OLD deploy information: $deployID"
                            $execSQL = 'EXEC [deploy].[reevaluateDeployResults] '+ $deployID
                            WRITE-VERBOSE "invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $execSQL "
                            invoke-sqlcmd -ServerInstance $deployServer -Database $deployDB -Query $execSQL
                        }
                }
        }
} #End of forEach folders 


 <#####################################################################
Purpose:  
     This script perfoem code deploys based on the defined AutoDB team phases. 
History:  
     20180301 hbrotherton W-4557656 CREATED
     YYYYMMDD USERID W-000000000 This is what I changed.
Comments:
     Anything you feel is important to share that is not the "purpose"
#######################################################################>
 
