FUNCTION Import-SqlModule 
{
    <#
    .SYNOPSIS
        Imports the SQL Server PowerShell module or snapin.
    .DESCRIPTION
        Import-MrSQLModule is a PowerShell function that imports the SQLPS PowerShell
        module (SQL Server 2012 and higher) or adds the SQL PowerShell snapin (SQL
        Server 2008 & 2008R2).
    .EXAMPLE
         Import-SqlModule
    #>
        [CmdletBinding()]
        param ()
        TRY
            {
                $PolicyState=0
                if (-not(Get-Module -Name SQLPS) -and (-not(Get-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100 -ErrorAction SilentlyContinue))) {
                Write-Verbose -Message 'SQLPS PowerShell module or snapin not currently loaded'
                    if (Get-Module -Name SQLPS -ListAvailable) {
                        Write-Verbose -Message 'SQLPS PowerShell module found'
                        Push-Location
                        Write-Verbose -Message "Storing the current location: '$((Get-Location).Path)'"
                        if ((Get-ExecutionPolicy) -ne 'Restricted') {
                            Import-Module -Name SQLPS -DisableNameChecking -Verbose:$false
                            Write-Verbose -Message 'SQLPS PowerShell module successfully imported'
                        }
                        else{
                            Write-Warning -Message 'The SQLPS PowerShell module cannot be loaded with an execution policy of restricted'
                        }
                        Pop-Location
                        Write-Verbose -Message "Changing current location to previously stored location: '$((Get-Location).Path)'"
                    }
                    elseif (Get-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100 -Registered -ErrorAction SilentlyContinue) {
                        Write-Verbose -Message 'SQL PowerShell snapin found'
                        Add-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100
                        Write-Verbose -Message 'SQL PowerShell snapin successfully added'
                        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo') | Out-Null
                        Write-Verbose -Message 'SQL Server Management Objects .NET assembly successfully loaded'
                    }
                    else {
                        Write-Warning -Message 'SQLPS PowerShell module or snapin not found'
                    }
                }
                else {
                    Write-Verbose -Message 'SQL PowerShell module or snapin already loaded'
                }
    
            }
        CATCH
            {
                WRITE-VERBOSE "Add-PSSnapin Exception"
                $PolicyState = 2
                $returnObject = New-Object PSObject -Property @{
                        ErrorDetail = 'Add-PSSnapin Exception'
                    }
                $policystate
                $returnObject
                BREAK;
            }

    RETURN     $PolicyState
}

FUNCTION Check-HostPing ( [string] $f_targetHost, [string] $f_domain )
{
    $f_targetInstance = $f_targetHost.substring(0,$f_targetHost.IndexOf('\')) + $f_domain
    test-Connection -ComputerName $f_targetInstance -Count 2 -Quiet       
}

FUNCTION fetch-sourceList
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [string] $f_startDate,
		    [string] $f_invDB = "SQLmonitor",
		    [string] $f_invServer = "XTINOPSD2\I2",
            [string] $f_whereStatement,
            [string] $sourceType,
            [switch] $Custom
        )
<#
    $searchSQL = "SELECT distinct server_name, database_name
                    FROM [SQLMonitor].[dbo].[BackupInfo]
                    where (database_name like 'ExactTarget%' or database_name like 'ET%') AND database_name != 'ETManage'
	                AND description != 'Ally DR - Full Backup' and server_name not like '%cb%' AND physical_device_name NOT like '%Restores%'
	                    AND type = 'D'	AND backup_start_date > '"+ $f_startDate +"'
                          "
  #>   
  
    If( $sourceType -eq 'Full' )
        {                     
            $searchSQL = "SELECT distinct server_name, database_name
                          FROM [SQLMonitor].[dbo].[BackupInfo]
                          WHERE "+ $f_whereStatement +" 
	                            AND description != 'Ally DR - Full Backup' and server_name not like '%cb%' AND physical_device_name NOT like '%Restores%'
                                AND database_name not in ('WorkTableDB', 'Utility', 'master', 'model', 'msdb', 'tempdb')
	                            AND type = 'D'	AND backup_start_date > '"+ $f_startDate +"' "
        }
    ELSE
        {
            $searchSQL = "SELECT inst.InstanceName as server_name, db.[DatabaseName] as database_name 
                          FROM [SQLMonitor].[dbo].[Database] AS db join [SQLMonitor].[dbo].[instance] AS inst ON (db.hostInstance = inst.InstanceID)
                          WHERE "+ $f_whereStatement +"
                            AND db.[IsStandby] != 1 AND (db.[isONline] = 1 AND db.[IsProduction] = 1) "
        }

    WRITE-VERBOSE $searchSQL

    $dbOBJ = Invoke-Sqlcmd -ServerInstance $f_invServer -Database $f_invDB -Query $searchSQL -QueryTimeout 65535

    return $dbOBJ
}

FUNCTION fetch-backupInfo
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [string] $f_startDate,
            [string] $f_endDate,
		    [string] $f_targetServer,
            [string] $f_targetDatabase,
            [switch] $Custom
        )
 
    $selectSQL = "select
	                @@SERVERNAME as InstanceName,
	                buset.database_name, 
	                buset.type,
	                bmf.physical_device_name,
	                bmf.mirror,
	                buset.backup_set_id,
	                buset.first_lsn,
	                buset.last_lsn,
	                buset.checkpoint_lsn,
	                buset.database_backup_lsn,
	                buset.backup_start_date,
	                buset.backup_finish_date 
	                from msdb.dbo.backupset buset 
		                join msdb.dbo.backupmediaset bmset on buset.media_set_id = bmset.media_set_id
		                join msdb.dbo.backupmediafamily bmf on buset.media_set_id = bmf.media_set_id
		            WHERE buset.database_name = '"+ $f_targetDatabase +"' AND buset.backup_start_date > '"+ $f_startDate +"'"
    IF( $f_endDate -ne '' )
    {
        $selectSQL = $selectSQL + " AND buset.backup_finish_date <= '"+ $f_endDate +"' "
    }

    $selectSQL = $selectSQL + "
		                and database_name not in ('WorkTableDB', 'Utility', 'master', 'model', 'msdb', 'tempdb')
		                order by buset.backup_start_date asc
                "
    WRITE-VERBOSE $selectSQL

    $dbOBJ = Invoke-Sqlcmd -ServerInstance $f_targetServer -Database MSDB -Query $selectSQL -QueryTimeout 65535

    return $dbOBJ
}

FUNCTION fetch-cvJobInfo
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [string] $f_startDate,
            [string] $f_endDate,
		    [string] $f_targetServer,
            [string] $f_targetDatabase,
            [switch] $Custom
        )
 
    $selectSQL = "SELECT  
                    JobID, clientname AS MAServer, @@SERVERNAME AS CommServer, SubClient, JobStatus, StartDate, EndDate, numbytesuncomp/(1024*1024) AS SizeMB, 
                    numobjects AS ObjectCount, RetentionDays, CAST(dateadd(dd, CAST(RetentionDays AS int), StartDate)AS Date) AS ExpirationDate
                    FROM [CommServ].[dbo].[CommCellBackupInfo] bi
                      where bi.clientname like '%MA%' and bi.idataagent not in ('Virtual Server')
                      and SubClient not like 'Splunk%'
                      AND startdate >= '"+ $f_startDate +"'
                      order by bi.startdate desc"
    WRITE-VERBOSE $selectSQL

    $dbOBJ = Invoke-Sqlcmd -ServerInstance $f_targetServer -Database MSDB -Query $selectSQL -QueryTimeout 65535

    return $dbOBJ
}

FUNCTION insert-backupInfo
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [object[]] $f_backupInfo,
            [string] $f_dwhTable,
		    [string] $f_dwhDB,
		    [string] $f_dwhServer,
            [switch] $Custom
        )

    ForEach($row in $f_backupInfo)
    {
        $insertSQL = "INSERT INTO "+ $f_dwhTable +" (InstanceName, DBName, BackupType,BackupLocation, BackupMirror, BackupSetID, FirstLSN, LastLSN, CheckpointLSN, DatabaseBackupLSN, BackupStartDate, BackupFinishDate ) 
            VALUES 
          ('$($row.InstanceName)','$($row.database_name)','$($row.type)','$($row.physical_device_name)',$($row.mirror),$($row.backup_set_id),$($row.first_lsn),$($row.last_lsn),$($row.checkpoint_lsn),$($row.Database_Backup_LSN),'$($row.Backup_Start_Date)','$($row.Backup_Finish_Date)' )"

        WRITE-VERBOSE $insertSQL

        Invoke-Sqlcmd -ServerInstance $f_dwhServer -Database $f_dwhDB -Query $insertSQL -QueryTimeout 65535
    }

}

FUNCTION insert-cvJobInfo
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [object[]] $f_backupInfo,
            [string] $f_dwhTable,
		    [string] $f_dwhDB,
		    [string] $f_dwhServer,
            [switch] $Custom
        )

    ForEach($row in $f_backupInfo)
    { 
        $insertSQL = "INSERT INTO "+ $f_dwhTable +"  ([JobID],[MAServer],[CommServer],[SubClient],[JobStatus],[StartDate],[EndDate],[SizeMB],[ObjectCount],[RetentionDays],[ExpirationDate],[ProcessStatus],[ProcessDate])
            VALUES
               ('$($row.JobID)','$($row.MAServer)','$($row.CommServer)','$($row.SubClient)','$($row.JobStatus)','$($row.StartDate)','$($row.EndDate)',$($row.SizeMB),$($row.ObjectCount),$($row.RetentionDays),'$($row.ExpirationDate)',0,'')"

        WRITE-VERBOSE $insertSQL

        Invoke-Sqlcmd -ServerInstance $f_dwhServer -Database $f_dwhDB -Query $insertSQL -QueryTimeout 65535
    }

}
#################################################
FUNCTION process-fullBackups
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [string] $startDate = '8/1/2018',
            [string] $endDate = '',
            [string] $whereStatement,
		    [string] $invDB = "SQLmonitor",
		    [string] $invServer = "XTINOPSD2\I2",
		    [string] $dwhtable = "BackupHistoryFiles",
		    [string] $dwhDB = "DBA",
		    [string] $dwhServer = "XTINP1DBA01\DBADMIN",
            [boolean] $SuppressDetail,
            [switch] $customVerbose
            )

    $processStartDate = get-Date
    $Domain = "."+ $env:userDNSdomain.Replace("CT.","")

    WRITE-VERBOSE "[] Inv DB: $invDB"
    WRITE-VERBOSE "[] Inv Server: $invServer"
    WRITE-VERBOSE "[] "
    WRITE-VERBOSE "[] DWH table: $dwhtable"
    WRITE-VERBOSE "[] DWH DB: $dwhDB"
    WRITE-VERBOSE "[] DWH Server: $dwhServer"
    WRITE-VERBOSE "[] "
    WRITE-VERBOSE "[] Start Date: $startDate"

    IF( $endDate -ne '' )
        {
             WRITE-VERBOSE "[] End Date: $endDate"
        }

    ## GET SOURCE(S)
    $sourceList =  fetch-sourceList $startDate $invDB $invServer $whereStatement 'FULL' -Custom:$CustomVerbose -whatif | Sort-Object -Property server_name

    $counter = 1
    ForEach( $sourceInstance in $sourceList)
        {
            WRITE-VERBOSE "Processing: $($sourceInstance.server_name) $($sourceInstance.database_name) [$($counter)/$($sourceList.server_name.Count)]"
            WRITE-VERBOSE "[] Sanity check - Check-HostPing $($sourceInstance.server_name) $domain"
            if ( Check-HostPing $sourceInstance.server_name $domain ) 
                {
                    IF( $endDate -eq '' )
                        {
                            WRITE-VERBOSE "`t Check DWH table for MAX date"
                                $selectSQL = "select IsNULL(MAX(BackupStartDate),'$($startDate)') as MaxDate FROM "+ $dwhtable +" WHERE InstanceName = '$($sourceInstance.server_name)' and dbName = '$($sourceInstance.database_name)'"
	                            WRITE-VERBOSE $selectSQL

                                $InstanceMaxDate = Invoke-Sqlcmd -ServerInstance $dwhServer -Database $dwhDB -Query $selectSQL -QueryTimeout 65535 | SELECT -exp MaxDate
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "`t Searching Date Range $($startDate) to $($endDate)"
                            $InstanceMaxDate = $startDate
                        }
            
                    WRITE-VERBOSE "`t Fetch Backup Info for $($sourceInstance.server_name) after $($InstanceMaxDate)"
                    $backupInfo =  fetch-backupInfo $InstanceMaxDate $endDate $sourceInstance.server_name $sourceInstance.database_name -Custom:$CustomVerbose -whatif
                    #$backupInfo | Format-Table -Auto

                    WRITE-VERBOSE "`t Insert New data into DWH"
                    insert-backupInfo $backupInfo $dwhTable $dwhDB $dwhServer -Custom:$CustomVerbose -whatif

                }
             ELSE
                {  
                    WRITE-VERBOSE "[WARNING] Cluster $($sourceInstance.server_name)$domain is not Pinging"
                    <#WRITE-VERBOSE "`t`t Check inventory if decomm requested based on serverDescription like '%Cluster Decomm requested W%'"
                    $selectSQL = "SELECT ServerDescription  FROM [DBA].[dbo].[ExactTargetSQLInstallations] WHERE SQLServerName = '$($instance.Name)' AND serverDescription like '%Cluster Decomm W%'"

                    $ServerDescription = $null
                    $ServerDescription = Invoke-Sqlcmd -ServerInstance $targetInvServer -Database $targetInvDB -Query $selectSQL -QueryTimeout 65535 | select -EXP ServerDescription

                    If( $ServerDescription.Count -eq 0 )
                        {
                            WRITE-VERBOSE "[ALERT] TARGET $($Target)$domain is not Pinging - check SQL network name and inventory."
                            RETURN;
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "[OK] Cluster is being decommisioned: $($ServerDescription)"
                            RETURN;
                        }#>
                }

            $counter = $counter+1
        }#  ForEach( $sourceInstance in $sourceList)


    WRITE-VERBOSE "[] Database_Name: $whereStatement"
    WRITE-VERBOSE "[] Start Search: $startDate"

    IF( $endDate -ne '' )
        {
             WRITE-VERBOSE "[] End Search: $endDate"
        }
    WRITE-VERBOSE "[] Process Start: $($processStartDate)"
    WRITE-VERBOSE "[] Process End: $(get-date)"
}
#################################################
FUNCTION process-allETbackups
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [string] $startDate = '8/1/2018',
            [string] $endDate = '',
            [string] $whereStatement = "[DatabaseName] like 'ExactTarget%'",
		    [string] $invDB = "SQLmonitor",
		    [string] $invServer = "XTINOPSD2\I2",
		    [string] $dwhtable = "BackupHistoryFiles",
		    [string] $dwhDB = "DBA",
		    [string] $dwhServer = "XTINP1DBA01\DBADMIN",
            [boolean] $SuppressDetail,
            [switch] $customVerbose
            )

    $processStartDate = get-Date
    $Domain = "."+ $env:userDNSdomain.Replace("CT.","")

    WRITE-VERBOSE "[] Inv DB: $invDB"
    WRITE-VERBOSE "[] Inv Server: $invServer"
    WRITE-VERBOSE "[] "
    WRITE-VERBOSE "[] DWH table: $dwhtable"
    WRITE-VERBOSE "[] DWH DB: $dwhDB"
    WRITE-VERBOSE "[] DWH Server: $dwhServer"
    WRITE-VERBOSE "[] "
    WRITE-VERBOSE "[] Start Date: $startDate"

    IF( $endDate -ne '' )
        {
             WRITE-VERBOSE "[] End Date: $endDate"
        }

    ## GET SOURCE(S)
    $sourceList =  fetch-sourceList $startDate $invDB $invServer $whereStatement 'LOG' -Custom:$CustomVerbose -whatif | Sort-Object -Property server_name

    $counter = 1
    ForEach( $sourceInstance in $sourceList)
        {
            WRITE-VERBOSE "Processing: $($sourceInstance.server_name) $($sourceInstance.database_name) [$($counter)/$($sourceList.server_name.Count)]"
            WRITE-VERBOSE "[] Sanity check - Check-HostPing $($sourceInstance.server_name) $domain"
            if ( Check-HostPing $sourceInstance.server_name $domain ) 
                {
                    IF( $endDate -eq '' )
                        {
                            WRITE-VERBOSE "`t Check DWH table for MAX date"
                                $selectSQL = "select IsNULL(MAX(BackupStartDate),'$($startDate)') as MaxDate FROM "+ $dwhtable +" WHERE InstanceName = '$($sourceInstance.server_name)' and dbName = '$($sourceInstance.database_name)'"
	                            WRITE-VERBOSE $selectSQL

                                $InstanceMaxDate = Invoke-Sqlcmd -ServerInstance $dwhServer -Database $dwhDB -Query $selectSQL -QueryTimeout 65535 | SELECT -exp MaxDate
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "`t Searching Date Range $($startDate) to $($endDate)"
                            $InstanceMaxDate = $startDate
                        }
            
                    WRITE-VERBOSE "`t Fetch Backup Info for $($sourceInstance.server_name) after $($InstanceMaxDate)"
                    $backupInfo =  fetch-backupInfo $InstanceMaxDate $endDate $sourceInstance.server_name $sourceInstance.database_name -Custom:$CustomVerbose -whatif
                    #$backupInfo | Format-Table -Auto

                    WRITE-VERBOSE "`t Insert New data into DWH"
                    insert-backupInfo $backupInfo $dwhTable $dwhDB $dwhServer -Custom:$CustomVerbose -whatif

                }
             ELSE
                {  
                    WRITE-VERBOSE "[WARNING] Cluster $($sourceInstance.server_name)$domain is not Pinging"
                    <#WRITE-VERBOSE "`t`t Check inventory if decomm requested based on serverDescription like '%Cluster Decomm requested W%'"
                    $selectSQL = "SELECT ServerDescription  FROM [DBA].[dbo].[ExactTargetSQLInstallations] WHERE SQLServerName = '$($instance.Name)' AND serverDescription like '%Cluster Decomm W%'"

                    $ServerDescription = $null
                    $ServerDescription = Invoke-Sqlcmd -ServerInstance $targetInvServer -Database $targetInvDB -Query $selectSQL -QueryTimeout 65535 | select -EXP ServerDescription

                    If( $ServerDescription.Count -eq 0 )
                        {
                            WRITE-VERBOSE "[ALERT] TARGET $($Target)$domain is not Pinging - check SQL network name and inventory."
                            RETURN;
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "[OK] Cluster is being decommisioned: $($ServerDescription)"
                            RETURN;
                        }#>
                }

            $counter = $counter+1
        }#  ForEach( $sourceInstance in $sourceList)


    WRITE-VERBOSE "[] Database_Name: $whereStatement"
    WRITE-VERBOSE "[] Start Search: $startDate"

    IF( $endDate -ne '' )
        {
             WRITE-VERBOSE "[] End Search: $endDate"
        }
    WRITE-VERBOSE "[] Process Start: $($processStartDate)"
    WRITE-VERBOSE "[] Process End: $(get-date)"
}
#################################################
FUNCTION process-commVaultJobs
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [string] $startDate = '8/1/2018',
            [string] $endDate = '',
            [string] $whereStatement = "",
		    [string] $invDB = "SQLmonitor",
		    [string] $invServer = "XTINOPSD2\I2",
		    [string] $dwhtable = "BackupCVJob",
		    [string] $dwhDB = "DBA",
		    [string] $dwhServer = "XTINP1DBA01\DBADMIN",
            [boolean] $SuppressDetail,
            [switch] $customVerbose
            )

    $processStartDate = get-Date
    $Domain = "."+ $env:userDNSdomain.Replace("CT.","")

    WRITE-VERBOSE "[] Inv DB: $invDB"
    WRITE-VERBOSE "[] Inv Server: $invServer"
    WRITE-VERBOSE "[] "
    WRITE-VERBOSE "[] DWH table: $dwhtable"
    WRITE-VERBOSE "[] DWH DB: $dwhDB"
    WRITE-VERBOSE "[] DWH Server: $dwhServer"
    WRITE-VERBOSE "[] "
    WRITE-VERBOSE "[] Start Date: $startDate"

    IF( $endDate -ne '' )
        {
             WRITE-VERBOSE "[] End Date: $endDate"
        }

    ## GET SOURCE(S)
    $selectSQL = "SELECT [InstanceName] as server_name FROM [SQLMonitor].[dbo].[Instance] where tenants like '%commvault%'"
    $sourceList =  Invoke-Sqlcmd -ServerInstance $invServer -Database $invDB -Query $selectSQL -QueryTimeout 65535 

    $counter = 1
    ForEach( $sourceInstance in $sourceList)
        {
            WRITE-VERBOSE "Processing: $($sourceInstance.server_name) CommServ [$($counter)/$($sourceList.server_name.Count)]"
            WRITE-VERBOSE "[] Sanity check - Check-HostPing $($sourceInstance.server_name) $domain"
            if ( Check-HostPing $sourceInstance.server_name $domain ) 
                {
                    IF( $endDate -eq '' )
                        {
                            WRITE-VERBOSE "`t Check DWH table for MAX date"
                                $selectSQL = "select IsNULL(MAX(EndDate),'$($startDate)') as MaxDate FROM "+ $dwhtable +" WHERE CommServer = '$($sourceInstance.server_name)' "
	                            WRITE-VERBOSE $selectSQL

                                $InstanceMaxDate = Invoke-Sqlcmd -ServerInstance $dwhServer -Database $dwhDB -Query $selectSQL -QueryTimeout 65535 | SELECT -exp MaxDate
                        }
                    ELSE
                        {
                            WRITE-VERBOSE "`t Searching Date Range $($startDate) to $($endDate)"
                            $InstanceMaxDate = $startDate
                        }
            
                    WRITE-VERBOSE "`t Fetch Backup Info for $($sourceInstance.server_name) after $($InstanceMaxDate)"
                    $cvJobInfo =  fetch-cvJobInfo $InstanceMaxDate $endDate $sourceInstance.server_name $sourceInstance.database_name -Custom:$CustomVerbose -whatif
                    #$backupInfo | Format-Table -Auto

                    WRITE-VERBOSE "`t Insert New data into DWH"
                    insert-cvJobInfo $cvJobInfo $dwhTable $dwhDB $dwhServer -Custom:$CustomVerbose -whatif

                }
             ELSE
                {  
                    WRITE-VERBOSE "[WARNING] Cluster $($sourceInstance.server_name)$domain is not Pinging"
                }

            $counter = $counter+1
        }#  ForEach( $sourceInstance in $sourceList)


    WRITE-VERBOSE "[] Database_Name: $whereStatement"
    WRITE-VERBOSE "[] Start Search: $startDate"

    IF( $endDate -ne '' )
        {
             WRITE-VERBOSE "[] End Search: $endDate"
        }
    WRITE-VERBOSE "[] Process Start: $($processStartDate)"
    WRITE-VERBOSE "[] Process End: $(get-date)"
}

FUNCTION process-StandardRun
{
    start-job -NAME "harvest-StackLevel" -Init ([ScriptBlock]::Create("Set-Location '$ReleaseFileDestination'")) -ScriptBlock {.\deployGitHubObjects.ps1 -targetDB WORKTABLEDB -repoVersion UTILITYDB_1.16.0 -phase phase1 -cmsGroup Stack11 -dryRun 1 -force}
    
    start-job -NAME "WorkTableDB-Stack11" -Init ([ScriptBlock]::Create("Set-Location '$ReleaseFileDestination'")) -ScriptBlock {.\deployGitHubObjects.ps1 -targetDB WORKTABLEDB -repoVersion UTILITYDB_1.16.0 -phase phase1 -cmsGroup Stack11 -dryRun 1 -force}

    start-job -NAME "WorkTableDB-Stack11" -Init ([ScriptBlock]::Create("Set-Location '$ReleaseFileDestination'")) -ScriptBlock {.\deployGitHubObjects.ps1 -targetDB WORKTABLEDB -repoVersion UTILITYDB_1.16.0 -phase phase1 -cmsGroup Stack11 -dryRun 1 -force}


}
<#####################################################################
Purpose:
    Harvest information from:
        Commvault regarding jobs
        Full backup information based on collector information stored in SQLmonitor
        All backup information based on DB inventory stored in SQLmonitor
History:
    20181211 hbrotherton W-###### Created

    yyyymmdd username W-###### what was changed
Common Commands:

    process-fullBackups   -startDate "11/1/2018" -whereStatement "database_name LIKE '[a-df-z]%' AND database_name != 'ConfigDB'" -verbose
    process-commVaultJobs -startDate "11/1/2018"  -verbose
    process-allETBackups  -startDate "11/1/2018"  -verbose

LOAD STACK 10 SYSTEM LEVEL BACKUPS
process-allETBackups   -startDate "11/1/2018" -whereStatement "inst.stack = 10 and db.databaseTypeID not in ('1','2','3','4','5','6','7','8') AND db. [DatabaseName] != 'ConfigDB'" -verbose

LOAD STACK 50 SYSTEM LEVEL BACKUPS
process-allETBackups   -startDate "11/1/2018" -invServer 'FRA3S50DBA01I01\I01' -whereStatement "inst.stack = 50 and db.databaseTypeID not in ('1','2','3','4','5','6','7','8') AND db. [DatabaseName] != 'ConfigDB'" -verbose
LOAD STACK 50 ET LEVEL BACKUPS
process-allETBackups   -startDate "11/1/2018" -invServer 'FRA3S50DBA01I01\I01' -verbose
############################################################>