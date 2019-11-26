[CmdletBinding(SupportsShouldProcess)]
PARAM(
    [string] $searchInstance = '',
    [string] $searchCluster = '',
    [string] $invDB = "snapbackupDB",
    [string] $invServer = "XTINP1MA05\I1",
    [string] $dwhtable = "Instance",
    [string] $dwhDB = "SQLMonitor",
    [string] $dwhServer = "DataWhareHouse",
    [int] $dryRun = 1,
    [boolean] $SuppressDetail,
    [switch] $customVerbose
)

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
                <# not using this in Zarga 
                $policystate
                $returnObject 
                #>
                BREAK;
            }

    #RETURN     $PolicyState

}

FUNCTION Check-HostPing ( [string] $f_targetHost )
{
    #$f_targetInstance = $f_targetHost.substring(0,$f_targetHost.IndexOf('\')) + $f_domain
    test-Connection -ComputerName $f_targetHost -Count 2 -Quiet       
}

FUNCTION fetch-sourceList
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [string] $f_targetInstance,
            [string] $f_targetCluster,
	        [string] $f_invDB,
	        [string] $f_invServer,
            [switch] $Custom
	 ) 

    WRITE-VERBOSE "[] Gather information from inventory: "
    IF( $f_targetInstance )
        {
            $searchSQL = "select * from SnapbackupDB.dbo.LogCopyConfig where enabled = 1 AND sourceHost = '"+ $f_targetInstance +".XT.LOCAL'
	                AND name in (select InstanceName FROM [DataWareHouse].[SQLMonitor].[dbo].[Instance] where isProduction = 0 and isOn = 0)"
        }
    ELSEIF( $f_targetCluster )
        {
            $searchSQL = "select * from SnapbackupDB.dbo.LogCopyConfig where enabled = 1 AND  sourceHost like '"+ $f_targetCluster +"%'
	                AND name in (select InstanceName FROM [DataWareHouse].[SQLMonitor].[dbo].[Instance] where isProduction = 0 and isOn = 0)"
        }
    ELSE
        {
            $searchSQL = "select * from SnapbackupDB.dbo.LogCopyConfig where enabled = 1 
	                AND name in (select InstanceName FROM [DataWareHouse].[SQLMonitor].[dbo].[Instance] where isProduction = 0 and isOn = 0)"
        }        

    WRITE-VERBOSE "`t $($searchSQL)"

    $dbOBJ = Invoke-Sqlcmd -ServerInstance $f_invServer -Database $f_invDB -Query $searchSQL -QueryTimeout 65535

    return $dbOBJ

}

<######  MAIN BODY ######>
    $processStartDate = get-Date
    $Domain = "."+ $env:userDNSdomain.Replace("CT.","")

    WRITE-VERBOSE "[] Inv DB: $invDB"
    WRITE-VERBOSE "[] Inv Server: $invServer"
    WRITE-VERBOSE "[] "
    WRITE-VERBOSE "[] DWH table: $dwhtable"
    WRITE-VERBOSE "[] DWH DB: $dwhDB"
    WRITE-VERBOSE "[] DWH Server: $dwhServer"
    WRITE-VERBOSE "[] "
    
    IF( $searchInstance -ne '')
        {
            WRITE-VERBOSE "[] Target Instance: $searchInstance "
        }
    ELSEIF( $searchCluster -ne '')
        {
            WRITE-VERBOSE "[] Target Cluster: $searchCluster "
        }
    ELSE
        {
            WRITE-VERBOSE "[] Processing entire Inventory "
        }
    WRITE-VERBOSE "[] "

    IF( $dryRun -eq 1 )
        {
            WRITE-VERBOSE "[] DryRun"
            WRITE-VERBOSE "[] "
        }

    Import-SqlModule 
    ## GET SOURCE(S)
    $sourceList =  fetch-sourceList $searchInstance $searchCluster $invDB $invServer -Custom:$CustomVerbose -whatif | Sort-Object -Property sourcePath
    $counter = 1

    ForEach( $sourceInstance in $sourceList)
        {
            WRITE-VERBOSE "Processing: $($sourceInstance.server_name) $($sourceInstance.database_name) [$($counter)/$($sourceList.sourceHost.Count)]"
            WRITE-VERBOSE "[] Sanity check - Check-HostPing $($sourceInstance.SourceHost)"

            IF( Check-HostPing $sourceInstance.SourceHost $domain ) 
                {
                    WRITE-VERBOSE "[WARNING] Host is still online - checking for DB"
                }
            ELSE
                {  
                    WRITE-VERBOSE "[OK] Cluster $($sourceInstance.SourceHost) is not Pinging"
                    WRITE-VERBOSE "[] Check destPath $($sourceInstance.DestPath)"

		            IF( Test-Path $sourceInstance.DestPath ) 
			            {
				            WRITE-VERBOSE "`t Directory Exists - getting file count"
				            $directoryInfo = Get-ChildItem $sourceInstance.DestPath -erroraction 'silentlycontinue'| Measure-Object
				            $currentCount = $directoryInfo.count
				            $removeDirectory = 1			
			            }
		            ELSE
			            {
				            WRITE-VERBOSE "`t Directory Does Not Exist - setting file count = 0"
				            $currentCount = 0
				            $removeDirectory = 0			    
			            }

                    IF( $currentCount -eq 0 )
                        {
				            IF( $removeDirectory -eq 1 )
                                {
					                WRITE-VERBOSE "[] Removing Empty Directory - $($currentCount) files"
					                $removeCMD = "Remove-Item -Recurse -Force $($sourceInstance.DestPath.REPLACE('\Logs',''))"

                                    IF( $dryRun -eq 1 )
                                        {
					                        WRITE-VERBOSE "`t[DryRun] $($removeCMD) "
                                        }
                                    ELSE
                                        {
					                        Invoke-Expression $removeCMD
                                        }
				                }				

				            WRITE-VERBOSE "[OK] Directory Empty"
				            WRITE-VERBOSE "[] Update Inventory: $($invServer)"
				            $updateSQL = "UPDATE SnapbackupDB.dbo.LogCopyConfig Set enabled = 0 where SourceHost = '$($sourceInstance.SourceHost)'"

                            IF( $dryRun -eq 1 )
                                {
				                    WRITE-VERBOSE "`t[DryRun] $($updateSQL)"
                                }
                            ELSE
                                {
				                    Invoke-Sqlcmd -ServerInstance $invServer -Database $invDB -Query $updateSQL -QueryTimeout 65535
                                }

                            WRITE-VERBOSE "[] Check for Instance LUN to reclaim - PATH $($sourceInstance.DestPath.REPLACE('\Logs','\'))"
                            $selectSQL = "SELECT [mountLabel] FROM [SnapBackupDB].[dbo].[mountInfo] where mountname = '"+ $($sourceInstance.DestPath.REPLACE('\Logs','\')) +"'"
                            WRITE-VERBOSE "`t $($selectSQL)"
                            #invoke-sqlcmd

				            [string] $CopySetID = $sourceInstance.CopySetID

				            WRITE-VERBOSE "[] Sanity check - anything left enabled"
				            $selectSQL = "SELECT count(copySetID) as instanceCount FROM SnapbackupDB.dbo.LogCopyConfig WHERE copySetID = '$($CopySetID)' AND enabled = 1"
				            WRITE-VERBOSE "`t $($selectSQL)"

                            $enabledInstanceCount = Invoke-Sqlcmd -ServerInstance $invServer -Database $invDB -Query $selectSQL -QueryTimeout 65535 | select -exp instanceCount
                            WRITE-VERBOSE "`t $($enabledInstanceCount) instances enabled in inventory"

                            IF( $enabledInstanceCount -gt 0 )
                                {
					                WRITE-VERBOSE "[] Rebuild Copy Matrix Log Files-Cluster $($CopySetID.substring(1))"
					                $execSQL = "EXEC [SnapbackupDB].[dbo].[dropCreateClusterCopyJob] '$($CopySetID.substring(1))'"
                                    
                                    IF( $dryRun -eq 1 )
                                        {
					                        WRITE-VERBOSE "`t[DryRun] $($execSQL)"
                                        }
                                    ELSE
                                        {
					                        Invoke-Sqlcmd -ServerInstance $invServer -Database $invDB -Query $execSQL -QueryTimeout 65535
                                        }		            
                                }
			    	        ELSE
					            {
					                WRITE-VERBOSE "[] DISABLE Copy Matrix Log Files-Cluster $($CopySetID.substring(1))"
					                $execSQL = "EXEC msdb.dbo.sp_update_job @job_Name = 'Copy Matrix Log Files-Cluster $($CopySetID.substring(1))', @enabled=0"

                                    IF( $dryRun -eq 1 )
                                        {
					                        WRITE-VERBOSE "`t $($execSQL)"
                                        }
                                    ELSE
                                        {
					                        Invoke-Sqlcmd -ServerInstance $invServer -Database $invDB -Query $execSQL -QueryTimeout 65535
                                        }

					                WRITE-VERBOSE "[] Check for Cluster LUN to reclaim"
                                    $selectSQL = "SELECT [mountLabel] FROM [SnapBackupDB].[dbo].[mountInfo] where mountname like '%"+ $searchCluster +"%'"
                                    WRITE-VERBOSE "`t $($selectSQL)"

					            }
        
                        }
                    ELSE # IF( $currentCount -eq 0 )
                        {
                            WRITE-VERBOSE "[WARNING] DestPath not empty - not updating inventory or rebuilding job"
                        }
                }

    		$counter = $counter + 1
		    WRITE-VERBOSE " "

        }#  ForEach( $sourceInstance in $sourceList)

    

    WRITE-VERBOSE "[] Process Start: $($processStartDate)"
    WRITE-VERBOSE "[] Process End: $(get-date)"


<#############################
Purpose:  Check master invetory to see if instance is retired.
	  Adjust local invetory and jobs accordingly.
History: 20181228 hbrotherton w-###### created
Comments:
Process the entire inventory
	process-validateSources -verbose

Process a specific cluster
	process-validateSources -searchcluster 'XTGAP4CL04' -verbose

Process a specific instance
	process-validateSources -searchInstance 'XTGAP4CL04D5' -verbose

QUIP:

.\verifyCopySource -targetInstance 'XTGAP4CL11D1' -invServer 'ATL1P04C01MA03\I03' -dryRun 1 -verbose
##############################>

