PARAM(
		[Parameter(Position=0)]
		[Alias("setID")]
		[int] $CopySetID = 0,

 		[Parameter(Position=1)]
		[Alias("logCSID")]       
        [string] $logCopyConfigID = "%",
	
 		[Parameter(Position=2)]
		[Alias("sqlHost")]       
        [string] $searchHost = "",
 		
        [Parameter(Position=3)]
		[Alias("mediahost")]       
        [string]$mediaServer = "" ,

 		[Parameter(Position=4)]
		[Alias("cutOff")]       
        [int] $hoursCutOff = 0,
                	
 		[Parameter(Position=5)]
		[Alias("testRun")]       
        [int] $dryrun = 0

        )

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Xml.XmlDocument");
[void][System.Reflection.Assembly]::LoadWithPartialName("System.IO");
<#IF ($host.Name -eq “ConsoleHost” -or $host.name -eq "Windows PowerShell ISE Host")
{
    $pshost = Get-Host              # Get the PowerShell Host.
    $pswindow = $pshost.UI.RawUI    # Get the PowerShell Host's UI.
    $newsize = $pswindow.BufferSize # Get the UI's current Buffer Size.
    $newsize.width = 200            # Set the new buffer's width to 150 columns.
    $pswindow.buffersize = $newsize # Set the new Buffer Size as active.
    $newsize = $pswindow.windowsize # Get the UI's current Window Size.
    $newsize.width = 200            # Set the new Window Width to 150 columns.
    $pswindow.windowsize = $newsize # Set the new Window Size as active.
}#>
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

function copyFiles-UNCv2 ( [string] $sourceLocation ,[string] $destinationLocation,[string] $filePrefix,[bool] $checkArchiveBit,[int] $debug )
{      
    write-output "[] Test-Path: Look for orphaned copies $destinationLocation "
    $destCMD = "Get-ChildItem -Path $destinationLocation\ -Filter *.tmp "
    #write-output $destCMD
    $destinationFiles = invoke-expression $destCMD
    $fileCount = $destinationFiles.Count

    	
    if($debug -eq 1)
   	{
        write-output "[DEBUG] .TMP files in destination $fileCount "
        Write-output $destinationFiles 
   	}
    ELSE
    {
        write-output `t".TMP files in destination $fileCount "
        IF($fileCount -gt 0)
        {
            TRY
            {
                WRITE-output `t"REM0VING files"
                $removeCMD = "remove-item -PATH $destinationLocation\*.tmp -Force"
                invoke-expression $removeCMD
            }
            CATCH # Does not appear to catch properly
            {
                #WRITE-OUTPUT "[PANIC] - Undecided how to handle an undeleteable file....restart?  Just skip?"
                #echo $_.Exception.GetType().FullName, $_.Exception.Message
                $currentError = $_.Exception.Message -REPLACE "'",""
                write-output `t"[WARNING] Delete failed $currentError"
                $returnValue = 1
            }
        }
    }

    $currentCutOff = (get-date).addhours(-$hoursCutOff)
    write-output "[] Get source Files older than $currentCutOff"

<## get the files in the source location
    SKIP -2 remove the most recent file from the source list (configDB, ET###)
    we'll pick them up next time.
 ##>
            
    IF($checkArchiveBit -eq 1)
    {
        write-output `t"Archive = 1"
        write-output `t"We need to copy ALL the non-archived files."
        $remoteCMD = "Invoke-Command -Computer $sourceHost -ScriptBlock { Get-ChildItem -Attributes Archive -Path $sourceLocation\ | where LastAccessTime -lt '$CutOff' | Sort-Object LastAccessTime -Descending | Select-Object -skip 2 }"
        #write-output $remoteCMD
        $sourceFiles = @(invoke-expression $remoteCMD )

        $filesToCopy = $sourceFiles.name | Sort-Object LastAccessTime #-Ascending
        write-output " "
    }
    ELSE
    {
        write-output `t"We'll just copy the ones that don't exist."
        $remoteCMD = "Invoke-Command -Computer $sourceHost -ScriptBlock { Get-ChildItem -Path $sourceLocation\ | where-object LastWriteTime -lt (get-date).addhours(-$hoursCutOff) | Sort-Object LastWriteTime -Descending | Select-Object -skip 2 }"
        #write-output $remoteCMD
        $sourceFiles = @(invoke-expression $remoteCMD )
        write-output "[] Get destination Files for comparison."
        $remoteCMD = "Invoke-Command -Computer "+ $mediaServer.replace('\I1','.xt.local') +" -ScriptBlock { Get-ChildItem -Path $destinationLocation\ }"
        #write-output $remoteCMD
        $destinationFiles = invoke-expression $remoteCMD
        IF($debug -eq 1)
   	    {
	        write-output "[DEBUG] destinationFiles"	
            Write-output $destinationFiles 
   	    }

        $filesToCopy = compare-object -ReferenceObject $sourceFiles -DifferenceObject $destinationFiles -PassThru | Sort-Object LastAccessTime #-Ascending
        write-output " "
    }

    $fileCount = $sourcefiles.Count

    IF($debug -eq 1)
        {	
	        write-output "[DEBUG] filesToCopy $fileCount"	
            Write-output $filesToCopy
        }
    ELSE
        {
            write-output "[] filesToCopy $fileCount"
        }
     
    IF (($host.Name -eq “ConsoleHost” -or $host.name -eq "Windows PowerShell ISE Host") -AND ($cursorCount -eq 1))
        {
            write-output " "
            $confirmation = Read-Host "Are you Sure You Want To Proceed: y to continue or anything else to exit"
            if ($confirmation -ne 'y') {  return  }
            write-output " "
        }   
    $myCounter = 0

    # begin the copy loop
    $filesToCopy | forEach-object{  
                                    $startTime = get-date
                                    write-output "$startTime"
                                    $returnValue = 1
                                    $myCounter++
                                    write-output "[$myCounter / $fileCount]"
                                    IF($skipCopy -eq 0)
                                    {
                                        write-output "`t[] Copying File $_ "
                                        # if run on the local media agent
                                        #$copyCMD = "Copy-Item -Path D:\"+ $newSourceDB +".init.bak -Destination \\"+ $targetDBHost +"\"+$rootTargetPath.replace(":","$")+"BAK1\"
                                        # if run remotely
                                        $copyCMD = 'copy-Item -Path '+ $sourceLocation +'\'+ $_ +' -Destination '+ $destinationLocation +'\'+$_ +'.tmp -Force'
                                        # Overwrite *.TMP files # $checkDest = $destinationLocation +'\'+ $_ +'.tmp'
                                        # to see progress using roboCopy - cannot rename in flight
                                        #$roboCopyOptions = " /NJH /NJS "
                                        #$copyCMD = "roboCopy $sourceLocation $destinationLocation $_ $roboCopyOptions.split(' ')"
                                        
                                        $checkDest = $destinationLocation +'\'+ $_

                                        write-output "`t`t Check TARGET for $checkDest "
                                        IF(Test-Path $checkDest -PathType Leaf)  #yes it exists
                                        {
                                            #This isn't working as expected.
                                            write-output "`t[] File exists - skipping copy "
                                            $returnValue = 0
                                        }
                                        ELSE
                                        {
                                            
                                            $checkSource = $sourceLocation +'\'+ $_
                                            write-output "`t`t Check SOURCE for $checkSource "
                                            IF(Test-Path $checkSource -PathType Leaf)  #yes it exists
                                            {
                                 
                                                Try
                                                {
                                                    # write-output "`t`t $copyCMD"
                                                    if($debug -ne 1)
                                                    {
                                                        invoke-expression $copyCMD
                                                    }
                                                    ELSE
                                                    {
                                                        write-output "`t[DEBUG] Copy skipped "
                                                    }
                                                    #uncomment when copying to .TMP
                                                    $checkDest = $destinationLocation +'\'+ $_ +'.tmp'

                                                    write-output "`t`t Check TARGET for $checkDest "
                                                    IF(Test-Path $checkDest -PathType Leaf)  #yes it exists
                                                    {
                                                        #This isn't working as expected.
                                                        write-output "`t[] Copy successful "
                                                        $returnValue = 0
                                                    }
                                                    ELSE
                                                    {
                                                        if($debug -ne 1)
                                                        {
                                                            #write-output `t"[2] Copy failed"
                                                            #echo $_.Exception.GetType().FullName, $_.Exception.Message
                                                            $currentError = $_.Exception.Message -REPLACE "'",""
                                                            write-output `t"[WARNING] Copy failed $currentError"
                                                            $returnValue = 1

                                                            #  Should we try and delete files?

                                                        }
                                                        ELSE
                                                        {
                                                            write-output "`t[DEBUG] Move skipped " 
                                                        }
                                                    }
                                                }
                                                CATCH
                                                {
                                                    #write-output `t"[1] Copy failed"
                                                    #echo $_.Exception.GetType().FullName, $_.Exception.Message
                                                    $currentError = $_.Exception.Message -REPLACE "'",""
                                                    write-output `t"[WARNING] Copy failed $currentError"
                                                    $returnValue = 1
                                                }
                                            }
                                            ELSE
                                            {
                                                write-output "[WARNING] File no longer exists !!! "
                                                $returnValue = 1
                                            }

                                            IF($returnValue -eq 0) 
                                            {
                                                write-output "`t[] Rename file "
                                                $moveCMD = 'move '+ $destinationLocation +'\'+ $_ +'.tmp '+ $destinationLocation +'\'+ $_ +' -Force'
                                                # $renameCMD = 'rename-Item '+ $destinationLocation +'\'+ $_ +'.tmp '+ $_
                                                # write-output "`t`t $moveCMD"
                                                invoke-expression $moveCMD

                                                $checkDest = $destinationLocation +'\'+ $_
                                                write-output "`t`t Check for $checkDest "
                                                IF(Test-Path $checkDest -PathType Leaf)  #yes it exists
                                                {
                                                    #This isn't working as expected.
                                                    write-output "`t[] Rename Successful "
                                                    $returnValue = 0
                                                }
                                                ELSE
                                                {
                                                     write-output "`t[] Rename Failed "
                                                    $returnValue = 1
                                                }
                                            }

                                        }
                                        
                                    }
                                    ELSE
                                    {
                                        write-output `t"Skipping Copy because @SkipCopy = 1 . Will still clear archive bit if @checkArchivebit=1 -- would have run:"
                                        
                                        $returnValue = 0
                                    }

                                    If($returnValue -eq 0 -AND $checkArchiveBit -eq 1)
                                    {
                                        write-output "`t[] Clear archive bit on source file $_ "
                                        $script = 'Set-ItemProperty -Path '+ $sourceLocation +'\'+ $_ +' -Name Attributes -value normal'
                                        $remoteCMD = "Invoke-Command -Computer $sourceHost -ScriptBlock { $script }"
                                        #write-output $remoteCMD
                                        invoke-expression $remoteCMD
                                    
                                    }
                                 }

    write-output "[] Copies complete"
    Get-Date
    write-output " "
}

if ($host.Name -eq “ConsoleHost” -or $host.name -eq "Windows PowerShell ISE Host")
{
    #clear
	
    $myInvocation.MyCommand.Name
}

	Import-SqlModule

    IF($searchHost -eq "" )
    {
	    $getList_sqlCMD =
		    "SELECT  [Name],[SourceHost],[SourcePath],[DestPath],[FilePrefix],[CheckArchiveBit],[SkipCopy]
		      -- ,[SilenceAlertUntil]
		      -- ,[Enabled]
		    FROM [snapBackupDB].[dbo].[LogCopyConfig] (NOLOCK)
		    WHERE [Enabled] = 1 and [CopySetID] = $CopySetID and LogCopyConfigID like '$logCopyConfigID' ;"
    }
    ELSE
    {
        $getList_sqlCMD =
		    "SELECT  [Name],[SourceHost],[SourcePath],[DestPath],[FilePrefix],[CheckArchiveBit],[SkipCopy]
		      -- ,[SilenceAlertUntil]
		      -- ,[Enabled]
		    FROM [snapBackupDB].[dbo].[LogCopyConfig] (NOLOCK)
            WHERE [Enabled] = 1 and sourceHost like '$searchHost"+"%';"
		   # WHERE [Enabled] = 1 and [CopySetID] = $CopySetID and sourceHost like '$searchHost"+".%';"
    }
    #write-output $getList_sqlCMD

    $copyList_cursor = @(invoke-sqlcmd -ServerInstance $mediaServer  -Query $getList_sqlCMD | select name, sourceHost, sourcePath, destPath, filePrefix, checkArchiveBit, skipCopy )

    if($debug -ne 1)
    {
        $cursorCount = $copyList_cursor.Count
        write-VERBOSE "Instances to manage: $cursorCount "
    }
    ELSE
    {
        write-VERBOSE $copyList_cursor.name
    }
	$copyList_cursor | forEach-object{  Get-Date
                                        write-output " "

                                        $name = $_.name
                                        write-output "Name: $name"
                                        $sourceHost = $_.sourceHost
                                        write-output "SourceHost: $sourceHost"
                                        $sourcePath = $_.sourcePath #+"2"
                                        #write-VERBOSE "SourcePath: $sourcePath"
                                        $fullPath = '\\' + $SourceHost + '\' +$SourcePath.replace( ':', '$');
                                        write-output "fullPath: $fullPath"
                                        
                                        IF( -Not (Test-Path $fullPath.trim() ))
                                            {
                                                WRITE-OUTPUT "[WARNING] Source path not found - Skipping Instance"
                                            }
                                        ELSE
                                            {
                                                WRITE-VERBOSE "Source Path found."
                                                write-output " "
                                                write-output "MediaServer: $mediaServer "
                                                $destPath = $_.destPath
                                                #write-output "DestPath: $destPath"
                                                #IF( $destPath.substring(1,1) -eq ':' )
                                                #{
                                                    $fullDestPath = '\\' + $mediaServer.REPLACE('\I1','.XT.LOCAL') + '\' +$destPath.replace( ':', '$');
                                                #}
                                                #ELSE 
                                                #{
                                                    $fullDestPath = $destPath
                                                #}
                                                write-output "fullDestPath: $fullDestPath"
                                                IF( -Not (Test-Path $fullDestPath.trim() ))
                                                    {
                                                        WRITE-VERBOSE "Creating new Destination folder on FSC"
                                                        New-Item -Path $fullDestPath -ItemType Directory | out-null
                                                    }
                                                ELSE
                                                    {
                                                        WRITE-VERBOSE "Destination path found."
                                                    }

                                                write-output " "
                                                $filePrefix = $_.filePrefix
                                                write-output "filePrefix: $filePrefix"
                                                $checkArchiveBit = $_.checkARchiveBit
                                                write-output "CheckArchiveBit: $checkArchiveBit"
                                                $skipCopy = $_.skipCopy
                                                write-output "SkipCopy: $skipCopy"
                                                $debug = $dryRun
                                                write-output "Debug: $debug"
                                                Write-output "Hours before now: $hoursCutOff"
                                                $cutOff = (get-date).addhours(-$hoursCutOff) 
                                                write-output "Cut off: $cutOff"
                                                write-output " "

                                                copyFiles-UNCv2 $fullPath $fullDestPath $filePrefix $checkArchiveBit $debug
                                            }

    }
<####################################
 
 

Run against entire cluster specify cluster name and terminate with "I" or "D"
    \\XTINP1DBA01\GitHub\dbops_workingfolders\dbops\Harold\powerShell\archiveBackup5.1.ps1 -searchHost "ATL1P04C011I" -mediaServer "XTGAP4MA06\I1"
Run against single instance sepecify instance name and terminate with ".XT"    
    \\XTINP1DBA01\GitHub\dbops_workingfolders\dbops\Harold\powerShell\archiveBackup5.1.ps1 -searchHost "IND1P01C033I03.XT" -mediaServer "XTINP1MA05\I1"
    \\XTINP1DBA01\GitHub\dbops_workingfolders\dbops\Harold\powerShell\archiveBackup5.1.ps1 -searchHost "IND1P01C033I03.XT" -mediaServer "XTINP1MA06\I1"

Run against entire cluster with ID = 101
    \\XTINP1DBA01\GitHub\dbops_workingfolders\dbops\Harold\powerShell\archiveBackup5.1.ps1 -copySetID 101 -mediaServer "XTGAP4MA06\I1"
Run against single instance with cluster id = 102 and instance id = 708
    \\XTINP1DBA01\GitHub\dbops_workingfolders\dbops\Harold\powerShell\archiveBackup5.1.ps1 -copySetID 1012 -logCopyConfigID 708 -mediaServer "XTGAP4MA06\I1"

#####################################>
