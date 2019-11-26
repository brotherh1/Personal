 <#
	.\deployGitHubObjects.ps1 -targetDB "SnapBackupDB" -sourceRep "C:\SQL\SnapBackupDB-master" -targetHost "localhost\I1" -repoFolder "Auto"
    .\deployGitHubObjects.ps1 -targetDB "SQLmonitor" -targetHost "localhost\I1" -repoRoot "C:\Users\hbrotherton\myGit\Releases\SQLMonitor"  -repoFolder "StoredProcedure"
QA - no phases
    .\deployGitHubObjects.ps1 -targetDB "sqlmonitor" -currentDomain ".QA.LOCAL" -repoFolder "StoredProcedure"
 
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
        [string] $phase = "NA",  # staging(QA) "phase0","phase1","phase2"
        [string] $cmsGroup ="NA", 
		[string] $repoRoot="C:\Users\hbrotherton\myGit\Releases\"+ $targetDB,
        #[string] $repoRoot=".\Releases\"+ $targetDB,
		[string] $repoFolder= "Auto",
        [string] $currentDomain = "."+ $env:userDNSdomain,
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
    #$f_targetInstance = $f_targetHost.substring(0,$f_targetHost.IndexOf('\'))
    #$f_targetServer = $f_targetInstance + $f_domain
    #$selectSQL = "  select DB.name as dbName, DB.state_desc as dbState, SC.confValue as serverType 
    #                FROM [Utility].[dbo].[systemconfig] as SC
    #                CROSS JOIN sys.databases as DB
    #                where name = '"+ $f_targetDB +"' AND confKey = 'instance.ServerType'"

    $selectSQL = " select DB.name as dbName, DB.state_desc as dbState, IsNULL((Select SC.confValue
																                from [Utility].[dbo].[systemconfig] as SC
																                where  confKey = 'instance.ServerType'),'Not configured') as serverType
                    FROM  sys.databases as DB
                    where name = '"+ $f_targetDB +"'"

    WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $f_targetHost -Database MASTER  -ErrorAction SilentlyContinue -Query $selectSQL | select -exp dbName dbState serverType "
    TRY
        {
	        Invoke-Sqlcmd -ServerInstance $f_targetHost -Database MASTER  -ErrorAction SilentlyContinue -Query $selectSQL | select dbName, dbState, serverType
        }
    CATCH
        {
            $ExceptionMessage = "[FAILED - CONNECTION] .\deployGitHubObjects.ps1 -targetDB $f_targetDB -targetHost $f_targetHost -phase $f_phase -cmsGroup $f_cmsGroup -currentDomain $f_domain -dryRun $f_dryRun "
            [void]$ResultsTable.Rows.Add("3", $f_targetHost, $f_targetDB, $ExceptionMessage)
        }
#    FINALLY
#        {
             #Invoke-Sqlcmd -ServerInstance $f_targetHost -Database MASTER  -ErrorAction SilentlyContinue -Query $selectSQL | select dbName, dbState, serverType
#             $error
#        }
     
}

function checkStatus-Ping ( [string] $f_targetHost, [string] $f_domain )
{
    $f_targetInstance = $f_targetHost.substring(0,$f_targetHost.IndexOf('\'))
    #$f_targetServer = $f_targetInstance + $f_domain
    WRITE-VERBOSE "test-Connection -ComputerName $f_targetInstance -Count 2 -Quiet"
    test-Connection -ComputerName $f_targetInstance -Count 2 -Quiet  
     
}

Function CopyFiles-Somewhere ( [string] $FileName, [string] $f_targetHost, [string] $f_targetDB , [string] $f_folder, [string] $f_repoVersion , [int] $f_dryRun )
{
    IF($total -eq 0 -AND ($f_dryRun -eq 1 -OR $Verbose) )
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
                WRITE-HOST `t"Source Location: $f_sqlSourcePath"
                WRITE-HOST `t"Files to process: $total"
            }
        }
}

function process-Zipfile ( [string] $FileName, [string] $f_targetHost, [string] $f_targetDB , [string] $f_folder, [string] $f_repoVersion , [int] $f_dryRun )
{
    IF( $f_folder -eq "COPY" )
        {
            $databaseFolder = $f_targetDB +"\*"
        }
    ELSE
        {
            $databaseFolder = $f_targetDB +"\"+ $f_folder +"*"
        }
#    IF(Test-Path $FileName) 
#        {
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
#        }
#    ELSE
#        {
#            WRITE-WARNING "$FileName File path not found" 
#            EXIT
#        }

    IF($total -eq 0 -AND ($f_dryRun -eq 1 -OR $Verbose) )
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
            $failureCounter = 0

            $process = "Started"
            WHILE( $process -ne "Succesful" -AND $failureCounter -lt $total ) # AND attempts less than file count
            {
                $process = "Started"
                #WRITE-HOST "[$process] Attempt "
                #$count++

                foreach($object in $objArray) 
                {            
                    $currentFile = $object.FileName
                    IF($f_dryRun -eq 1 -OR $Verbose){ WRITE-HOST `t`t"File: $currentFile" }

                    #$fullPath = $object.ZipFileName +"\"+ $object.FullPath
                    #$fullPath = $object.FullPath
                    #WRITE-HOST "Full Path: $fullPath "

                    $zip = [IO.Compression.ZipFile]::OpenRead($FileName)
                    $file = $zip.Entries | where-object { $_.Name -eq $currentFile }
                    #WRITE-HOST "FILE: $file "

                    $stream = $file.Open()
                    $reader = New-Object IO.StreamReader($stream)
                    $text = $reader.ReadToEnd()
                    #$text

                    IF($f_dryRun -eq 0)
                        {
                            TRY
                                {
                                    WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB  -ErrorAction Stop -Query $text "
	                                Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB  -ErrorAction Stop -Query "$text" 
                                    IF($process -ne "FAILED"){ $Process = "Succesful" }
                                }
                            CATCH
                                {
                                    $displayCounter = $failureCounter + 1
                                    WRITE-HOST `t"[ALERT] !!! Something broke !!!  Attempt $displayCounter of $total "
                                    $process = "FAILED"
                                }
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB  -ErrorAction Stop -Query $text "
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
                    
                    $ExceptionMessage = "[FAILED] Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB  -ErrorAction Stop -InputFile $f_sqlSourcePath\$currentFile "
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

                    WRITE-VERBOSE `t"Invoke-Sqlcmd -ServerInstance $f_targetHost -Database UTILITY  -ErrorAction Stop -Query $execSQL"
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

}

function process-folder ( [string] $f_sqlSourcePath, [string] $f_targetHost, [string] $f_targetDB , [int] $f_dryRun)
{
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

    IF($total -eq 0 -AND ($f_dryRun -eq 1 -OR $Verbose) )
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
            IF($total -ne 0 -or $verbose )
            {
                WRITE-HOST `t"Source Location: $f_sqlSourcePath"
                WRITE-HOST `t"Files to process: $total"
                #WRITE-HOST " "
            }
           # $error = ""
            $failureCounter = 0

            $process = "Started"
            WHILE( $process -ne "Succesful" -AND $failureCounter -lt $total ) # AND attempts less than file count
            {
                $process = "Started"
                #WRITE-HOST "[$process] Attempt "

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
                                    WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB  -ErrorAction Stop -InputFile $sqlFile "
	                                Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB  -ErrorAction Stop -InputFile $sqlFile 
                                    IF($process -ne "FAILED"){ $Process = "Succesful" }
                                }
                            CATCH
                                {
                                    $displayCounter = $failureCounter + 1
                                    WRITE-HOST `t"[ALERT] !!! Something broke !!!  Attempt $displayCounter of $total "
                                    $process = "FAILED"
                                }
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB  -ErrorAction Stop -InputFile $f_sqlSourcePath\$currentFile "
                            IF($process -ne "FAILED"){ $Process = "Succesful" }
                        }
                } #end get-childItem
                WRITE-HOST " "
                $failureCounter ++
            } #end WHILE

            If( $process -eq "FAILED" )
                {
                    WRITE-HOST "[ALERT] Failure $failureCounter Total $total"
                    IF( ($failureCounter -eq $total) -AND $verbose) { $error }
                    
                    # No longer exiting - writing to data table to display at end.
                    #EXIT 
                    #[void]$ResultsTable.Rows.Add("3", $ExceptionMessage)
                    $ExceptionMessage = "[FAILED] Invoke-Sqlcmd -ServerInstance $f_targetHost -Database $f_targetDB  -ErrorAction Stop -InputFile $f_sqlSourcePath\$currentFile "
                    [void]$ResultsTable.Rows.Add("3", $f_targetHost, $f_targetDB, $ExceptionMessage)
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
#$count = 0
$total = 0
$filterExtenion = $filter.substring($filter.Length -4) 
IF( $filterExtenion -eq ".zip" ) { $repoRoot = $repoRoot + $filter }
$folderArray = @()
IF( $filterExtenion -eq ".ZIP" -and $targetDB -eq "" )
    {
        WRITE-HOST "[] No targetDB specified - gathering all root folders in repo.zip: $repoRoot "
        #$folderArray = @() 
        $rawFolders = [IO.Compression.ZipFile]::OpenRead($repoRoot).Entries
        ForEach( $rawFolder in $rawFolders )
            { 
                $currentFolder = $rawFolder.FullName
                #$currentFolder
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
                        WRITE-VERBOSE ".\deployGitHubObjects.ps1 -targetDB $folder -filter $filter -repoRoot $repoRoot -repoFolder $repoFolder  -phase $phase -cmsGroup $cmsGroup -dryRun $dryRun"
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

            $level2Groups = @( "ActiveBatch","Admin","commVault","Confio","DBA01","DBrestores","DataWarehouse","MediaServers","StandbyMgr","DBA01MAchines","Templates" )
            $level3Groups = @( "Unused" )
            $level4Groups = @( "Build","Standby" ) #All Live Stack DBs are in level 4.
            $phase1Groups = @( "Stack2", "Stack4", "Stack10" )
            $phase2Groups = @( "Stack1", "Stack5", "Stack6", "Stack7" )

            If( ($targetDB -eq "Utility") -OR ($targetDB -eq "worktableDB") )
                {
                    switch ($phase) 
                    {
                        ### BAD NAMING - no "AUTO-"
                        {($_ -eq "phase0" ) -AND ($cmsGroup -eq "DBA01MAchines")} {  
                                                                                    WRITE-VERBOSE "Phase0 - level 1";
                                                                                    $selectSQL = "  select t.name AS [Parent Name], Grps.name AS [Group Name], '"+ $cmsGroup +"' AS [Stack Name], Srv.name AS [Display Name], 
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
                                                                                    $selectSQL = "  select t.name AS [Parent Name], Grps.name AS [Group Name], '"+ $cmsGroup +"' AS [Stack Name], Srv.name AS [Display Name], 
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
                                                                                    $selectSQL = "  select t.name AS [Parent Name], Grps.name AS [Group Name], pod.Name AS [Stack Name], Srv.name AS [Display Name], 
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
                                                                                    $selectSQL = "  select t.name AS [Parent Name], Grps.name AS [Group Name], stack.Name AS [Stack Name], Srv.name AS [Display Name], 
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
                                                                                $selectSQL = "  select t.name AS [Parent Name], Grps.name AS [Group Name], stack.Name AS [Stack Name], Srv.name AS [Display Name], 
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
                                                                                    $selectSQL = "  select t.name AS [Parent Name], Grps.name AS [Group Name], stack.Name AS [Stack Name], Srv.name AS [Display Name], 
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
                                                                                    $selectSQL = "  select t.name AS [Parent Name], Grps.name AS [Group Name], stack.Name AS [Stack Name], Srv.name AS [Display Name], 
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
            ELSEIF( $targetDB -eq "SQLmonitor")
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
        #$phaseGroups = @("QA")

        If( ($targetDB.ToUpper() -eq "UTILITY") -OR ($targetDB.ToUpper() -eq "WORKTABLEDB") )
            {
                $selectSQL = "  select t.name AS [Parent Name], Grps.name AS [Group Name], Stack.name AS [Stack Name], Srv.name AS [Display Name], 
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
        ELSEIF( $targetDB.ToUpper() -eq "SQLMONITOR")
            {   
                WRITE-VERBOSE "SQLmonitor - Not in Inventory - hard coded";
                #$selectSQL = "select FQDN from [dbo].[instance] where InstanceID in ( SELECT hostInstance FROM [Database] where databasename like '"+ $targetDB +"' ) and isOn = 1"
                $targetHost = "IND2Q00DBA01.qa.local\i1" 
            }
        ELSEIF( $targetDB.ToUpper() -eq "STANDARDJOBS" )
            {
                $targetHost = $scriptNinjaInst
            }
        ELSE
            {
                WRITE-VERBOSE "$targetDB - $cmsGroup";
                $selectSQL = "select FQDN from [dbo].[instance] where InstanceID in ( SELECT hostInstance FROM [Database] where databasename like '"+ $targetDB +"' ) and isOn = 1"
                #$cmsDB = "sqlMonitor"
                $targetCMS = "IND2Q00DBA01.QA.LOCAL\I1" #SQLmonitor instance
            }
        WRITE-VERBOSE "Target CMS: $targetCMS "
        WRITE-VERBOSE "TargetInvDB: $targetInvDB "
        WRITE-VERBOSE "ScriptNinja UNC: $scriptNinjaPath "
    }
    ELSEIF( ($currentDomain -eq '.XT.LOCAL' -OR $currentDomain -eq '.QA.LOCAL') -AND ($phase -eq "NA" -or $phase -eq "NA" ) )
                        {
        WRITE-HOST "[!!]                                               [!!]"
        WRITE-HOST "[!!] Standalone deploy - targeting single instance [!!]"
        WRITE-HOST "[!!]                                               [!!]"
    }
    ELSE
        {
            WRITE-HOST "[ALERT] $currentDomain not supported - Please log into a QA or PROD host."; EXIT
        }

    WRITE-HOST "[] Working Domain: $currentDomain "
    WRITE-HOST "[] Target INV Server: $targetInvServer "
    WRITE-HOST "[] Inv Database: $targetInvDB "
    WRITE-HOST "[] Target DB: $targetDB"

    IF($targetHost -ne ""){ WRITE-HOST "[] Target Host: $targetHost " }
    IF($targetDB -ne ""  ){ WRITE-HOST "[] Target DB: $targetDB " }

    WRITE-HOST "[] Phase: $phase "
    WRITE-HOST "[] CMS Group: $cmsGroup "
    WRITE-HOST "[] Filter: $filterExtenion "
    WRITE-HOST "[] DryRun: $dryRun "
    WRITE-VERBOSE ".\deployGitHubObjects.ps1 -targetDB $folder -filter $filter -repoRoot $repoRoot -repoFolder $repoFolder  -phase $phase -cmsGroup $cmsGroup -dryRun $dryRun" 
    WRITE-HOST " "

#  This is a place holder if we were wanting to cycle through all phase0 groups
#ForEach ( $group in $phaseGroups )
#    {



        IF($targetHost -eq "")
            {
                WRITE-HOST "[] No target instance supplied - looking at inventory"
                #$selectSQL
                WRITE-VERBOSE `t"invoke-sqlcmd -ServerInstance $targetCMS -Database master -Query $selectSQL "
                $hostList = @( invoke-sqlcmd -ServerInstance $targetCMS -Database master -Query $selectSQL | select -exp FQDN )
            }
        ELSE
            {
                WRITE-HOST "[] Target instance supplied "
                $hostList = $targetHost
            }
        IF( $dryRun -eq 1 ){ ForEach( $currenthost in $hostList){ WRITE-HOST `t" $currenthost"; WRITE-HOST " " } }

        IF( $targetDB.ToUpper() -eq "STANDARDJOBS" )
            {
                
                WRITE-HOST "[] CopyFiles"
                WRITE-HOST `t"Copy to Standard location used by baseline:  $scriptNinjaPath\StandardJobScript "
                process-zipFile "$repoRoot\COPY" $currentHost $folder $targetDB $repoVersion $dryRun
                
                WRITE-HOST `t"Copt to location used by ScriptNinja: $scriptNinjaPath\IBtest "
                process-zipFile "$repoRoot\COPY" $currentHost $folder $targetDB $repoVersion $dryRun

            }
        ELSE
            {
        
                ForEach ( $currentHost in $hostList)
                    {
                        WRITE-HOST "[] Ping Test: $currentHost "
                        IF( checkStatus-Ping $currentHost $currentDomain ) 
                            {
                                WRITE-HOST "[] DB Test: $targetDB "
                                $targetDBInfo = @( checkStatus-online $currentHost $targetDB $f_phase $f_cmsGroup $dryRun )
                                #$targetDBInfo.dbName 
                                #$targetDBInfo.dbState 
                                #$targetDBInfo.serverType
                                #$targetDBInfo.Count
                                IF( ($targetDBInfo.dbState -ne "RESTORING") -AND ($targetDBInfo.serverType -ne "Restore") -AND ($targetDBInfo.Count -ne 0) )
                                    {
                                        IF( $filterExtenion -eq ".sql" )
                                            {
                                                WRITE-HOST "[] Processing: TSQL"
                                                WRITE-VERBOSE ".\deployGitHubObjects.ps1 -targetDB $targetDB -targetHost $currentHost -phase $phase -cmsGroup $cmsGroup -currentDomain $currentDomain -dryRun $dryRun"
                                                If( $repoFolder -eq "Auto" )
                                                    {	
                                                        If( $folder -eq "StandardJobs" )
                                                            {
                                                                process-zipFile "$repoRoot\COPY" $currentHost $folder $targetDB $repoVersion $dryRun
                                                            }
                                                        ELSE
                                                            {
                                                                process-Folder "$repoRoot\Role" $currentHost $targetDB $dryRun
                                                                process-Folder "$repoRoot\Schema" $currentHost $targetDB $dryRun
                                                                process-Folder "$repoRoot\Table" $currentHost $targetDB $dryRun
                                                                process-Folder "$repoRoot\View" $currentHost $targetDB $dryRun 
                                                                process-Folder "$repoRoot\Type" $currentHost  $targetDB $dryRun	
                                                                process-Folder "$repoRoot\Synonym" $currentHost $targetDB $dryRun
                                                                process-Folder "$repoRoot\UserDefinedFunction" $currentHost $targetDB $dryRun
                                                                process-Folder "$repoRoot\StoredProcedure" $currentHost $targetDB $dryRun
                                                                process-Folder "$repoRoot\Init" $currentHost $targetDB $dryRun
                                                                process-Folder "$repoRoot\AgentJob" $currentHost $targetDB $dryRun
                                                            }
                                                    }
                                                ELSE
                                                    {
                                                        Process-Folder "$repoRoot\$repoFolder" $currentHost $targetDB $dryRun
                                                    }
                                             }
                                        ELSEIf( $filterExtenion -eq ".zip")
                                            {
                                                $repoVersion = $filter.replace(".ZIP", "" )
                                                WRITE-HOST "[] Processing: PowerShell - $repoRoot "
                                                WRITE-VERBOSE ".\deployGitHubObjects.ps1 -targetDB $targetDB -targetHost $currentHost -phase $phase -cmsGroup $cmsGroup -currentDomain $currentDomain -dryRun $dryRun"
                                                IF(Test-Path $repoRoot) 
                                                    {
                                                        If($repoFolder -eq "Auto" -AND $targetDB -eq "" )
                                                            {	
                                                                #WRITE-HOST "[] No Folder specified - gathering all root folders in repo"
                                                                #$folderArray = @() 
                                                                #$rawFolders = [IO.Compression.ZipFile]::OpenRead($repoRoot).Entries
                                                                ForEach( $rawFolder in $rawFolders )
                                                                    { 
                                                                        $currentFolder = $rawFolder.FullName
                                                                        #$currentFolder
                                                                        $rootFolder = $currentFolder.Substring(0,$currentFolder.IndexOf("\"))
                                                                        #$rootFolder

                                                                        IF($folderArray.Contains($rootFolder) -eq $false) 
                                                                            {
                                                                               $folderArray += $rootFolder
                                                                            }
                                                                    }
                                                ##  IF $targetDB is null process entire zipfile $folder....

                                                                ForEach( $folder in $folderArray )
                                                                    {
                                                                        If( $folder -eq "StandardJobs" )
                                                                            {
                                                                                process-zipFile "$repoRoot" $currentHost $folder "COPY" $repoVersion $dryRun
                                                                            }
                                                                        ELSE
                                                                            {
                                                                                process-zipFile "$repoRoot" $currentHost $folder "Role" $repoVersion $dryRun
                                                                                process-zipFile "$repoRoot" $currentHost $folder "Schema" $repoVersion $dryRun
                                                                                process-zipFile "$repoRoot" $currentHost $folder "Table" $repoVersion $dryRun
                                                                                process-zipFile "$repoRoot" $currentHost $folder "View" $repoVersion $dryRun 
                                                                                process-zipFile "$repoRoot" $currentHost $folder "Type" $repoVersion $dryRun	
                                                                                process-zipFile "$repoRoot" $currentHost $folder "Synonym" $repoVersion $dryRun
                                                                                process-zipFile "$repoRoot" $currentHost $folder "UserDefinedFunction" $repoVersion $dryRun
                                                                                process-zipFile "$repoRoot" $currentHost $folder "StoredProcedure" $repoVersion $dryRun
                                                                                process-zipFile "$repoRoot" $currentHost $folder "Init" $repoVersion $dryRun
                                                                                process-zipFile "$repoRoot" $currentHost $folder "AgentJob" $repoVersion $dryRun
                                                                            }
                                                                    }
                                                            }
                                                        ELSEIf($repoFolder -eq "Auto" -AND $targetDB -ne "" )
                                                            {	
                                                                    process-zipFile "$repoRoot" $currentHost $targetDB "Role" $repoVersion $dryRun
                                                                    process-zipFile "$repoRoot" $currentHost $targetDB "Schema" $repoVersion $dryRun
                                                                    process-zipFile "$repoRoot" $currentHost $targetDB "Table" $repoVersion $dryRun
                                                                    process-zipFile "$repoRoot" $currentHost $targetDB "View" $repoVersion $dryRun 
                                                                    process-zipFile "$repoRoot" $currentHost $targetDB "Type" $repoVersion $dryRun	
                                                                    process-zipFile "$repoRoot" $currentHost $targetDB "Synonym" $repoVersion $dryRun
                                                                    process-zipFile "$repoRoot" $currentHost $targetDB "UserDefinedFunction" $repoVersion $dryRun
                                                                    process-zipFile "$repoRoot" $currentHost $targetDB "StoredProcedure" $repoVersion $dryRun
                                                                    process-zipFile "$repoRoot" $currentHost $targetDB "Init" $repoVersion $dryRun
                                                                    process-zipFile "$repoRoot" $currentHost $targetDB "AgentJob" $repoVersion $dryRun
                                                            }
                                                        ELSE
                                                            {
                                                                process-zipFile "$repoRoot" $currentHost $targetDB "$repoFolder" $repoVersion $dryRun
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
                                                WRITE-VERBOSE ".\deployGitHubObjects.ps1 -targetDB $targetDB -targetHost $currentHost -phase $phase -cmsGroup $cmsGroup -currentDomain $currentDomain -dryRun $dryRun"
                                                If($repoFolder -eq "Auto")
                                                    {	
                                                        processFolder "$repoRoot\Scripts" $currentHost $targetDB $dryRun
                                                    }
                                                ELSE
                                                    {
                                                        ProcessFolder "$repoRoot\$repoFolder" $currentHost $targetDB $dryRun
                                                    }
                                            }
                                    }
                                ELSEIF( ($targetDBInfo.dbState -eq "RESTORING") -AND ($targetDBInfo.serverType -eq "Restore") -AND ($targetDBInfo.Count -ne 0)  )
                                    {
                                        WRITE-HOST "[SKIP] Target Host is of Type RESTORE and target DB is in state RESTORING"
                                    }
                                ELSE
                                    {
                                        WRITE-HOST "[ALERT] TargetDatabase does not exist - if it should we need to log a ticket with DBOps. "
                                        $ExceptionMessage = "[FAILED - missing $targetDB] .\deployGitHubObjects.ps1 -targetDB $targetDB -targetHost $currentHost -phase $phase -cmsGroup $cmsGroup -currentDomain $currentDomain -dryRun $dryRun "
                                        [void]$ResultsTable.Rows.Add("3", $f_targetHost, $targetDB, $ExceptionMessage)
                                    }
                            }
                        ELSE
                            {
                                WRITE-HOST `t`t"[ALERT] FAILED TO CONNECT - logging Failure"
                                $ExceptionMessage = "[FAILED - PING] .\deployGitHubObjects.ps1 -targetDB $targetDB -targetHost $currentHost -phase $phase -cmsGroup $cmsGroup -currentDomain $currentDomain -dryRun $dryRun "
                                [void]$ResultsTable.Rows.Add("3", $f_targetHost, $targetDB, $ExceptionMessage)
                            }

                    } #forEach Host
            }

#Print results in order of Success, Warning, Failure
#$ResultsTable | Sort-Object @{Expression = "OrderValue"}, @{Expression = "TargetInstance"}  | format-Table -Property targetInstance, targetDatabase, FinalResults -AutoSize  #ForEach-Object {$_.ItemArray[1] +" "+ $_.ItemArray[2]}

    #Print final Result of the script
    If($ResultsTable.Select("FinalResults LIKE '*FAILED*'").ItemArray -eq $null)
        {
            $FinalResultMessage = "`n*** SUCCESS ***"
        }
    Else
        {
            $ResultsTable | where {$_.OrderValue -eq 3} | Sort-Object @{Expression = "OrderValue"}, @{Expression = "TargetInstance"}  | format-Table -Property @{Label="Final Results $cmsGroup"; Expression={ $_.FinalResults }} -WRAP  
            $FinalResultMessage = "`n*** FAILURE ***"
        }
    #Print Result Message
    WRITE-HOST `t$FinalResultMessage

    IF($dryRun -eq 1)
        {
            WRITE-HOST "[DryRun] Finished Deploying: $targetDB $targetHost $phase cmsGroup $cmsGroup "
        }
    ELSE
        {
            WRITE-HOST "[] Finished Deploying: $targetDB $targetHost $phase cmsGroup $cmsGroup "
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
 
