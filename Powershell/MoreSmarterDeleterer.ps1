[cmdletbinding(SupportsShouldProcess=$True)]
PARAM ( 
        [string] $targetInstance ='IND1P02C105I05',
       # [string[]] $localBAKpath ,
        #[string[]] $targetFSC = 'IND1P02C01MA03' ,
        #[string] $remoteFSCPath = 'G:\TRN\IND1P02C109\IND1P02C109I05\Logs', ## pull from confkey ?
        [int] $retainHours = 48, ## default value - pull from confkey? / reduce only inf extreme situations
        [int] $dryRun = 1, ## default value for safety reasons / change this to 0 in the command to perform deletes.
        [int] $force = 0  # use only if you have wild abandon....and manager approval
    )

Function Get-LocalArchivedFiles
{
    param
    (   [cmdletbinding(SupportsShouldProcess=$True)]
        [string] $path ,
        [string] $Server,
        [int]    $HoursThreshold 
    )

    $ResultsArray = @()
    $ThresholdDate = (get-date).AddHours(-$HoursThreshold)

    $files = Get-ChildItem -Path $path -include *.trn -Recurse 
    $attribute = [io.fileattributes]::archive

    # Check for the Archive Bit and date time stamp for the files
    Foreach($file in $files)
    {
        IF ($file.CreationTime -lt $ThresholdDate)
        {
            If((Get-ItemProperty -Path $file.fullname).attributes -band $attribute )
                { 
                    #ADD to return Array with a type of SAVE? 
                    WRITE-VERBOSE "[Skipping] $file does not appear to have been backed up" 
                }
            ELSE
                { 
                    #ADD to return array with a type of REMOVABLE?
                    $FileDate = $file.CreationTime 
                    $ResultsArray += New-Object PSObject -Property @{ServerName=$Server;FilePath=$path;FileName=$file;FileCreationDate=$FileDate; ThresholdDate=$ThresholdDate}
                }         
        }  # IF ($file.CreationTime -lt $ThresholdDate)
    } # Foreach($file in $files)

    $resultsArray 
} #end of function

Function Get-RemoteArchivedFiles
{
    param
    (
        [string] $path , ##='G:\TRN\IND1P\ATL1P04C129I07\Logs\',
        [string] $Server , ##='ATL1P04C01MA03',
        [int]    $HoursThreshold
    )

    $ThresholdDate = (get-date).AddHours(-$HoursThreshold)

    $files = Invoke-Command -ComputerName $server { Get-ChildItem -Path $($args[0]) -include *.trn -Recurse } -argumentlist $path

    $RemoteResultsArray = @()

    # Just grabbing all files from repository...being lazy
    Foreach($file in $files)
    {
        IF ($file.CreationTime -lt $ThresholdDate)
        {
            #DryRun info WRITE-VERBOSE "$file.fullname file on remote repository"
            $FileDate = $file.CreationTime 
            $RemoteResultsArray += New-Object PSObject -Property @{ServerName=$Server;FilePath=$path;FileName=$file;FileCreationDate=$FileDate; ThresholdDate=$ThresholdDate}
        }    
    } # Foreach($file in $files)

    $RemoteResultsArray 
} #end of function

$localBAKpath = @()
$deleteLocalFiles = @()

# first sanity check
IF($retainHours -lt 48 -AND $force -eq 0)
    {
        WRITE-OUTPUT " "
        WRITE-OUTPUT "[ALERT] Parameter retainHours is less than 48 hours and parameter FORCE was not supplied."
        WRITE-OUTPUT "Only use the parameter FORCE in extreme situations and you are certain...maybe get a manager to sign off"
        BREAK
    }

WRITE-OUTPUT "[] Start Time: $(Get-Date)"
IF( $force -ne 0 ){WRITE-OUTPUT "[WARNING] USING FORCE - no guardrails and deletes will happen";$dryRun = 0 }
WRITE-OUTPUT "[] DryRun: $($dryRun)"
WRITE-OUTPUT " "
WRITE-OUTPUT "[] LOCAL Instance: $($targetInstance)"
IF((Test-Connection -Cn $($targetInstance.subString(0,$targetInstance.IndexOf("\"))) -BufferSize 16 -Count 1 -ea 0 -quiet))
    {
        $selectSQL = "SELECT SystemPath FROM utility.[dbabackup].[BackupPathSet] AS BPS LEFT JOIN utility.[dbabackup].[BackupPath] as BP ON (BPS.BackupPathSetID = BP.BackupPathSetID) WHERE BPS.name = 'DefaultLog'"
        $localBAKpath = @(Invoke-Sqlcmd -ServerInstance $targetInstance -Database 'UTILITY' -Query $selectSQL | select -exp systemPath)
    }
ELSE
    {
        WRITE-OUTPUT "[ALERT] LOCAL UtilityDB unreachable: $targetInstance" 
    }

ForEach( $localPath in $localBAKpath )
{
    $LocalArchivedFiles = @()
    $RemoteArchivedFiles = @()

    WRITE-OUTPUT "[] LOCAL PATH: $($localPath)\Logs"
    WRITE-OUTPUT "[] Checking for LOCAL Files older than: $($retainHours) hours"
    IF(Test-Path -Path $localPath)
        {
            $LocalArchivedFiles = Get-LocalArchivedFiles "$($localPath)\Logs" $targetInstance $retainHours
        }
    ELSE
        {
            WRITE-OUTPUT "[ALERT] LOCAL Path unreachable: $localPath"
        }
    #$LocalArchivedFiles | Format-Table -AutoSize
    WRITE-OUTPUT "`t Local Files found: $($LocalArchivedFiles.Count)"
    IF( $($LocalArchivedFiles.Count) -ne 0 )
        {
            $selectSQL = "IF('$($localPath)' like '%Bak1%')
	                    BEGIN
		                    SELECT distinct MediaAgentInstanceName as targetFSC
		                    FROM DBA.[dbo].[BackupMALocation] 
		                    WHERE ServerName = '$($targetInstance.subString(0,$targetInstance.IndexOf("\")))' 
                                and (MediaAgentInstanceName like '%C01MA%' or MediaAgentInstanceName like '%MA05%')
		                    order by MediaAgentInstanceName
	                    END
                    ELSE
	                    BEGIN
		                    SELECT distinct MediaAgentInstanceName as targetFSC
		                    FROM DBA.[dbo].[BackupMALocation] 
		                    WHERE ServerName = '$($targetInstance.subString(0,$targetInstance.IndexOf("\")))' 
                                and (MediaAgentInstanceName like '%C02MA%' or MediaAgentInstanceName like '%MA06%')
		                    order by MediaAgentInstanceName
	                    END"

            $targetFSC = Invoke-Sqlcmd -ServerInstance 'XTINP1DBA01\dbAdmin' -Database 'DBA' -Query $selectSQL | select -exp targetFSC

            $selectSQL = "SELECT destPath FROM logCopyConfig WHERE sourceHost LIKE '$($targetInstance.subString(0,$targetInstance.IndexOf("\")))%' AND sourcePath = '$($localPath)\Logs' AND ENABLED = 1"
            $remoteFSCPath = Invoke-Sqlcmd -ServerInstance $targetFSC -Database 'SnapBackupDB' -Query $selectSQL | select -exp destPath

            WRITE-OUTPUT "[] RemoteHost: $($targetFSC)"
            WRITE-OUTPUT "[] Remote Path: $($remoteFSCPath)"
            WRITE-OUTPUT "[] Gathering Files older than: $($retainHours) hours"
            IF((Test-Connection -Cn $($targetFSC.subString(0,$targetFSC.IndexOf("\"))) -BufferSize 16 -Count 1 -ea 0 -quiet))
                {
                    $RemoteArchivedFiles = Get-RemoteArchivedFiles $remoteFSCPath $($targetFSC.subString(0,$targetFSC.IndexOf("\"))) 
                }
            ELSE
                {
                    WRITE-OUTPUT "[ALERT] Remote Repository unreachable: $targetFSC" 
                    BREAK
                }
            #$RemoteArchivedFiles | Format-Table -AutoSize
            WRITE-OUTPUT "`t Remote Files found: $($RemoteArchivedFiles.Count)"

            $remoteFiles = @()
            $remoteFiles = split-Path -Path $remoteArchivedFiles.fileName -leaf
            WRITE-VERBOSE "Remote LEAFS found: $($remoteFiles.Count)"

            ForEach ($LocalItem in $LocalArchivedFiles ) 
            { 
                WRITE-VERBOSE "Checking: $($LocalItem.FileName)"
                TRY   {    $searchFile = split-Path -Path $LocalItem.FileName -leaf }
                CATCH { WRITE-VERBOSE "[] FAILURE  "; $localItem | format-Table -AutoSize }
 
                IF ($remoteFiles -contains $searchFile) 
                {
                    WRITE-VERBOSE "Safe to Delete: $searchFile"
                    $deleteLocalFiles += New-Object PSObject -Property @{ServerName=$TargetInstance;FilePath=$localPath;FileName=$LocalItem.FileName}
                }    
            }
        }
    ELSE
        {
            WRITE-OUTPUT "[] Skipping remote inventory"
            WRITE-OUTPUT " "
        }
} # ForEach( $localPath in $localBAKpath )

IF( $($deleteLocalFiles.count) -ne 0 )
{
    WRITE-OUTPUT "[] Files Safe to DELETE: $($deleteLocalFiles.count)"
    IF( $dryRun -eq 1 )
        {
            $deleteLocalFiles | format-table -AutoSize

            WRITE-OUTPUT "[] IF these results look good issue same command with '-dryRun 0'"
        }
    ELSE
        {
            ForEach( $delItem in $deleteLocalFiles )
            {
                WRITE-VERBOSE "Removing: $($delItem.fileName) "
                remove-item -Path $delItem.fileName 
            }

            IF($retainHours -gt 48)
                {
                    WRITE-OUTPUT "[] Change cleaner.INI retention to: $($retainHours) hours"
                    WRITE-OUTPUT "[] cleaner.INI should be located: $($tempPath.substring(0,$tempPath.Length -4))Utility\ETFileCleaner\cleaner.ini'"
                }
            ELSE
                {
                    WRITE-OUTPUT "[] Change cleaner.INI retention to: 48 hours"
                    WRITE-OUTPUT "[] cleaner.INI should be located: $($tempPath.substring(0,$tempPath.Length -4))Utility\ETFileCleaner\cleaner.ini'"
                }
        }
}



<##########################################
Purpose: This should be called by a SQL agent job as a reaction to a failed backup.



Command examples:
    .\moreSmarterDeleterer.ps1 'IND1P02C105I05' -retainHours 48 -dryRun 0 -verbose
    .\moreSmarterDeleterer.ps1 'IND1P02C105I05' -retainHours 48 -dryRun 0 -verbose

##########################################>