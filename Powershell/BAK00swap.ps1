param
(
    [Parameter(
        ParameterSetName = "Full",
        Mandatory = $true)]
    [Parameter(
        ParameterSetName = "SingleStep",
        Mandatory = $true)]
    [Parameter(
        ParameterSetName = "FromStep",
        Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerName,

    [Parameter(
        ParameterSetName = "Full",
        Mandatory = $true)]
    [Parameter(
        ParameterSetName = "SingleStep",
        Mandatory = $true)]
    [Parameter(
        ParameterSetName = "FromStep",
        Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Instance,

    [Parameter(
        ParameterSetName = "Full",
        Mandatory = $true)]
    [Parameter(
        ParameterSetName = "SingleStep",
        Mandatory = $true)]
    [Parameter(
        ParameterSetName = "FromStep",
        Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$disableFSC, #which FSC will no longer be a repository - C01 or C02

    [Parameter(
        ParameterSetName = "SingleStep",
        Mandatory = $true)]
    [int]$StepToRun = $null,

    [Parameter(
        ParameterSetName = "FromStep",
        Mandatory = $true)]
    [int]$StepToRunFrom = $null,

    [int]$DryRun = 1
)

$ErrorActionPreference = "Stop"
$sqlServer = "$ServerName\$Instance"
$dbaInstance = "XTINP1DBA01\DBADMIN"
    Write-Output "Get instance Drive letter"
    $driveLetter = Invoke-Sqlcmd -ServerInstance $sqlServer -Query "SELECT [Utility].[dbo].[GetDriveLetter] () AS drive" |select -exp drive

WRITE-HOST "[] SQL Inventory:   $($dbaInstance)"
WRITE-HOST "[] Target SQL Host: $($sqlServer)"
WRITE-HOST "[] Target Drive:    $($driveLetter)"
WRITE-HOST "[] Dry Run:         $($DryRun)"
$confirmation = Read-Host "Confirm above is correct?  :"
if ($confirmation -eq 'n') { EXIT; }

WRITE-HOST " "
# STEP 0
if ($StepToRun -eq 0 -or ($StepToRunFrom -le 0 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 0: Making sure there are proper permissions"
    IF($DryRun -eq 0)
        { 
            icacls "\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak00\System Volume Information" /grant "builtin\administrators:(OI)(CI)F" 
        }
    ELSE
        {
            WRITE-HOST `t"[DryRun] icacls `"\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak00\System Volume Information`" /grant `"builtin\administrators:(OI)(CI)F`" "
        }
}

# STEP 1
if ($StepToRun -eq 1 -or ($StepToRunFrom -le 1 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 1: Create folder structure"
    IF($DryRun -eq 0)
        { 
            robocopy "\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak1" "\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak00" /e /z /SEC /xf * 
        }
    ELSE
        {
            WRITE-HOST `t"[DryRun] robocopy `"\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak1`" `"\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak00`" /e /z /SEC /xf * "
        }
}

# STEP 2
if ($StepToRun -eq 2 -or ($StepToRunFrom -le 2 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 2: Disable mirrored log backups"
    IF($DryRun -eq 0)
        { 
            Invoke-Sqlcmd -ServerInstance $sqlServer -Query "UPDATE Utility.dbabackup.BackupPathSet SET UseMirror = 0" 
        }
    ELSE
        {
            WRITE-HOST `t"[DryRun] UPDATE Utility.dbabackup.BackupPathSet SET UseMirror = 0"
            Invoke-Sqlcmd -ServerInstance $sqlServer -Query "SELECT * FROM Utility.dbabackup.BackupPathSet" 
        }
}

# STEP 3
if ($StepToRun -eq 3 -or ($StepToRunFrom -le 3 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 3: Redirect backups to Bak00"
    IF($DryRun -eq 0)
        { 
            Invoke-Sqlcmd -ServerInstance $sqlServer -Query "UPDATE Utility.dbabackup.BackupPath SET SystemPath = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(SystemPath, 'Bak1', 'Bak00'), 'Bak2', 'Bak00'), 'Bak3', 'Bak00'), 'Bak4', 'Bak00'), 'Bak5', 'Bak00'), 'Bak6', 'Bak00')" 
        }
    ELSE
        {
            WRITE-HOST `t"[DryRun] UPDATE Utility.dbabackup.BackupPath SET SystemPath = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(SystemPath, 'Bak1', 'Bak00'), 'Bak2', 'Bak00'), 'Bak3', 'Bak00'), 'Bak4', 'Bak00'), 'Bak5', 'Bak00'), 'Bak6', 'Bak00')" 
            Invoke-Sqlcmd -ServerInstance $sqlServer -Query "SELECT * FROM Utility.dbabackup.BackupPath"
        }
}

# STEP 4
if ($StepToRun -eq 4 -or ($StepToRunFrom -le 4 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 4: Update Cleaner.ini"
    $match = [regex]::Escape("[path=%CURRENTDRIVE%:\SQL\%INSTANCE%\Bak1")
    $cleanerFilePath = "\\$ServerName\$DriveLetter`$\SQL\$Instance\Utility\ETFileCleaner\Cleaner.ini"
    $cleanerContent = Get-Content $cleanerFilePath
    $lineNumber = ($cleanerContent | Select-String -Pattern $match).LineNumber - 1
    $newCleanerContent = @()
    for ($i = 0; $i -lt $cleanerContent.Count; $i++)
    {
        if ($i -eq $lineNumber)
        {
            $newCleanerContent += "[path=%CURRENTDRIVE%:\SQL\%INSTANCE%\Bak00]"
            $newCleanerContent += "hours = 168"
            $newCleanerContent += "pattern = *.trn|*.bak|*.diff"
            $newCleanerContent += ""
        }

        $newCleanerContent += $cleanerContent[$i]
    }

    IF($DryRun -eq 0)
        { 
            $newCleanerContent | Out-File $cleanerFilePath 
        }
    ELSE
        {
            WRITE-HOST `t"[DryRun] File Path: $cleanerFilePath"
            WRITE-HOST `t"[DryRun] File Content: $newCleanerContent"
        }
}

# STEP 5
if ($StepToRun -eq 5 -or ($StepToRunFrom -le 5 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 5: Stop SQL Server audit jobs"
    $jobStatuses = @(Invoke-Sqlcmd -ServerInstance $sqlServer -Query "SELECT name, enabled FROM msdb.dbo.sysjobs WHERE name = 'CmdshellAudit' or name = 'MembersAudit'")
    foreach ($jobStatus in $jobStatuses)
    {
        if ($jobStatus["enabled"] -eq 1)
        {
            IF($DryRun -eq 0)
                { 
                    Invoke-Sqlcmd -ServerInstance $sqlServer -Query "EXEC msdb.dbo.sp_update_job @job_name = '$($jobStatus["name"])', @enabled = 0" 
                }
            ELSE
                {
                    WRITE-HOST `t"[DryRun] EXEC msdb.dbo.sp_update_job @job_name = '$($jobStatus[`"name`"])', @enabled = 0" 
                }
        }
    }
}

# STEP 6
if ($StepToRun -eq 6 -or ($StepToRunFrom -le 6 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 6: Stop all SQL Server audits on the instance"
    IF($DryRun -eq 0)
        { 
            Invoke-Sqlcmd -ServerInstance $sqlServer -Query "EXEC Utility.action.StopAudits @force = 1" 
        }
    ELSE
        {
            WRITE-HOST `t"[DryRun] EXEC Utility.action.StopAudits @force = 1" 
        }
}

# STEP 7
if ($StepToRun -eq 7 -or ($StepToRunFrom -le 7 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 7: Alter audit paths"
    $auditPaths = @(Invoke-Sqlcmd -ServerInstance $sqlServer -Query "SELECT name, log_file_path FROM master.sys.server_file_audits")
    foreach ($auditPath in $auditPaths)
    {
        IF($DryRun -eq 0)
            { 
                Invoke-Sqlcmd -ServerInstance $sqlServer -Query "ALTER SERVER AUDIT $($auditPath["name"]) TO FILE (FILEPATH = '$($auditPath["log_file_path"] -ireplace [regex]::Escape("Bak1"), "Bak00" -ireplace [regex]::Escape("Bak2"), "Bak00")')" 
            }
        ELSE
            {
                WRITE-HOST `t"[DryRun] ALTER SERVER AUDIT $($auditPath["name"]) TO FILE (FILEPATH = '$($auditPath["log_file_path"] -ireplace [regex]::Escape("Bak1"), "Bak00" -ireplace [regex]::Escape("Bak2"), "Bak00")')" 
            }
    }
}

# STEP 8
if ($StepToRun -eq 8 -or ($StepToRunFrom -le 8 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 8: Start audits"
    IF($DryRun -eq 0)
        { 
            Invoke-Sqlcmd -ServerInstance $sqlServer -Query "EXEC Utility.action.StartStandardAudits @force = 1" 
        }
    ELSE
        {
            WRITE-HOST `t"[DryRun] EXEC Utility.action.StartStandardAudits @force = 1 "
        }
}

# STEP 9?
if ($StepToRun -eq 9 -or ($StepToRunFrom -le 9 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 9: Cut and paste files from Bak1\Audit to Bak00\Audit"
    
    $bak1AuditPath = "\\$ServerName\$DriveLetter`$\SQL\$Instance\bak1\Audit\*.sqlaudit"
    $bak0AuditPath = "\\$ServerName\$DriveLetter`$\SQL\$Instance\bak00\Audit\"
    IF($DryRun -eq 0)
        { 
            Move-Item $bak1AuditPath $bak0AuditPath 
        }
    ELSE
        {
            WRITE-HOST `t"[DryRun] Move-Item $bak1AuditPath $bak0AuditPath"
        }
    
    $bak1AuditPath = "\\$ServerName\$DriveLetter`$\SQL\$Instance\bak1\Audit\CmdShell\*.sqlaudit"
    $bak0AuditPath = "\\$ServerName\$DriveLetter`$\SQL\$Instance\bak00\Audit\CmdShell\"
    IF($DryRun -eq 0)
        { 
            Move-Item $bak1AuditPath $bak0AuditPath 
        }
    ELSE
        {
            WRITE-HOST `t"[DryRun] Move-Item $bak1AuditPath $bak0AuditPath "
        }
}

# STEP 10
if ($StepToRun -eq 10 -or ($StepToRunFrom -le 10 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 10: Enable audit jobs"
    if ($jobStatuses -eq $null)
    {
        $jobStatuses = @(Invoke-Sqlcmd -ServerInstance $sqlServer -Query "SELECT name, enabled FROM msdb.dbo.sysjobs WHERE name = 'CmdshellAudit' or name = 'MembersAudit'")
    }
    foreach ($jobStatus in $jobStatuses)
    {
        if ($jobStatus["enabled"] -eq 1)
        {
            IF($DryRun -eq 0)
                { 
                    Invoke-Sqlcmd -ServerInstance $sqlServer -Query "EXEC msdb.dbo.sp_update_job @job_name = '$($jobStatus["name"])', @enabled = 1" 
                }
            ELSE
                {
                    WRITE-HOST `t"[DryRun] EXEC msdb.dbo.sp_update_job @job_name = '$($jobStatus["name"])', @enabled = 1"
                }
        }
    }
}

# STEP 11
if ($StepToRun -eq 11 -or ($StepToRunFrom -le 11 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 11: Move all .trn files that have not been copied to the FSC to Bak00"

    # Get a list of files that are on Bak1 and Bak2
    $bak1Path = "\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak1\Logs"
    $bak1Files = New-Object System.Collections.ArrayList($null)

    IF( test-Path -Path $bak1Path )
        {
            $bak1Files.AddRange(@(Get-ChildItem -Path $bak1Path -Attributes A | Select -ExpandProperty Name))
        }
    ELSE
        {
            WRITE-HOST `t"[WARNING] Path does not exist - $bak1Path"
        }
    $bak2Path = "\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak2\Logs"
    $bak2Files = New-Object System.Collections.ArrayList($null)

    IF( test-Path -Path $bak2Path )
        {
            $bak2Files.AddRange(@(Get-ChildItem -Path $bak2Path -Attributes A | Select -ExpandProperty Name))
        }
    ELSE
        {
            WRITE-HOST `t"[WARNING] Path does not exist - $bak2Path"
        }
    
    $bak00Path = "\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak00\Logs"

    # Copy any files from Bak1 to Bak00 that aren't on the FSC and remove those files from the Bak2 list so we don't do duplicate work
    foreach ($bak1File in $bak1Files)
    {
        IF($DryRun -eq 0)
            { 
                Move-Item -Path "$bak1Path\$bak1File" "$bak00Path\$bak1File"
                $bak2Files.Remove($bak1File)
            }
        ELSE
            {
                WRITE-HOST `t"[DryRun] Move-Item -Path `"$bak1Path\$bak1File`" `"$bak00Path\$bak1File`" "
                WRITE-HOST `t"[DryRun] $bak2Files.Remove($bak1File) "
            }
    }

    # Copy any files from Bak2 to Bak00 that aren't on the FSC
    foreach ($bak2File in $bak2Files)
    {
        IF($DryRun -eq 0)
            { 
                Move-Item -Path "$bak2Path\$bak2File" "$bak00Path\$bak2File" 
            }
        ELSE
            {
                WRITE-HOST `t"[DryRun] Move-Item -Path `"$bak2Path\$bak2File`" `"$bak00Path\$bak2File`" "
            }
    }
}

# STEP 12
if ($StepToRun -eq 12 -or ($StepToRunFrom -le 12 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 12: Move certs and keys from Bak1 to Bak00"
    IF($DryRun -eq 0)
        { 
            Move-Item -Path "\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak1\Keys\*" -Destination "\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak00\Keys\" 
        }
    ELSE
        {
            WRITE-HOST `t"[DryRun] Move-Item -Path `"\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak1\Keys\*`" -Destination `"\\$ServerName\$DriveLetter`$\SQL\$Instance\Bak00\Keys\`" "
        }
}

# STEP 13 - sysAdmins want empty drives to reclaim
if ($StepToRun -eq 13 -or ($StepToRunFrom -le 13 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 13: If all the log files are on the FSC, change the retention down to 12 hours"
    # If all the log files are on the FSC, change the retention down to 12 hours
    Write-Output "Changing retention for Bak1 and Bak2 to 12 hours"
    if ($newCleanerContent -eq $null)
    {
        $cleanerFilePath = "\\$ServerName\$DriveLetter`$\SQL\$Instance\Utility\ETFileCleaner\Cleaner.ini"
        $newCleanerContent = Get-Content $cleanerFilePath
    }

    $newerCleanerContent = @()
    $matchBak1 = [regex]::Escape("[path=%CURRENTDRIVE%:\SQL\%INSTANCE%\Bak1")
    $bak1LineNumber = ($newCleanerContent | Select-String -Pattern $matchBak1).LineNumber
    $matchBak2 = [regex]::Escape("[path=%CURRENTDRIVE%:\SQL\%INSTANCE%\Bak2")
    $bak2LineNumber = ($newCleanerContent | Select-String -Pattern $matchBak2).LineNumber
    for ($i = 0; $i -lt $newCleanerContent.Count; $i++)
    {
        if ($i -eq $bak1LineNumber -or $i -eq $bak2LineNumber)
        {
            $newerCleanerContent += "hours = 12"
        }
        else
        {
            $newerCleanerContent += $newCleanerContent[$i]
        }
    }

    IF($DryRun -eq 0)
        { 
            $newCleanerContent | Out-File $cleanerFilePath 
        }
    ELSE
        {
            WRITE-HOST `t"[DryRun] File Path: $cleanerFilePath"
            WRITE-HOST `t"[DryRun] File Content: $newCleanerContent"
        }
}

# STEP 14
if ($StepToRun -eq 14 -or ($StepToRunFrom -le 14 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 14: Alter SourcePath in SnapbackupDB.dbo.LogcopyConfig table on both FSC instances"
    $maInstances = @(Invoke-Sqlcmd -ServerInstance $dbaInstance -Query "SELECT MediaAgentInstanceName FROM DBA.dbo.BackupMALocation WHERE ServerName = '$ServerName'")
    foreach ($maInstance in $maInstances)
    {
        WRITE-HOST `t"Updating $($maInstance["MediaAgentInstanceName"]) "
        IF( $dryRun -eq 0 )
            {
                Invoke-Sqlcmd -ServerInstance $maInstance["MediaAgentInstanceName"] -Query "UPDATE SnapbackupDB.dbo.LogCopyConfig SET SourcePath = REPLACE(REPLACE(SourcePath,'Bak1','Bak00'),'Bak2','Bak00') WHERE SourceHost = '$ServerName.XT.LOCAL'"
            }
        ELSE
            {
                WRITE-HOST `t`t"[DryRun] UPDATE SnapbackupDB.dbo.LogCopyConfig SET SourcePath = REPLACE(REPLACE(SourcePath,'Bak1','Bak00'),'Bak2','Bak00') WHERE SourceHost = '$ServerName.XT.LOCAL'"
            }
    }
}

# STEP 15
if ($StepToRun -eq 15 -or ($StepToRunFrom -le 15 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 15: Alter table SourceInstanceCopy Path"
    $maInstances = @(Invoke-Sqlcmd -ServerInstance $dbaInstance -Query "SELECT MediaAgentInstanceName FROM DBA.dbo.BackupMALocation WHERE ServerName = '$ServerName'")

    foreach ($maInstance in $maInstances)
    {
        WRITE-HOST `t"Updating $($maInstance["MediaAgentInstanceName"]) "
        IF( $dryRun -eq 0 )
            {
                Invoke-Sqlcmd -ServerInstance $maInstance["MediaAgentInstanceName"] -Query "UPDATE DBARpts_StandbyMGR.StandbyDBmanager.dbo.SourceInstanceCopyPath SET CopyPath = REPLACE(CopyPath, 'Bak1','Bak00') WHERE SourceInstanceID IN (SELECT sourceInstanceID FROM [DBARpts_StandbyMGR].[StandbyDBmanager].[DBO].[SourceInstance] WHERE InstanceName like '$ServerName%' and CopyPath like '%Bak1%')"
            }
        ELSE
            {
                WRITE-HOST `t`t"[DryRun] UPDATE DBARpts_StandbyMGR.StandbyDBmanager.dbo.SourceInstanceCopyPath SET CopyPath = REPLACE(CopyPath, 'Bak1','Bak00') WHERE SourceInstanceID IN (SELECT sourceInstanceID FROM [DBARpts_StandbyMGR].[StandbyDBmanager].[DBO].[SourceInstance] WHERE InstanceName like '$ServerName%' and CopyPath like '%Bak1%')"
            }
    }
}

# STEP 16
if ($StepToRun -eq 16 -or ($StepToRunFrom -le 16 -and $StepToRunFrom -ne 0) -or ($StepToRun -eq 0 -and $StepToRunFrom -eq 0))
{
    Write-Output "Starting Step 16: Disabling LogCopyConfig on $disableFSC only"
    $maInstances = @(Invoke-Sqlcmd -ServerInstance $dbaInstance -Query "SELECT MediaAgentInstanceName FROM DBA.dbo.BackupMALocation WHERE ServerName = '$ServerName'")

    foreach ($maInstance in $maInstances)
    {
        if ($maInstance["MediaAgentInstanceName"] -match "$disableFSC")
        {
            WRITE-HOST `t"Updating $($maInstance["MediaAgentInstanceName"]) "
            IF( $dryRun -eq 0 )
                {       
                    WRITE-HOST `t`t"Disabling Instance"      
                    Invoke-Sqlcmd -ServerInstance $maInstance["MediaAgentInstanceName"] -Query "UPDATE SnapbackupDB.dbo.LogCopyConfig Set [Enabled] = 0 WHERE SourceHost = '$ServerName.XT.LOCAL'"
                    WRITE-HOST `t`t"Rebuilding Cluster Copy Job"
                    WRITE-VERBOSE `t"[DryRun] EXEC SnapBackupDB.dbo.dropCreateClusterCopyJOb @clusterID = '$($ServerName.Substring($ServerName.IndexOf('C') + 1, $ServerName.IndexOf('I') - $ServerName.IndexOf('C') - 1))'"
                    Invoke-Sqlcmd -ServerInstance $maInstance["MediaAgentInstanceName"] -Query "EXEC SnapBackupDB.dbo.dropCreateClusterCopyJOb @clusterID = '$($ServerName.Substring($ServerName.IndexOf('C') + 1, $ServerName.IndexOf('I') - $ServerName.IndexOf('C') - 1))'"
                }
            ELSE
                {
                    WRITE-HOST `t"[DryRun] UPDATE SnapbackupDB.dbo.LogCopyConfig Set [Enabled] = 0 WHERE SourceHost = '$ServerName.XT.LOCAL'"
                    WRITE-HOST `t"[DryRun] EXEC SnapBackupDB.dbo.dropCreateClusterCopyJOb @clusterID = '$($ServerName.Substring($ServerName.IndexOf('C') + 1, $ServerName.IndexOf('I') - $ServerName.IndexOf('C') - 1))'"
                }
        }
    }
}
<############################
Purpose: 
    This can be used to move objects from BAK1/BAK2 to BAK00

History:
        20190601 tgrieger W-###### created
        20190620 hbrotherton W-##### updates


        YYYYMMDD username W-####### changes
Comments:
    Example command:

        FULL RUN FROM START
        .\BAK00swap.ps1 -serverName ATL1P04C168i08 -driveLetter E -instance I09 

# TODO Confirm CopyMatrix Job is successful and pulling files from new location? Is this necessary for this script? Maybe a manual check done after the fact?get

# TODO how to manage the snaps?


Google Doc: https://docs.google.com/document/d/13D-7LTmYd3EGz4BQyZ5UVeT24_GJBpwfCGIOrIrgEj4/edit#

##############################>