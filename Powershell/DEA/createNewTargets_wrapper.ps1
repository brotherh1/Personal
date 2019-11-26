PARAM(

    [Parameter(Mandatory=$true)] [string] $targetDB = '',
    [Parameter(Mandatory=$true)] [string] $oldProd = '',    # host\inst
    [string] $newProd = '',    # host\inst
    [string] $newStandby = '', # host\inst
    [string] $backupPath = '', # "H:\SQL\I04\BAK2\ExactTarget11\" " C:\RESTORES\DB###\"
    [int] $skipRestore = 0,
    [int] $skipStndbyMGR = 0,
    [int] $dryRun = 1
    #[string] $standbyMGR = ''
    ## These values should be table driven to try and eliminate typos....
    #  .\createNewTargets_wrapper.ps1 -targetDB 'ExactTarget59' -oldPROD 'XTINP1CL13D6\I6' -newPRod 'IND1P01C087I01\I01' -newStandBY 'IND1P01CB087I01\I01'
    #  .\createNewTargets_wrapper.ps1 -targetDB 'ConfigDB' -oldPROD 'XTINP1CL13D6\I6' -newPRod 'IND1P01C087I01\I01' -newStandBY 'IND1P01CB087I01\I01'

    #  .\createNewTargets_wrapper.ps1 -targetDB 'ExactTarget59' -oldPROD 'XTINP1CL13D6\I6' -newPRod 'IND1P01C087I01\I01' -newStandBY 'IND1P01CB087I01\I01' -backupPath 'C:\RESTORES\DB59\'
    #  .\createNewTargets_wrapper.ps1 -targetDB 'ConfigDB' -oldPROD 'XTINP1CL13D6\I6' -newPRod 'IND1P01C087I01\I01' -newStandBY 'IND1P01CB087I01\I01' -backupPath ='C:\RESTORES\ConfigDB\'

    #  .\createNewTargets_wrapper.ps1 -targetDB 'ExactTarget59' -oldPROD 'XTINP1CL13D6\I6' -newPRod 'IND1P01C087I01\I01' -newStandBY 'IND1P01CB087I01\I01' -backupPath 'E:\SQL\I01\'
    #  .\createNewTargets_wrapper.ps1 -targetDB 'ConfigDB' -oldPROD 'XTINP1CL13D6\I6' -newPRod 'IND1P01C087I01\I01' -newStandBY 'IND1P01CB087I01\I01' -backupPath 'E:\SQL\I01\'

)

function get-drive ( [string] $f_instance )
{
    $f_instance = $f_instance.replace("I0","I")  #just in case

    switch ($f_instance) 
    { 
       {($_ -LIKE "*\I1")}  {$rootDrive = "E:"} 
       {($_ -LIKE "*\I2")}  {$rootDrive = "F:"} 
       {($_ -LIKE "*\I3")}  {$rootDrive = "G:"} 
       {($_ -LIKE "*\I4")}  {$rootDrive = "H:"} 
       {($_ -LIKE "*\I5")}  {$rootDrive = "J:"} 
       {($_ -LIKE "*\I6")}  {$rootDrive = "K:"} 
       {($_ -LIKE "*\I7")}  {$rootDrive = "L:"}
       {($_ -LIKE "*\I8")}  {$rootDrive = "M:"} 
       {($_ -LIKE "*\I9")}  {$rootDrive = "N:"} 
       {($_ -LIKE "*\I10")} {$rootDrive = "O:"} 
       {($_ -LIKE "*\I11")} {$rootDrive = "P:"} 
       {($_ -LIKE "*\I12")} {$rootDrive = "S:"} 
       {($_ -LIKE "*\I13")} {$rootDrive = "U:"} 
       {($_ -LIKE "*\I14")} {$rootDrive = "V:"} 
       {($_ -LIKE "*\I15")} {$rootDrive = "W:"} 
       {($_ -LIKE "*\I16")} {$rootDrive = "X:"} 
        default {$rootDrive = "BAD INSTANCE"}
    }
    RETURN $rootDrive
}

function move-LastFull ( [string] $f_sourceHost, [string] $f_targetHost, [string] $f_targetDB, [string] $f_targetBAK, [int] $f_dryRun )
{
    $selectSQL = "SELECT
    bs.database_name,bs.media_set_ID,
    bmf.physical_device_name--, *
FROM
    msdb.dbo.backupmediafamily bmf
    JOIN
    msdb.dbo.backupset bs ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = '"+ $f_targetDB +"' AND
    bs.backup_finish_date = (	SELECT  MAX([BS].[backup_finish_date])
						        FROM [msdb].[dbo].[backupset] AS BS
						        WHERE [BS].[description] like 'FULL %'
							        AND [BS].[database_name] = '"+ $f_targetDB +"'
								GROUP BY [BS].[database_name]
)
GROUP BY [BS].[database_name], bs.media_set_ID,bmf.physical_device_name"
    WRITE-VERBOSE $selectSQL

    $fullBackupFileList = invoke-sqlcmd -ServerInstance $f_sourceHost -Query $selectSQL | select -exp physical_device_name

    ForEach( $fullBackupFile in $fullBackupFileList )
        {
            WRITE-OUTPUT "Processing file: $(Split-Path $fullBackupFile -Leaf)"
            $sourcefile = "\\"+ $f_sourceHost.substring(0,$f_sourceHost.IndexOf('\')) +"\"+ $fullBackupFile.Replace(":","$").substring(0, $fullBackupFile.IndexOf('Full')+4)
            $targetDrive = "\\"+ $f_targetHost.substring(0,$f_targetHost.IndexOf('\')) +"\"+ $f_targetBAK.REPLACE(":","$") #+"\"+ $f_targetDB

            WRITE-OUTPUT `t"Copying source file: $($sourcefile)"
            WRITE-OUTPUT `t"        target file: $($targetDrive)"
            $f_copyCMD = "robocopy $sourcefile $targetDrive $(Split-Path $fullBackupFile -Leaf) /MIR /ETA"
            IF($f_dryRun -eq 1)
                {
                    WRITE-HOST `t"[DryRun] $f_copyCMD"
                    #WRITE-HOST `t`t"$f_copyCMD"
                }
            ELSE
                {
                    WRITE-HOST `t"Copying file..."
                    invoke-expression $f_copyCMD
                }

        }


    RETURN $fullBackupFileList | Select-Object -first 1
}

function process-process ( [string] $f_sourceHost, [string] $f_targetHost, [string] $f_targetDB, [string] $f_targetBAK, [int] $f_skipRestore, [int] $f_skipStndbyMGR, [int] $f_dryRun )
{
    $newDataPath = get-drive $f_targetHost
    $newDataPath = $newDataPath +"\SQL\"+ $f_targetHost.substring($f_targetHost.IndexOf('\')+1,3) +"\"+ $f_targetDB.REPLACE("ExactTarget","DB") +"\"

    # Call restore process - receive backup location and file name for one file
    ."$ScriptDirectory\restoreDatabase_ET.ps1"

    TRY
        {
            If( $f_skipRestore -eq 1)
                {
                    WRITE-HOST "[SKIP] restore - but get header info"
                    WRITE-HOST `t"restoredatabase -RequestNum 711 -ServerInstance $f_targetHost -Database $f_targetDB -RestoreType "Database" -BackupFile $f_targetBAK -OverWriteDatabase 0 -OperationType "Restore" -Verbose -RestoreLunPath "$newDataPath" -DryRun $f_skipRestore"
                    WRITE-HOST " "
                    $backupFile = restoredatabase -RequestNum 711 -ServerInstance $f_targetHost -Database $f_targetDB -RestoreType "Database" -BackupFile $f_targetBAK -OverWriteDatabase 0 -OperationType "Restore" -Verbose -RestoreLunPath "$newDataPath" -DryRun $f_skipRestore
                    $backupPath = $backupFile.Replace("Disk = ","")
                }
            ELSE
                {
                    WRITE-HOST "[] Call Restore process - $f_targetHost "
                    WRITE-HOST `t"restoredatabase -RequestNum 711 -ServerInstance "$f_targetHost" -Database "$f_targetDB" -RestoreType "Database" -BackupFile "$f_targetBAK" -OverWriteDatabase 0 -OperationType "Restore" -Verbose -RestoreLunPath "$newDataPath" -DryRun $f_dryRun"
                    WRITE-HOST " "
                    $backupFile = restoredatabase -RequestNum 711 -ServerInstance "$f_targetHost" -Database "$f_targetDB" -RestoreType "Database" -BackupFile "$f_targetBAK" -OverWriteDatabase 0 -OperationType "Restore" -Verbose -RestoreLunPath "$newDataPath" -DryRun $f_dryRun
                    $backupPath = $backupFile.Replace("Disk = ","")
                }
        }
    CATCH
        {
            WRITE-HOST "[ALERT] RESTORE FAILED ...."
            RETURN
        }

    # rewritten standby manager all in powershell ... use EXE instead
    # $standardScript = $ScriptDirectory +"\insertUpdate-Standby.ps1 -sourceDB  $targetDB -sourceHost $oldProd -targetHost $newProd  "

    # Use Standby DB manager.EXE
    WRITE-HOST " " 
    #."$ScriptDirectory\cmdLine-Standby.ps1"
    $standardScript = $ScriptDirectory +"\cmdLine-Standby.ps1 -sourceDB "+ $f_targetDB +" -sourceHost "+ $f_sourceHost +" -targetHost "+ $f_targetHost +" -backupFile "+ $backupPath +" -dryRun "+ $f_dryRun

    IF( $f_skipStndbyMGR -eq 1)
        {
            Write-HOST "[SKIP] Not building temp job or adding to inventory "
            WRITE-HOST `t"$standardScript             "
        }
    ELSE
        { 
            Write-HOST "[] Executing: $standardScript "
            invoke-expression $standardScript
        }

    #Looking for config.ps1 as inidcator population job has completed.
    $instDrive = get-drive $f_targetHost
    $utilityPath = "\\"+ $f_targetHost.substring(0,$f_targetHost.IndexOf('\')) +"\"+ $instDrive.replace(':','$') +"\StandbyUtil"
    #IF( $f_targetDB -like 'ExactTarget*' ){ $utilityPath = $utilityPath + "\config.ps1"  } ELSE { $utilityPath = $utilityPath + "_"+ $f_targetDB +"\config.ps1" } 
    $utilityPath = $utilityPath + "_"+ $f_targetDB +"\config.ps1"
    
    IF($dryRun -eq 1)
        {
             WRITE-HOST "[DryRun] Not Looking for $utilityPath "
        }
    ELSE
        {
            IF($f_skipStndbyMGR -eq 0)
                {
                    WRITE-HOST "[] Looking for $utilityPath "
                    while(!(test-path $utilityPath))
                    {   
                        WRITE-HOST `t"not found - 10 second count and try again" 
                        start-sleep -s 10;   
                    }
                }
            else
                {
                    WRITE-HOST "[SKIP] Not Looking for $utilityPath "
                }
        }

    #enable LogcopyJob
    IF($f_skipStndbyMGR -eq 0)
            {
                $enableSQL = "EXEC msdb.dbo.sp_update_job @job_name=N'LogShip_"+ $f_targetDB +"', @enabled=1"
            }

    If($f_dryRun -eq 1)
        {
            WRITE-HOST "[DryRun] $enableSQL "
        }
    ELSE
        {
            IF($f_skipStndbyMGR -eq 0)
            {
                WRITE-HOST "[] Executing: $enableSQL "
                invoke-sqlcmd -ServerInstance $f_targetHost -Query $enableSQL
            }
        }

}
##############################################################################################################################
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

IF( $backupPath -eq '' )  # I do this here in case new prod and standby instances are different.
    {   ## NO BAKCKUP PATH SPECIFIED - NEW BUILD - SMALL BACKUP - SYSTEM WILL MOVE FILES FOR YOU.
        IF( !$newProd )
            {
                WRITE-VERBOSE "Not defining New PROD locations"
            }
        ELSE
            {
                $newProdBAK1 = get-drive $newProd 
                $newProdBAK1 = $newProdBAK1 +"\SQL\"+ $newProd.substring($newProd.IndexOf('\')+1,3) +"\BAK1\"+ $targetDB +"\"
            }

        $newStndbyBAK1 = get-drive $newStandby 
        $newStndbyBAK1 = $newStndbyBAK1 +"\SQL\"+ $newStandby.substring($newStandby.IndexOf('\')+1,3) +"\BAK1\"+ $targetDB +"\"
    }
ELSE
    {   ## IF BACKUP PATH IS SPECIFIED THAN A BACKUP WAS ALREADY MOVED AND IS POSSIBLY A LOCAL DRIVE.
        $newProdBAK1 = $backupPath
        $newStndbyBAK1 = $backupPath
    }

WRITE-HOST "[] Started: $((Get-Date).ToString())"
WRITE-HOST "[] Source Host: $oldProd "
WRITE-HOST "[] Source DB: $targetDB "
If( !$newProd ) 
    {
        WRITE-HOST "   "
    }
ELSE
    {
        WRITE-HOST "   "
        WRITE-HOST "[] Target Prod: $newProd "
        WRITE-HOST "[] Target PROD DB: $targetDB "
        WRITE-HOST "[] Target PROD Backup: $newProdBAK1 "
    }
WRITE-HOST "   "
WRITE-HOST "[] Target Stndby: $newStandby "
WRITE-HOST "[] Target Stndby DB: $targetDB "
WRITE-HOST "[] Target Stndby Backup: $newStndbyBAK1 "
WRITE-HOST "   "
WRITE-HOST "[] Skip Restore: $skipRestore"
WRITE-HOST "[] Skip Stndby MGR: $skipStndbyMGR"
WRITE-HOST "[] DryRun: $dryRun"
WRITE-HOST " "



If( !$newProd ) 
    {
        WRITE-HOST "[WARNING] No New Prod host -SKIP"
    }
ELSE
    {
        IF( !$backupPath )
            {
                WRITE-OUTPUT "Attempting to move files from $($oldProd) to $($newProd)"
                ## GRABBING LAST FULL BACKUP
                move-LastFull $oldProd $newProd $targetDB $newProdBAK1 $dryRun
            }
        process-process $oldProd $newProd $targetDB $newProdBAK1 $skipRestore $skipStndbyMGR $dryRun
    }

WRITE-HOST " "

If( !$newStandby )
    {
        WRITE-HOST "[WARNING] No new standby host -SKIP"
    }
ELSE
    {
        IF( !$backupPath )
            {
                WRITE-OUTPUT "Attempting to move files from $($oldProd) to $($newStandby)"
                ## GRABBING LAST FULL BACKUP
                move-LastFull $oldProd $newStandby $targetDB $newStndbyBAK1 $dryRun
            }
        # call funciton sourceHost newHost     dbName    locationBAK    skiprestore
        process-process $oldProd $newStandby $targetDB $newStndbyBAK1 $skipRestore $skipStndbyMGR $dryRun

    }

    
<#####################################################################
Purpose:  
     This procedure performs this action. 
History:  
     20181502 HBROTHERTON W-4693137 Added STEP2 - Sanity check to SQL agent job that executes the standbymanager exe
     20182102 HBROTHERTON W-4693137 Added check for C:\ drive versus shared mount
     YYYYMMDD USERID W-000000000 This is what I changed.
Comments:
     Anything you feel is important to share that is not the "purpose"

    Create standby for NEW EMPTY DB
     .\createNewTargets_wrapper.ps1 -targetDB 'ExactTarget11074' -oldPROD 'ATL1S11C009I01\I01' -newPRod '' -newStandBY 'ATL1S11CB009I01\I01' -dryrun 0

    Creaet Standby on OLD BIG DB that you did a snap and export
     .\createNewTargets_wrapper.ps1 -targetDB 'ExactTarget11074' -oldPROD 'ATL1S11C009I01\I01' -newPRod '' -newStandBY 'ATL1S11CB009I01\I01' -backupPath 'C:\Restores\ET11074' -dryrun 0
#######################################################################>