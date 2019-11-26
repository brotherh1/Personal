PARAM(

    [Parameter(Mandatory=$true)] [string] $targetDB = '',
    [Parameter(Mandatory=$true)] [string] $oldProd = '',    # host\inst
    [string] $newProd = '',    # host\inst
    [string] $newStandby = '', # host\inst
    [Parameter(Mandatory=$true)] [string] $backupPath = '', # "H:\SQL\I04\BAK2\ExactTarget11\" " C:\RESTORES\DB###\"
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
    IF( $f_targetDB -like 'ExactTarget*' ){ $utilityPath = $utilityPath + "\config.ps1"  } ELSE { $utilityPath = $utilityPath + "_"+ $f_targetDB +"\config.ps1" } 
    
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
    {
        $newProdBAK1 = get-drive $newProd 
        $newProdBAK1 = $newProdBAK1 +"\SQL\"+ $newProd.substring($newProd.IndexOf('\')+1,3) +"\BAK1\"+ $targetDB +"\"

        $newStndbyBAK1 = get-drive $newStandby 
        $newStndbyBAK1 = $newStndbyBAK1 +"\SQL\"+ $newStandby.substring($newStandby.IndexOf('\')+1,3) +"\BAK1\"+ $targetDB +"\"
    }
ELSE
    {
        $newProdBAK1 = $backupPath
        $newStndbyBAK1 = $backupPath
    }

WRITE-HOST "[] Started: $((Get-Date).ToString())"
WRITE-HOST "[] Source Host: $oldProd "
WRITE-HOST "[] Source DB: $targetDB "
WRITE-HOST "   "
WRITE-HOST "[] Target Prod: $newProd "
WRITE-HOST "[] Target PROD DB: $targetDB "
WRITE-HOST "[] Target PROD Backup: $newProdBAK1 "
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
        process-process $oldProd $newProd $targetDB $newProdBAK1 $skipRestore $skipStndbyMGR $dryRun
    }

WRITE-HOST " "

If( !$newStandby )
    {
        WRITE-HOST "[WARNING] No new standby host -SKIP"
    }
ELSE
    {
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
#######################################################################>