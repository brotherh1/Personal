 <####################################
# Golden Gate Status Monitor
# Developed: Sarjen Haque

\\XTINP1DBA01\GitHub\dbops_workingfolders\dbops\Harold\powerShell\ggWork.ps1 -newSourceDB "LinkS01S66" -debug 1
#####################################>

　
PARAM(
		[Parameter(Position=0)]
		[Alias("OPS")]
		[string]$targetOPS="XTINOPSD2\i2",

		[Parameter(Position=1)]
		[Alias("template")]
		[string]$targetTemplate="XTINP1CL13D12\i12",

		[Parameter(Position=2)]
		[Alias("sourceDB")]
		[string]$newSourceDB="LInkS01S65",

		[Parameter(Position=3)]
		[Alias("templateLinkDB")]
		[string]$templateLink="LInkSXXyy",

		[Parameter(Position=4)]
		[Alias("replicats")]
		[int]$numReplicat=4,

		[Parameter(Position=5)]
		[Alias("dryRun")]
		[int]$myDebug=0,

        [Parameter(Position=6)]
		[Alias("brute")]
        [switch]$force 
    )

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Xml.XmlDocument");
[void][System.Reflection.Assembly]::LoadWithPartialName("System.IO");
$pshost = Get-Host              # Get the PowerShell Host.
$pswindow = $pshost.UI.RawUI    # Get the PowerShell Host's UI.
$newsize = $pswindow.BufferSize # Get the UI's current Buffer Size.
$newsize.width = 150            # Set the new buffer's width to 150 columns.
$pswindow.buffersize = $newsize # Set the new Buffer Size as active.
$newsize = $pswindow.windowsize # Get the UI's current Window Size.
$newsize.width = 150            # Set the new Window Width to 150 columns.
$pswindow.windowsize = $newsize # Set the new Window Size as active.

IF ( (Get-PSSnapin -Name sqlserverprovidersnapin100 -ErrorAction SilentlyContinue) -eq $null )
    {
        Add-PsSnapin sqlserverprovidersnapin100
    }
IF ( (Get-PSSnapin -Name sqlservercmdletsnapin100 -ErrorAction SilentlyContinue) -eq $null )
    {
        Add-PsSnapin sqlservercmdletsnapin100
    }

function object-init ([string] $whatType,  [string] $currentPath, [string] $currentObject )
{
     IF($whatType -eq "REPLICAT")
     {
        $executeCMD = "CMD /c `" echo OBEY "+ $currentPath.Replace("ggsci","autoconfig") + "\"+ $currentObject +".init `" | $currentPath"
        write-output "`t`t $executeCMD "
        $remoteCMD = "Invoke-Command -ComputerName $targetDBHost -ScriptBlock { $executeCMD }"

        If($myDeBug -eq 1)
        {
            write-output "`t[DEBUG] $remoteCMD "
        }
        ELSE
        {
            #write-output "`t`t $remoteCMD "
            invoke-expression $remoteCMD > $null # >$null to remove creation response from operating system
        }

     }
     ELSE
     {
        $executeCMD = "CMD /c `" echo OBEY "+ $currentPath.Replace("ggsci","autoconfig") + "\"+ $currentObject +".init `" | $currentPath"
        write-output "`t`t $executeCMD "
        If($myDeBug -eq 1)
        {
            write-output "`t[DEBUG] $executeCMD "
        }
        ELSE
        {
            invoke-expression $executeCMD > $null # >$null to remove creation response from operating system
        }
      }
}

function change-status ([string] $whatType, [string] $objectName, [string] $exePath,[string] $newStatus)
{
     
     IF($whatType -eq "REPLICAT")
     {
       [int]$tempCounter = 0
        WHILE( $tempCounter -lt $numReplicat )
        {
            [string]$currentReplicat = $objectName + ([int]$tempCounter+1)

            $executeCMD = "CMD /c echo $newStatus $currentReplicat | $exePath "
            write-output "`t`t $executeCMD "
            $remoteCMD = "Invoke-Command -ComputerName $targetDBHost -ScriptBlock { $executeCMD }"
            
            If($myDeBug -eq 1)
            {
                write-output "`t[DEBUG] $remoteCMD "
            }
            ELSE
            {
                #write-output "`t`t $remoteCMD "
                invoke-expression $remoteCMD > $null # >$null to remove creation response from operating system
            }

            $tempcounter++
        }
     }
     ELSE
     {
        #write-output `t"$newStatus $whatType $objectName"
        $currentCMD = "CMD /c echo $newStatus $objectName | $exePath "
        write-output "`t`t $currentCMD "
        If($myDeBug -eq 1)
        {
            write-output "`t[DEBUG] $currentCMD "
        }
        ELSE
        {
            invoke-expression $currentCMD > $null # >$null to remove creation response from operating system
        }
     }

}

function trailFile-check ([string] $whatType, [string] $objectName, [string] $exePath, [string] $expectedValue)
{ 
    $trailPath = $exePath.Replace("\GGS\ggsci","") +"\L"+ $objectName +"*"
    write-output "`t`t Check for $trailPath "
    IF(((Test-Path $trailPath -PathType Leaf) -eq $expectedValue ))
    {
        #This isn't working as expected.
        write-output "`t[OK] Directory Clean "
      
    }
    ELSE
    {
        If( $expectedValue = "False" )
        {
            write-output "`t[FAIL] File(s) exists - FREAK OUT!"
        }
        ELSE 
        {
            write-output "`t[FAIL] File(s) missing - FREAK OUT!"
        }
        #EXIT
    }

}

function Get-status ([string] $whatType, [string] $objectName, [string] $exePath, [string] $expectedValue)
{    <####################################
      # Golden Gate Status Monitor
      # Developed: Sarjen Haque
      #####################################>

     #write-host "[type,name,path,value] $whatType $objectName $exePath $expectedValue "
     $objectStatus = ""

     $String = "CMD /c echo Status All | $exePath "
     write-host `t`t" $String"

     IF($whatType -eq "REPLICAT")
     {
        #    [int]$tempCounter = 0
        #    WHILE( $tempCounter -lt $numReplicat )
        #    {
        #        $expectedStatus="RUNNING"
        #        [string]$currentReplicat = $replicatName + ([int]$tempCounter+1)
        #        write-output `t"Confirm $currentReplicat Status = $expectedStatus"
        #        Get-status "REPLICAT" $currentReplicat $ggsciTargetPath $expectedStatus #
        #
        #        $tempcounter++
        #    }
        $remoteCMD = "Invoke-Command -ComputerName $targetDBHost -ScriptBlock { $String }"
        $result = Invoke-Expression $remoteCMD
     }
     ELSE
     {
        
        $result = invoke-Expression $String
     }

     #write-output $result 
     $raw = $result -match $objectName
     #write-output $raw
     [StringSplitOptions]$Options = "RemoveEmptyEntries"
    
     # loop through each line and break
     foreach ($line in $raw)
     {
           $wrd = $line.Split(" ", $Options)
           $lg = $wrd[3].Split(":")
           $tm = $wrd[4].Split(":")
                    
           $result = [Ordered]@{
                    "Program" = $wrd[0];
                    "Status" = $wrd[1];
                    "Name" = $wrd[2];
                    "LagMin" = [int]$lg[0] * 60 + [int]$lg[1];
                    "Lag" = $wrd[3];
                    "ChkPt" = $wrd[4];
                    "ChkPtMin" = [int]$tm[0] * 60 + [int]$tm[1];
           }
           $obj = New-Object -TypeName PSObject -Property $result

　
           #write-output `t`t"Confirm $whatType $objectName Status $expectedValue"
           
           $objectStatus = $obj | Where-object {$_.Name -eq $objectName} | select -EXP Status

          
          #  Write-Output $obj
          #  RETURN
     }

      
           
    If($objectStatus -eq $expectedValue)
    {
        write-output `t"[OK] $objectName - $objectStatus"
    }
    ELSE
    {
        If(!$objectStatus) {$objectStatus = "NONEXISTENT" }
        write-output `t"[FAIL] $objectName - $objectStatus - Haulting progress"
        #EXIT
       
    } 
     
}

function database-discover ( [string] $currentHost )
{
    Write-output `t"Discovering new databases with option 1 on host: $currentHost"
        TRY
        {
            $execSQL = "EXEC Utility.dbabackup.DiscoverInstanceDatabases 1"
            If($myDeBug -eq 1)
            {
                write-output "`t[DEBUG] $execSQL "
            }
            ELSE
            {
                #write-Output `t"$execSQL"
                invoke-sqlcmd -ServerInstance $currentHost  -Query $execSQL
            }
            
        }
        CATCH
        {
            #echo $_.Exception.GetType().FullName, $_.Exception.Message
            $currentError = $_.Exception.Message -REPLACE "'",""
            write-output "[WARNING] $currentError" 
            EXIT                     
        }

}

function database-restore ( [string] $restoreCommand, [string] $restoreServer  )
{
    #Write-output "[] Restore New Source DB from Backup: "
        TRY
        {
            $restoreShort =  $restoreCommand.Substring(0,28)
            If($myDeBug -eq 1)
            {
                write-output "`t[DEBUG] $restoreShort "
            }
            ELSE
            {   # EXISTENCE check

                #write-output `t $restoreCommand.Substring(0,10) 
                invoke-sqlcmd -ServerInstance $restoreServer  -Query $restoreCommand -QueryTimeout 60000
            }
            
        }
        CATCH
        {
            #echo $_.Exception.GetType().FullName, $_.Exception.Message
            $currentError = $_.Exception.Message -REPLACE "'",""
            write-output "[WARNING] $currentError" 
            EXIT       
        }
 }

#############################################################################################
cls

write-output "[] Started: $((Get-Date).ToString())"
Write-Output "[] OPS Data Store: $targetOPS "
Write-Output "[] Template Server: $targetTemplate "
Write-Output "[] Source DB: $newSourceDB "
Write-Output "[] Debug: $myDeBug "
Write-Output "[] Force Deploy: $force "
#Write-Output "[] Failure Notification: $errorEmail "
#Write-output "[] Columns: srv, $renameColumns "
Write-Output "   "

TRY
{
    Write-Output "[] SET Source DB Info: $newSourceDB  "
    
    $selectSQL = "select * FROM dbops.ggate.ggsetup WHERE sourceDatabase = '"+ $newSourceDB +"'"
    #write-output `t$selectSQL
    $sourceDBInfo = invoke-sqlcmd -ServerInstance $targetOPS  -Query $selectSQL
            
    $sourceDBHost = $sourceDBInfo.SourceHost
    Write-Output `t"Source DB Host: $sourceDBHost "    

    $sourceDBInst = $sourceDBHost +"\"+ $sourceDBHost.subString($sourceDBHost.LastIndexOf("D"),$sourceDBHost.Length-$sourceDBHost.LastIndexOf("D")).replace("D","I")
    Write-Output `t"Source DB Host: $sourceDBInst " 

    $rootSourcePath = $sourceDBInfo.SourcePaths
    $rootSourcePath = $rootSourcePath.Substring(0,$sourceDBInfo.SourcePaths.indexOf("\Data01") ) -replace($newSourceDB,"") 
    $ggsciSourcePath = $rootSourcePath+"GoldenGate\Data01\GGS\ggsci"
    write-output `t"GGSCI Path: $ggsciSourcePath "
    
    $extractName = $sourceDBInfo.ExtractProcess        
    Write-Output `t"Extract Name: $extractName "    
    
    $pumpName = $sourceDBInfo.PumpProcess       
    Write-Output `t"Pump Name: $pumpName "

    $sourceODBC = $sourceDBInfo.SourceODBCConfig
    #Write-Output `t"Source ODBC Config: $sourceODBC"
    
    $createExtract = $sourceDBInfo.CreateExtract

    $createPump = $sourceDBInfo.CreatePump

    $initializeExtractPump = $sourceDBInfo.InitializeExtractPump
  
    $restoreSourceDB = $sourceDBInfo.RestoreSource
    #Write-Output `t"Restore Source DB:  $sourceDBInfo.RestoreSource "

    $trailFileLetter = $sourceDBInfo.TrailFileLetter
    Write-Output `t"Trail File Letter: $trailFileLetter"

    $targetDB = $sourceDBInfo.TargetDatabase
    Write-Output "[] SET Target DB Info: $targetDB"

    $targetDBHost = $sourceDBInfo.TargetHost
    write-output `t"Target DB Host: $targetDBHost"

    $targetDBInst = $targetDBHost +"\"+ $targetDBHost.subString($targetDBHost.LastIndexOf("D"),$targetDBHost.Length-$targetDBHost.LastIndexOf("D")).replace("D","I")
    write-output `t"Target DB Host: $targetDBInst"

    $rootTargetPath = $sourceDBInfo.TargetPaths
    $rootTargetPath = $rootTargetPath.Substring(0,$sourceDBInfo.SourcePaths.indexOf("\Data01") ) -replace($targetDB,"") 
    $ggsciTargetPath = $rootTargetPath+"GoldenGate\Data01\GGS\ggsci"
    write-output `t"GGSCI Path: $ggsciTargetPath "

    $replicatName = $sourceDBInfo.ReplicatProcess
    Write-Output `t"Replicat Name: $replicatName [ 1 - $numReplicat ]"   
    
    $targetODBC = $sourceDBInfo.TargetODBCConfig

    $createReplicat = $sourceDBInfo.CreateReplicat

    $initializeReplicat = $sourceDBInfo.InitializeReplicat

    $restoreTargetDB = $sourceDBInfo.RestoreTarget 

}
CATCH
{
    #echo $_.Exception.GetType().FullName, $_.Exception.Message
    $currentError = $_.Exception.Message -REPLACE "'",""
    write-output "[WARNING] $currentError"        
}
Write-output " "
Write-output "Environment Pre-Checks:"
Write-Output `t"[SOURCE] Remove Pre-Existing trail files that contain: $trailFileLetter"
#    trailFile-check "SOURCE"  $trailFileLetter $ggsciSourcePath "False" 
    $trailPath = $ggsciSourcePath.Replace("\GGS\ggsci","") +"\L"+ $trailFileLetter +"*"
    write-output "`t`t Check for $trailPath "
     IF(Test-Path $trailPath -PathType Leaf)
    {
        write-output "`t[FAIL] File(s) exists - FREAK OUT!"
        #EXIT
        
    }
    ELSE
    {
        write-output "`t[OK] Directory Clean "
    }

Write-Output `t"[TARGET] Remove Pre-Existing trail files that contain: $trailFileLetter"
#    trailFile-check "TARGET"  $trailFileLetter $ggsciTargetPath "False"
    $trailPath = $ggsciTargetPath.Replace("\GGS\ggsci","") +"\L"+ $trailFileLetter +"*"
    write-output "`t`t Check for $trailPath "
    $remoteCMD = "Invoke-Command -Computer $targetDBHost -ScriptBlock { Test-Path $trailPath -PathType Leaf }"
    #write-output "`t`t $remoteCMD "
    #invoke-expression $remoteCMD
     IF( invoke-expression $remoteCMD )
    {
        write-output "`t[FAIL] File(s) exists - FREAK OUT!"
        #EXIT
    }
    ELSE
    {
        write-output "`t[OK] Directory Clean "
    }

write-output `t"[SOURCE] Remove Pre-Existing INIT files "
$sourceInit = $ggsciSourcePath.Replace("ggsci","autoconfig") + "\"+ $newSourceDB +".init"
write-output "`t`t Check for $sourceInit "
    IF(Test-Path $sourceInit -PathType Leaf)
    {
        write-output `t"[WARNING] Removing previous INIT file"
        remove-item $sourceInit
    }
    ELSE
    {
        write-output "`t[OK] Directory Clean "
    }

write-output `t"[TARGET] Remove Pre-Existing INIT files "
    $targetInit = $ggsciTargetPath.Replace("ggsci","autoconfig") + "\"+ $targetDB +".init "
    write-output "`t`t Check for $targetInit "
    $remoteCMD = "Invoke-Command -Computer $targetDBHost -ScriptBlock { Test-Path $targetInit -PathType Leaf }"
    IF(Test-Path $targetInit -PathType Leaf )
    {
        write-output `t"[WARNING] Removing previous INIT file"
        #remove-item $targetInit
        #$remoteCMD
    }
    ELSE
    {
        write-output "`t[OK] Directory Clean "

    }

$sourceBAK = "D:\"+ $templateLink +".bak"
write-output `t"[SOURCE] Remove backups: $sourceBAK" 
#    write-output "`t`t Check for $sourceBAK "
    IF(Test-Path $sourceBAK -PathType Leaf)
    {
        If($myDeBug -eq 1)
        {
            write-output "`t[DEBUG] file exists: $remoteCMD "
        }
        ELSE
        {
            write-output `t"[WARNING] Removing previous BAK file"
            remove-item $sourceBAK
        }
    }
    ELSE
    {
        write-output "`t[OK] Directory Clean "
    }

write-output `t"[TARGET] Remove backups from template." 
    write-output `t`t"DISABLED "

write-output `t"[TEMPLATE] Remove backups from template." 
        $temPlateHost = $targetTemplate.subString(0,$targetTemplate.indexOf("\"))
        $removeCMD = "remove-item -Path \\"+ $temPlateHost  +"\S$\"+ $templateLink +".bak"
        #write-output $removeCMD
        $remoteCMD = "Invoke-Command -Computer $targetDBHost -ScriptBlock { $removeCMD }"
        If($myDeBug -eq 1)
        {
            write-output "`t[DEBUG] $remoteCMD "
        }
        ELSE
        {
            #write-output `t$moveCMD
            invoke-expression $remoteCMD
        }

write-output " "
$confirmation = Read-Host "Are you Sure You Want To Proceed: y to continue or anything else to exit"
if ($confirmation -ne 'y') {  return  }
write-output " "
#############################################################################################
#Get-SourceInfo

Write-output "[] Create New backup from Template"
    TRY
    {
        $backupSQL = "backup database "+ $templateLink +" to disk = 'S:\"+ $templateLink +".bak' with stats = 5, init, compression;"
        If($myDeBug -eq 1)
        {
            write-output "`t[DEBUG] $backupSQL "
        }
        ELSE
        {
            invoke-sqlcmd -ServerInstance $targetTemplate  -Query $backupSQL
        }
            
    }
    CATCH
    {
        #echo $_.Exception.GetType().FullName, $_.Exception.Message
        $currentError = $_.Exception.Message -REPLACE "'",""
        write-output "[WARNING] $currentError"     
        EXIT   
    }

　
Write-output "[] Move Backup to Source DB Host: $sourceDBHost"
    TRY
    {
        $temPlateHost = $targetTemplate.subString(0,$targetTemplate.indexOf("\"))
        $moveCMD = "Copy-Item -Path \\"+ $temPlateHost  +"\S$\"+ $templateLink +".bak -Destination D:\"
        If($myDeBug -eq 1)
        {
            write-output "`t[DEBUG] $moveCMD "
        }
        ELSE
        {
            #write-output `t$moveCMD
            invoke-expression $moveCMD
        }
            
    }
    CATCH
    {
        #echo $_.Exception.GetType().FullName, $_.Exception.Message
        $currentError = $_.Exception.Message -REPLACE "'",""
        write-output "[WARNING] $currentError"        
    }

Write-Output "[DISABLED] Shrink files - DISABLED "
    write-output `t`t"- move to prechecks as space check."

Write-output "[] Restore New Source DB from Backup: "
    database-restore  $restoreSourceDB $sourceDBInst #$myDebug

　
write-output "[] Discover new database and set backup schedule"
    database-discover $sourceDBInst #$myDebug

Write-Output "[DISABLED] Update backup schedule and path - DISABLED "
    write-output `t`t"-"

Write-Output "[] Move backup to new Target DB Host: $targetDBHost"

    TRY
    {#LinkS01S63.init.bak
        $moveCMD = "Copy-Item -Path D:\"+ $newSourceDB +".init.bak -Destination \\"+ $targetDBHost +"\"+$rootTargetPath.replace(":","$")+"BAK1\"
        If($myDeBug -eq 1)
        {
            write-output "`t[DEBUG] $moveCMD "
        }
        ELSE
        {
            #write-output `t$moveCMD
            invoke-expression $moveCMD
        }
                    
    }
    CATCH
    {
        #echo $_.Exception.GetType().FullName, $_.Exception.Message
        $currentError = $_.Exception.Message -REPLACE "'",""
        write-output "[WARNING] $currentError" 
        EXIT                 
    }

Write-output "[] Restore New Target DB from Backup: $targetDBInst"
        database-restore  $restoreTargetDB $targetDBInst  #$myDebug

write-output "[] Discover new database and set backup schedule"
        database-discover $targetDBInst #$myDebug

Write-Output "[DISABLED] Update backup schedule and path - DISABLED "
    write-output `t`t"-"

#############################################################################################
Write-Output " "
Write-Output "[SOURCE] Configure Golden Gate"

Write-Output `t" Edit SetupGG.bat "
    $odbcPath = $ggsciSourcePath.Replace("ggsci","autoconfig") +"\setupgg.bat"
    write-output "`t`t Add ODBC to file $odbcPath "
    # ADD $sourceODBC to end of file
    # $sourceODBC -split "`r`n" | forEach-Object { write-output $_ }
    If($myDeBug -eq 1)
    {
        write-output "`t[DEBUG] not doing .... "
    }
    ELSE
    {
        $sourceODBC -split "`r`n" | forEach-Object { Add-Content $odbcPath `n$_ }
    }

Write-Output `t" Run SetupGG.bat "
    $executeCMD = "CMD /c "+ $ggsciSourcePath.Replace("ggsci","autoconfig") +"\setupgg.bat"
    If($myDeBug -eq 1)
    {
        write-output "`t[DEBUG] $executeCMD "
    }
    ELSE
    {
        #write-output "`t`t $executeCMD "
        invoke-expression $executeCMD >$null  # >$null to remove creation response from operating system
    }

Write-Output `t" Create Extract: $extractName "
    $filePath = $ggsciSourcePath.Replace("ggsci","dirprm") +"\"+ $extractName +".prm"
    IF(Test-Path $filePath -PathType Leaf)
    {
        write-output "`t[FAIL] File exists - FREAK OUT!"
        write-output " "
        $confirmation = Read-Host "Are you Sure You Want To Proceed: y to continue or anything else to exit"
        if ($confirmation -ne 'y') {  EXIT  }
        write-output " "
        #EXIT
    }
    ELSE
    {
        write-output "`t`t Create $filePath "
        $createCMD = "New-Item -path "+ $ggsciSourcePath.Replace("ggsci","dirprm") +"\ -Name "+$extractName +".prm -Value '$createExtract' -ItemType file -force"
        If($myDeBug -eq 1)
        {
            write-output "`t[DEBUG] $createCMD "
        }
        ELSE
        {        
            #write-output $createCMD
            invoke-expression $createCMD >$null  # >$null to remove creation response from operating system
        }
    }

Write-Output `t" Create Pump: $pumpName "
    $filePath = $ggsciSourcePath.Replace("ggsci","dirprm") +"\"+ $pumpName +".prm"
    IF(Test-Path $filePath -PathType Leaf)
    {
        write-output "`t[FAIL] File exists - FREAK OUT!"
        write-output " "
        $confirmation = Read-Host "Are you Sure You Want To Proceed: y to continue or anything else to exit"
        if ($confirmation -ne 'y') {  EXIT  }
        write-output " "
        #EXIT
    }
    ELSE
    {
        write-output "`t`t Create $filePath "
        $createCMD = "New-Item -path "+ $ggsciSourcePath.Replace("ggsci","dirprm") +"\ -Name "+$pumpName +".prm -Value '$createPump' -ItemType file -force"
        If($myDeBug -eq 1)
        {
            write-output "`t[DEBUG] $createCMD "
        }
        ELSE
        {      
            #write-output $createCMD
            invoke-expression $createCMD >$null  # >$null to remove creation response from operating system
        }
    }

#$sourceInit = $ggsciSourcePath.Replace("ggsci","autoconfig") + "\"+ $newSourceDB +".init "
Write-output `t" Create Extract/Pump Initialization file $sourceInit "
    If($myDeBug -eq 1)
    {
        write-output "`t[DEBUG] $initializeExtractPump "
    }
    ELSE
    {
        $initializeExtractPump -split "`r`n" | forEach-Object { Add-Content $sourceInit `n$_ } 
    }

Write-Output `t" Initialize Extract and Pump "
    object-init "PUMP" $ggsciSourcePath $newSourceDB

　
Write-Output "[SOURCE] Golden Gate - create TRAIL file"

Write-Output `t" Confirm Extract and Pump exist and are STOPPED."
$expectedStatus="STOPPED"
write-output `t"  Confirm $extractName status = $expectedStatus "
    Get-Status "EXTRACT" $extractName $ggsciSourcePath $expectedStatus  
$expectedStatus="STOPPED"
write-output `t"  Confirm $pumpName status = $expectedStatus "
    Get-Status "EXTRACT" $pumpName $ggsciSourcePath $expectedStatus  

Write-Output `t" Start and Stop Extract to create trail file."      
$setStatus="START"
Write-Output `t"  $setStatus Extract: $extractName "
    change-status "EXTRACT" $extractName $ggsciSourcePath $setStatus 

$expectedStatus="RUNNING"
write-output `t"  Confirm $extractName status = $expectedStatus "
    Get-status "EXTRACT" $extractName $ggsciSourcePath $expectedStatus 

$setStatus="STOP"   
Write-Output `t"  $setStatus Extract: $extractName "
    change-status "EXTRACT" $extractName $ggsciSourcePath $setStatus 

$expectedStatus="STOPPED"
write-output `t"  Confirm $extractName status = $expectedStatus "
    Get-Status "EXTRACT" $extractName $ggsciSourcePath $expectedStatus  

write-output "`t`t Check for $trailPath "
#    trailFile-check "SOURCE"  $trailFileLetter $ggsciSourcePath "True"

#EXIT #Stoppingherefornow

#############################################################################################
Write-Output " "
Write-Output "[TARGET] Configure Golden Gate"

Write-Output `t"Edit SetupGG.bat "
    $odbcPath = $ggsciTargetPath.Replace("ggsci","autoconfig") +"\setupgg.bat"
    write-output "`t`t Add ODBC to file $odbcPath "
    # ADD $sourceODBC to end of file
    # $sourceODBC -split "`r`n" | forEach-Object { write-output $_ }
    $remoteCMD = "Invoke-Command -Computer $targetDBHost -ScriptBlock { Add-Content $odbcPath `"`n"+ $targetODBC.replace('"','`"') +"`" }"
    If($myDeBug -eq 1)
    {
        write-output "`t[DEBUG] $remoteCMD "
    }
    ELSE
    {
        # write-output "`t`t $remoteCMD "
        invoke-expression $remoteCMD >$null  # >$null to remove creation response from operating system
    }

Write-Output `t"Run SetupGG.bat "
    $executeCMD = "CMD /c "+ $ggsciTargetPath.Replace("ggsci","autoconfig") +"\setupgg.bat"
    write-output "`t`t $executeCMD "
    $remoteCMD = "Invoke-Command -ComputerName $targetDBHost -ScriptBlock { $executeCMD }"
    If($myDeBug -eq 1)
    {
        write-output "`t[DEBUG] $remoteCMD "
    }
    ELSE
    {
        #write-output "`t`t $remoteCMD "
        invoke-expression $remoteCMD  >$null  # >$null to remove creation response from operating system
    }

Write-Output `t"Create Replicats [ 1 - $numReplicat ] "
$a_createReplicat = $createReplicat -split “`r`n`r`n--------------------------------------------------------------------------`r`n`r`n`r`n"
[int]$tempCounter = 0
WHILE( $tempCounter -lt $numReplicat )
{
    [string]$currentReplicat = $replicatName + ([int]$tempCounter+1)
    $filePath = $ggsciTargetPath.Replace("ggsci","dirprm") +"\"+ $currentReplicat +".prm"
    # write-output "`t`t Create file $filePath "
    $remoteCMD = "Invoke-Command -Computer $targetDBHost -ScriptBlock { Test-Path $filePath -PathType Leaf }"
    # write-output "`t`t $remoteCMD "
    # invoke-expression $remoteCMD

    # write-output $a_createReplicat[$tempCounter]
    write-output "`t`t Create $filePath "
    IF( invoke-expression $remoteCMD )
    {
        write-output "`t[FAIL] File exists - FREAK OUT!"
        write-output " "
        $confirmation = Read-Host "Are you Sure You Want To Proceed: y to continue or anything else to exit"
        if ($confirmation -ne 'y') {  EXIT  }
        write-output " "
        #EXIT
    }
    ELSE
    {
        $createCMD = "New-Item -path "+ $ggsciTargetPath.Replace("ggsci","dirprm") +"\ -Name "+$currentReplicat +".prm -Value '"+ $a_createReplicat[$tempCounter] +"' -ItemType file -force"
        #write-output $createCMD
        $remoteCMD = "Invoke-Command -Computer $targetDBHost -ScriptBlock { $createCMD }"
        If($myDeBug -eq 1)
        {
            write-output "`t[DEBUG] $remoteCMD "
        }
        ELSE
        {  
            #write-output "`t`t $remoteCMD "
            invoke-expression $remoteCMD >$null  # >$null to remove creation response from operating system
        }
    }

　
    $tempCounter++

}

Write-output `t"Create Replicat Initialization file $targetInit "
    $currentCMD = "CMD /c echo `"$initializeReplicat`" | out-file $targetInit"
    #write-output $currentCMD
    $remoteCMD = "Invoke-Command -Computer $targetDBHost -ScriptBlock { $currentCMD }"
    If($myDeBug -eq 1)
    {
        write-output "`t[DEBUG] $remoteCMD "
    }
    ELSE
    {
        #write-output "`t`t $remoteCMD "
        invoke-expression $remoteCMD > $null # >$null to remove creation response from operating system
    }

Write-Output `t"Initialize Replicats [ 1 - $numReplicat ] "
    object-init "REPLICAT" $ggsciTargetPath $targetDB

$expectedStatus="STOPPED"    
write-output `t" Confirm $pumpName [1 - $numReplicat] Status = $expectedStatus"
#    Get-status "REPLICAT" $currentReplicat $ggsciTargetPath $expectedStatus 

    [int]$tempCounter = 0
    WHILE( $tempCounter -lt $numReplicat )
    {
        [string]$currentReplicat = $replicatName + ([int]$tempCounter+1)
        #write-output `t"Confirm $currentReplicat Status = $expectedStatus"
        Get-status "REPLICAT" $currentReplicat $ggsciTargetPath $expectedStatus 

        $tempcounter++
    }

#EXIT #Stoppingherefornow

#############################################################################################
Write-Output "[SOURCE] Golden Gate - pump TRAIL file"
$expectedStatus="STOPPED"    
write-output `t" Confirm $pumpName Status = $expectedStatus"
    Get-Status "EXTRACT" $pumpName $ggsciSourcePath $expectedStatus

$setStatus="START"
Write-Output `t" $setStatus Pump: $pumpName "
    change-status "PUMP" $pumpName $ggsciSourcePath $setStatus 

$expectedStatus="RUNNING"    
write-output `t" Confirm $pumpName Status = $expectedStatus"
    Get-Status "EXTRACT" $pumpName $ggsciSourcePath $expectedStatus   

$setStatus="STOP"
Write-Output `t" $setStatus Pump: $pumpName "
    change-status "PUMP" $pumpName $ggsciSourcePath $setStatus 

$expectedStatus="STOPPED"    
write-output `t" Confirm $pumpName Status = $expectedStatus"
    Get-Status "EXTRACT" $pumpName $ggsciSourcePath $expectedStatus

#EXIT #Stoppingherefornow

#############################################################################################
Write-Output "[TARGET] Golden Gate - consume TRAIL file "

Write-Output "`t Confirm trail file was created. "
#    trailFile-check "TARGET"  $trailFileLetter $ggsciTargetPath "True"
    $trailPath = $ggsciTargetPath.Replace("\GGS\ggsci","") +"\L"+ $trailFileLetter +"*"
    write-output "`t`t Check for $trailPath "
    $remoteCMD = "Invoke-Command -Computer $targetDBHost -ScriptBlock { Test-Path $trailPath -PathType Leaf }"
    #write-output "`t`t $remoteCMD "
    #invoke-expression $remoteCMD
    IF( invoke-expression $remoteCMD )
    {
        write-output "`t[OK] File(s) exists"
       
    }
    ELSE
    {
        write-output "`t[FAIL] Directory EMPTY - FREAK OUT!!! "
        EXIT
    }

$setStatus="START"
Write-Output "`t $setStatus Replicat[1- $numReplicat]: "
    change-status "REPLICAT" $replicatName $ggsciTargetPath $setStatus 

$expectedStatus="RUNNING"    
write-output `t" Confirm $pumpName [1 - $numReplicat] Status = $expectedStatus"
#    Get-status "REPLICAT" $currentReplicat $ggsciTargetPath $expectedStatus 

    [int]$tempCounter = 0
    WHILE( $tempCounter -lt $numReplicat )
    {
        [string]$currentReplicat = $replicatName + ([int]$tempCounter+1)
        #write-output `t"Confirm $currentReplicat Status = $expectedStatus"
        Get-status "REPLICAT" $currentReplicat $ggsciTargetPath $expectedStatus #

        $tempcounter++
    }

$setStatus="STOP"
Write-Output "`t $setStatus Replicat[1- $numReplicat]: "
    change-status "REPLICAT" $replicatName $ggsciTargetPath $setStatus 

$expectedStatus="STOPPED"    
write-output `t" Confirm $pumpName [1 - $numReplicat] Status = $expectedStatus"
#    Get-status "REPLICAT" $currentReplicat $ggsciTargetPath $expectedStatus 

    [int]$tempCounter = 0
    WHILE( $tempCounter -lt $numReplicat )
    {
        [string]$currentReplicat = $replicatName + ([int]$tempCounter+1)
        #write-output `t"Confirm $currentReplicat Status = $expectedStatus"
        Get-status "REPLICAT" $currentReplicat $ggsciTargetPath $expectedStatus 

        $tempcounter++
    }

Write-output "[] At this point all services are confirmed to Start and Stop  "

#EXIT #Stoppingherefornow

#############################################################################################
Write-Output " "
Write-Output "[FINAL] Start all Golden Gate processes "
#############################################################################################
Write-Output "[SOURCE] Start Extract: $extractName "

$setStatus="START"
Write-Output `t"  $setStatus Extract: $extractName "
    change-status "EXTRACT" $extractName $ggsciSourcePath $setStatus 

$expectedStatus="RUNNING"
write-output `t"  Confirm $extractName status = $expectedStatus "
    Get-status "EXTRACT" $extractName $ggsciSourcePath $expectedStatus 

Write-Output "[SOURCE] Start Pump: $pumpName "

$setStatus="START"
Write-Output `t" $setStatus Pump: $pumpName "
    change-status "PUMP" $pumpName $ggsciSourcePath $setStatus 

$expectedStatus="RUNNING"    
write-output `t" Confirm $pumpName Status = $expectedStatus"
    Get-Status "EXTRACT" $pumpName $ggsciSourcePath $expectedStatus   

#EXIT #Stoppingherefornow

#############################################################################################
Write-Output "[TARGET] START ALL Replicats "

$setStatus="START"
Write-Output `t" $setStatus Replicat[1-4]: "
    change-status "REPLICAT" $replicatName $ggsciTargetPath $setStatus

$expectedStatus="RUNNING"    
write-output `t" Confirm $replicatName [1 - $numReplicat] Status = $expectedStatus"
#    Get-status "REPLICAT" $currentReplicat $ggsciTargetPath $expectedStatus 

    [int]$tempCounter = 0
    WHILE( $tempCounter -lt $numReplicat )
    {
        [string]$currentReplicat = $replicatName + ([int]$tempCounter+1)
        #write-output `t"Confirm $currentReplicat Status = $expectedStatus"
        Get-status "REPLICAT" $currentReplicat $ggsciTargetPath $expectedStatus 

        $tempcounter++
    }

#EXIT #Stoppingherefornow

#############################################################################################
write-output "[TEST] Confirm replication is working."
write-output `t" Confirm entries in source table. "
write-output `t" Confirm entries in target table. "
write-output `t" INSERT test value in source table. "
write-output `t" Confirm entries in source table. "
write-output `t" Confirm entries in target table. "
write-output `t" DELETE test value in source table. "
write-output `t" Confirm entries in source table. "
write-output `t" Confirm entries in target table. "

#EXIT #Stoppingherefornow

#############################################################################################
$tempDisplay =  "Write-Output '`t Set Notification on CDC job: cdc."+ $newSourceDB +"_cleanup to DBInformation'" 
invoke-expression $tempDisplay
TRY
{
    $updateSQL = "EXEC msdb.dbo.sp_update_job @job_name=N'cdc."+ $newSourceDB +"_cleanup', @notify_level_email=2, @notify_level_netsend=2, @notify_level_page=2, @notify_email_operator_name=N'DBInformation'"
    If($myDeBug -eq 1)
    {
        write-output "`t[DEBUG] $updateSQL "
    }
    ELSE
    {
        #write-output `t`t" $updateSQL "
        invoke-sqlcmd -ServerInstance $sourceDBInst  -Query $updateSQL
    }
            
}
CATCH
{
    #echo $_.Exception.GetType().FullName, $_.Exception.Message
    $currentError = $_.Exception.Message -REPLACE "'",""
    write-output "[WARNING] $currentError"        
}

　
#EXIT #Stoppingherefornow

#############################################################################################
write-output "Environment tested clean"
write-output "[On Deck] ADD to Source and Target Systems with status of zero. "

#############################################################################################
Write-Output "[TEMPLATE] Cleanup "
write-output `t"Delete all backup files and .init files"
$sourceInit = $ggsciSourcePath.Replace("ggsci","autoconfig") + "\"+ $newSourceDB +".init"
write-output "`t`t Check for $sourceInit "
    IF(Test-Path $sourceInit -PathType Leaf)
    {
        write-output `t"[WARNING] Removing previous file"
####        remove-item $sourceInit
        
    }
    ELSE
    {
        write-output "`t[OK] Directory Clean "
    }

Write-Output "[SOURCE] Cleanup "
write-output `t"Delete all backup files and .init files"
$sourceInit = $ggsciSourcePath.Replace("ggsci","autoconfig") + "\"+ $newSourceDB +".init"
write-output "`t`t Check for $sourceInit "
    IF(Test-Path $sourceInit -PathType Leaf)
    {
        write-output `t"[WARNING] Removing previous file"
####        remove-item $sourceInit
        
    }
    ELSE
    {
        write-output "`t[OK] Directory Clean "
    }

Write-Output "[TARGET] Cleanup "
write-output `t"Delete all backup files and .init files"
$sourceInit = $ggsciSourcePath.Replace("ggsci","autoconfig") + "\"+ $newSourceDB +".init"
write-output "`t`t Check for $sourceInit "
    IF(Test-Path $sourceInit -PathType Leaf)
    {
        write-output `t"[WARNING] Removing previous file"
####        remove-item $sourceInit
        
    }
    ELSE
    {
        write-output "`t[OK] Directory Clean "
    }

　
　
　
　
 
