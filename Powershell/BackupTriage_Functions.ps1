PARAM(
		[Parameter(Position=0)]
		[Alias("TargetSQL")]
		[string] $targetServer , # format server\instance

		[Parameter(Position=0)]
		[Alias("TargetDB")]
		[string] $targetDatabase, # found in alert - one at a time.
		
		[Parameter(Position=2)]
        [Alias("searchType")]       
	    [string[]] $backupType,  # Log, Diff, Full

		[Parameter(Position=3)]
        [Alias("wahtIf")]       
	    [bool] $dryRun = 0


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
                $policystate
                $returnObject
                BREAK;
            }

    RETURN     $PolicyState
}

FUNCTION Check-HostPing ( [string] $f_targetHost, [string] $f_domain )
{
    $f_targetHostFQDN = $f_targetHost + $f_domain
    test-Connection -ComputerName $f_targetHostFQDN -Count 2 -Quiet       
}

FUNCTION Get-BasicAuthCreds 
{
    param([string]$Username,[string]$Password)
    $AuthString = "{0}:{1}" -f $Username,$Password
    $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
    return "Basic $([Convert]::ToBase64String($AuthBytes))"
}#

$targetHost = $targetServer.substring(0,$targetServer.IndexOf('\')) +".XT.LOCAL"
$targetInstance = $targetServer.substring($targetServer.IndexOf('\')+1,$targetServer.length-($targetServer.IndexOf('\')+1))
WRITE-OUTPUT "[] Target SQL Server: $($targetServer)"
WRITE-OUTPUT "[] Target SQL Root: $($targetHost)"
WRITE-OUTPUT "[] Target SQL Instance: $($targetInstance)"
WRITE-OUTPUT "[] Target SQL Database: $($targetDatabase)"
WRITE-OUTPUT "[] Backup Search Type: $($backupType)"
WRITE-OUTPUT "[] "

$alertList = @()
WRITE-OUTPUT "[] Last Backup of Type: $($backupType)"
## Check backup run date/time
$selectSQL = "SELECT [BS].[database_name],
       MAX([BS].[backup_finish_date]) AS BackupDate,
       DATEDIFF(n, MAX([BS].[backup_finish_date]), GETDATE()) AS MinutesSince"
       
SWITCH ($backupType)
    { 
        "Full" {$selectSQL = $selectSQL + 'Full'; BREAK } # Full 
        "Diff" {$selectSQL = $selectSQL + 'Diff'; BREAK } # Diff 
        "Log"  {$selectSQL = $selectSQL + 'Log'; BREAK } # Log
    }
       
$selectSQL = $selectSQL +"Backup
FROM [msdb].[dbo].[backupset] AS BS
WHERE [BS].[type] = "

SWITCH ($backupType)
    { 
        "Full" {$selectSQL = $selectSQL + "'F'"; BREAK } # Full 
        "Diff" {$selectSQL = $selectSQL + "'D'"; BREAK } # Diff 
        "Log"  {$selectSQL = $selectSQL + "'L'"; BREAK } # Log
    }

IF (-not ([string]::IsNullOrEmpty($targetDatabase)) )
    {
        $selectSQL = $selectSQL +"
        AND [BS].[database_name] = '$($targetDatabase)'"
    }

$selectSQL = $selectSQL +"
GROUP BY [BS].[database_name]"
WRITE-VERBOSE $selectSQL

$lastRun = @(Invoke-Sqlcmd -ServerInstance $targetServer -Database 'MSDB' -Query $selectSQL)

$lastRun | format-table -AutoSize

IF($lastRun.Count -eq 0 ) {WRITE-VERBOSE "[ALERT] No recent backups"; $alertList += "[ALERT] No recent backups"}
WRITE-OUTPUT " "
WRITE-OUTPUT "[] Error Log"

$execSQL = "EXEC sp_readerrorlog 0,1,'BackupIoRequest'"
WRITE-VERBOSE $execSQL

$erroLog = @(Invoke-Sqlcmd -ServerInstance $targetServer -Database 'Utility' -Query $execSQL)
IF( $erroLog.Count -eq 0 ){ WRITE-OUTPUT "No Errors found" } ELSE { $erroLog | format-table -AutoSize }

IF($erroLog.text -match "not enough space on the disk"){WRITE-VERBOSE "[ALERT] Not Enough room on disk....."; $alertList += "[ALERT] Not Enough room on disk - https://docs.google.com/document/d/1I-kg9ZVL9nDNO0we_YcV9BpH1zWdOOSBKMWsfu8H1GQ/edit#"}
WRITE-OUTPUT " "
WRITE-OUTPUT "[] Default drives" 

## INterrogate Default paths for TYPE
$selectSQL = "
SELECT DISTINCT CASE 
		WHEN SystemPath like '%links%' THEN LEFT(SystemPath , CharIndex('Link',SystemPath)-2) 
		ELSE SystemPath
	   END as SystemPath
FROM Utility.dbabackup.[DatabaseSettings] AS DS
  LEFT JOIN Utility.dbaBackup.BackupPathSet AS BPS
    "

SWITCH ($backupType){ 
                        "Full" {$selectSQL = $selectSQL + 'ON (DS.FullBackupPathSetID = BPS.BackupPathSetID)'; BREAK } # Full 
                        "Diff" {$selectSQL = $selectSQL + 'ON (DS.DiffBackupPathSetID = BPS.BackupPathSetID)'; BREAK } # Diff 
                        "Log"  {$selectSQL = $selectSQL + 'ON (DS.LogBackupPathSetID = BPS.BackupPathSetID)'; BREAK } # Log
                    }

$selectSQL += "
  LEFT JOIN Utility.dbabackup.BackupPath AS BP 
    ON (BPS.backupPathSetID = BP.backupPathSetID)"
IF (-not ([string]::IsNullOrEmpty($targetDatabase)) )
    {
        $selectSQL = $selectSQL +"
        WHERE DS.databaseName = '$($targetDatabase)'"
    }
WRITE-VERBOSE $selectSQL

$backupPaths = @(Invoke-Sqlcmd -ServerInstance $targetServer -Database 'Utility' -Query $selectSQL | select -exp systemPath )

$mylist = @()
ForEach( $backupPath in $backupPaths)
{
    WRITE-VERBOSE "Processing: $backupPath"
    $mylist += Get-WmiObject Win32_Volume -ComputerName $targetHost -Filter "DriveType='3'"| where { $_.name -eq "$($backupPath)\" } | select name ,label,@{Name='capacity';Expression={[Math]::Round($_.Capacity /1GB,0)}}, @{Name='freespace';Expression={[math]::Round($_.FreeSpace /1GB,0)}}, @{Name="GPT";Expression={$_.Type.StartsWith("GPT")}}, type
}
                        
$myList | format-table -AutoSize

## display full alert actions.
IF( $alertList.count -eq 0 )
    {
        WRITE-OUTPUT "Nothing reported"
    }
ELSE
    {
        $alertList | format-table -autosize
    }

<#

.\backupTriage_Functions.ps1 -targetServer 'IND1P02CB111I09\I09' -targetDatabase 'ExactTarget10047' -backuptype 'log'
    Get-WmiObject Win32_DiskPartition -computer $targetHost -


    Get-WmiObject Win32_Volume |
Where { $_.drivetype -eq '3' -and $_.driveletter} |
Select-Object driveletter,@{Name='freespace';Expression={$_.freespace/1GB}},@{Name='capacity';Expression={$_.capacity/1GB}} |


Get-WmiObject Win32_Volume -ComputerName $targetHost -Filter "DriveType='3'"| where { $_.name -eq "$($backupPath)\" } | select name ,label,@{Name='capacity';Expression={[Math]::Round($_.Capacity /1GB,0)}}, @{Name='freespace';Expression={[math]::Round($_.FreeSpace /1GB,0)}}, @{Name="GPT";Expression={$_.Type.StartsWith("GPT")}}, type, @{Name="testeing";Expression={$_.getRelated('Win32_Volume')}}


#>


