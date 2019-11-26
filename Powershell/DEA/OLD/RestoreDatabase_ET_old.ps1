import-module sqlps -DisableNameChecking

Function RestoreDatabase {

Param(
   [Parameter(Mandatory=$true)] [string]   $RequestNum,
   [Parameter(Mandatory=$true)]  [string]  $ServerInstance,
   [Parameter(Mandatory=$true)] [string]   $Database,    
   [string]  $RestoreType = "Database", 
   [Parameter(Mandatory=$true)]  [String]  $BackupFile,  ## if OperationType "Restore", Speficy the backup LUN root path (G:\SQL\I03\). 
                                                          ## if OperationType "Attach", Specify LUN path where mdf & ldf files are located for the DB that you wanted to attach (G:\SQL\I03\DB6001\)
   [int]     $OverWriteDatabase = 0,
   [string]   $RestoreLunPath = $null, ## if $null, it is broken 
   [string]   $BackupInfo = $null, ## Pass the Backup Set GUID
   [parameter(mandatory=$true)] [string] $OperationType  # Accepted Values are "Restore" Or "Attach"
                                                                                                                          
   )


# import the SQLPS Extract module
# Import-Module sqlps -DisableNameChecking

<#

If (! (Get-module sqlps )) {
Import-Module sqlps >> 1

#>


function finaloutput_OK
{


   
    # call function to Archive the Backup files
    #Archive_Backupfiles

    # call Upgrade tasks functions
    #Perform_Upgrade

    $DateTime = get-date -format G 
    # Write-Output $DateTime":- Printing work  Status."
    $DateTime+":- Printing Restore Task Status "  | Out-File $ExecutionLogFileName  -Append

    

    #Write-Output $DBRestoreStatus | Format-table -Wrap
    $DBRestoreStatus | Format-table -Wrap | Out-File $ExecutionLogFileName  -Append
    #Write-Output $DateTime":- Automation work  is Completed. Please check the detailed log for its Status."

     
    $DateTime+":- Restore Task  is Completed. Please check the detailed log for its Status." | Out-File $ExecutionLogFileName  -Append
    
}


function finaloutput_NotOK
{    
    param([string] $printmsg)

   

    $DateTime = get-date -format G 
   # Write-output $DateTime":- Printing work  Status."
     $DateTime+":- Printing Restore Task Status " | Out-File $ExecutionLogFileName  -Append
   # Write-output $DateTime":- $printmsg"
    $DateTime+":- $printmsg" | Out-File $ExecutionLogFileName  -Append

    # Call Archive the Backup files function 
    #Archive_Backupfiles

    
    #Write-Output $DBRestoreStatus | Format-table -Wrap
    $DBRestoreStatus | Format-table -Wrap | Out-File $ExecutionLogFileName  -Append
    $msg =  "Restore Task  is Failed. Please check the detailed log for its Status."

 
    $msg | Out-File $ExecutionLogFileName  -Append
    throw $msg
}


function Writeout
{
    param ([string] $printmsg)

    $DateTime = get-date -format G 
    Write-Output $DateTime":- $printmsg" 
    $DateTime+":- $printmsg" | Out-File $ExecutionLogFileName  -Append

}

function  UpdateRestoreStatus # function will return collection array. make sure to store it main code block. i.e $DBRestoreStatus = UpdateRestoreStatus -dbkey
{
    param ([string] $dbkey, [datetime] $Restore_StartDateTime, [datetime] $Restore_EndDateTime, [string] $Last_known_Status, [PSobject[]] $psobjname, [string] $Upgrade_Task_Status, [string] $Last_Exception_Message )

    $DBRestoreStatus_tmp = $null

    $lst = $psobjname | select DBName

    $st = Get-Date -Format G

    if ($lst.DBName -contains $dbkey)
    {
        try {
        $psobjname | % { 
                               if ($_.dbname -eq $dbkey) 
                                { $_.Restore_Task_Status = if ($Last_known_Status -eq "" -or $Last_known_Status -eq $null) {$_.Restore_Task_Status} else {$Last_known_Status} ; 
                                $_.Restore_StartDateTime = if($Restore_StartDateTime) {$Restore_StartDateTime} else {$_.Restore_StartDateTime}; 
                                $_.Restore_EndDateTime = if($Restore_EndDateTime) {$Restore_EndDateTime} else {$_.Restore_EndDateTime} ; 
                                $_.Last_known_status_dt = $st;
                                 $_.Last_Exception_Message =if ($Last_Exception_Message -eq "" -or $Last_Exception_Message -eq $null) {$_.Last_Exception_Message} else {$Last_Exception_Message} ; 
                                $_.Upgrade_Task_Status  = if ($Upgrade_Task_Status -eq "" -or $Upgrade_Task_Status -eq $null) {$_.Upgrade_Task_Status} else {$Upgrade_Task_Status} ;
                               
                                
                                 } 
                             }
        }
        catch
        {
        throw $_.Exception.Message
        }
    }
    else
    {
        try{
       
         $DBRestoreStatus_tmp = New-Object PSObject -Property ([ordered] @{
                        DBName=$dbkey;
                        Restore_StartDateTime=$Restore_StartDateTime;
                        Restore_EndDateTime=$null;
                        Last_known_status_dt = $st;
                        Restore_Task_Status="NotStarted";
                        Last_Exception_Message = ""
                        Upgrade_Task_Status  = "NotStarted";
                        
                        }) -Debug -Verbose

        
         #$DBRestoreStatus = @($psobjname,$DBRestoreStatus_tmp)
         $psobjname += $DBRestoreStatus_tmp
         }
         catch
         {
          throw $_.Exception.Message
         }

          
    }

   return $psobjname

}
function Test-FileLock {
  param (
    [parameter(Mandatory=$true)][string]$Path
  )


  $oFile = New-Object System.IO.FileInfo $Path


  try {
    $oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        if ($oStream) {
      $oStream.Close()
    }
    $false
  } catch {
    # file is locked by a process.
    return $true
  }
}

function Attach-Database(
        [string] $Databasenew,
        [string] $AttachlunPath,
        [string] $AttachlunPath_rem
                )
{

$AttachlunPath_rem = "filesystem::$AttachlunPath_rem"

    try{
     Writeout -printmsg "Getting Target Instance [$ServerInstance] Data (mdf,ndf) & Log (ldf) files dynamically from [$AttachlunPath] "
    $AttachlunPath_rem
    $AttachFilesList = Get-ChildItem $AttachlunPath_rem -Recurse  | where { $_.Name -like "*.mdf" -or $_.Name -like "*.ndf" -or $_.Name -like "*.ldf" } | %{$_.fullName} -ErrorAction Stop 
    $AttachFilesList
    # get only files which are not in use
    $AttachFilesList = $AttachFilesList | where { (-not(Test-FileLock -path $_)) } 

    

    }
    catch{
      Writeout -printmsg   "[$AttachlunPath] is not valid or does not have Data (mdf,ndf) & Log (ldf) files to Attach "
         finaloutput_NotOK -printmsg "[$AttachlunPath] is not valid or does not have Data & Log Luns "
            break
    }

    IF ($AttachFilesList -eq $NULL)
    {
        Writeout -printmsg   "[$AttachlunPath] is not valid or does not have Data (mdf,ndf) & Log (ldf) files to Attach "
         finaloutput_NotOK -printmsg "[$AttachlunPath] is not valid or does not have Data & Log Luns "
            break
    }



    Writeout -printmsg "Creating Attach commands for the database [$DatabaseNew] with the available Data & log files"

    $AttachCmd = "CREATE DATABASE [$Databasenew] `n ON "

    foreach ($file in $AttachFilesList)
    {
  
   

    $LunName = (split-path(split-path($file)) -Leaf)+"\"
    $AttachfileName = split-path($file) -Leaf
    $AttachFilename = "$AttachlunPath$LunName$AttachfileName"

    

    $AttachCmd += "(FILENAME = N'$AttachFilename'), `n" 
    }


    $Final_AttachCmd = (($AttachCmd.Trim()).TrimEnd(","))+ "`n FOR ATTACH;"

     Writeout -printmsg "Final Attach Command is   $Final_AttachCmd"


     try {

     Writeout -printmsg "Attach Operation is starting for the database [$databasenew]. This Operation could take some time based on the Data & Ldf files. Pleas check the logs periodically"
     Writeout -printmsg ""
          

     # Execute Restore
     Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -Query $Final_AttachCmd -Verbose -OutputSqlErrors $true -OutBuffer $true -AbortOnError -ErrorAction stop -ConnectionTimeout 0 -QueryTimeout 0 
     }
     catch
     {
 
                  Writeout -printmsg "Attach Database Operation is Failed due to an Exception " 
                  Writeout -printmsg $_.Exception.Message
                  throw
     }        

}




# function to validate the database Phsyical file names and its existence. if does exist, it will create a unique Phsyical file names
function ValidateFileAndGetNewFileName
{
# do not use write-output or host and print any value inside this function whcih will be passed backed to the caller

     Param(
      [string] $ServerName,
      [string] $FilePhysicalName,
      [string] $Filelogicalname,
      [String] $FileDatabaseName,
      [String] $FileOverWriteDatabase,
      [bool]   $isDatabaseExist
     )

     try {

     #Get only the SQL Server Name. Instance name is not needed
     $Server_tmp =  $ServerName.split("\")[0] 

     #replace ":" with $ so that we can validate the file location using $ share
     $FilePhysicalName_new = $FilePhysicalName.replace(":","$")
     $File = "\\$Server_tmp\$FilePhysicalName_new"

  
     $NewPhysicalName = $null
     $NewPhysicalName_fullpath = $null

     
    
     if ($FileOverWriteDatabase -eq 1 -and ($isDatabaseExist -eq $true -or $isDatabaseExist_on_NotOnlineState -eq $true)) #if database is exist, get the physical data,log file locations based on the file name
    {
      $fileInfooutput = $null
      $fileInfooutput =  Invoke-Sqlcmd -ServerInstance $ServerName -database master -Query "select Physical_name from sys.master_files where db_name(database_id) = '$FileDatabaseName' and name = '$Filelogicalname'" -AbortOnError -ErrorAction stop -OutputSqlErrors $true -ConnectionTimeout 0 -QueryTimeout 0
      
         if ($fileInfooutput -ne $null){
      
      #the idea is that if the database exists already, reuse the phsyical names
      # get only mdf,ldf or ndf file names and assign it to  $NewPhysicalName. not the entire path
      $NewPhysicalName = $fileInfooutput[0].split("\")[-1]
  #    $NewPhysicalName_fullpath = $fileInfooutput[0]  | Out-String
  #    $NewPhysicalName_fullpath = $NewPhysicalName_fullpath.Trim()

      $NewPhysicalName_fullpath = Split-Path $FilePhysicalName  | Out-String
      $NewPhysicalName_fullpath = $NewPhysicalName_fullpath.trim()

      $NewPhysicalName_fullpath += "\"+$NewPhysicalName
      $NewPhysicalName_fullpath = $NewPhysicalName_fullpath.Trim()
      $NewPhysicalName_fullpath = $NewPhysicalName_fullpath.Replace("\\","\")
      $NewPhysicalName_fullpath = $NewPhysicalName_fullpath.Trim()

      }
      #troubleshooting purpose
   #   Invoke-Sqlcmd -ServerInstance $ServerName -database master -Query "print 'Step 1 $NewPhysicalName'"

      #one more validation to check if the file name is being used by any other database
      if ($NewPhysicalName -ne "" -and $NewPhysicalName -ne $null )
      {
      $fileInfooutput1 = $null
      $fileInfooutput1 =  Invoke-Sqlcmd -ServerInstance $ServerName -database master -Query "select distinct db_name(database_id) as DBName from sys.master_files where db_name(database_id) <> '$FileDatabaseName' and Physical_name like '$NewPhysicalName_fullpath'" -AbortOnError -ErrorAction stop -OutputSqlErrors $true -ConnectionTimeout 0 -QueryTimeout 0
      # check if the same physical file exists for some other database if so, reset $NewPhysicalName to null so that unique file will be generated
      
      $fileInfooutput1 = $fileInfooutput1.DBName  | Out-String

       #troubleshooting purpose
       Invoke-Sqlcmd -ServerInstance $ServerName -database master -Query "print 'Step 2 $NewPhysicalName'" -AbortOnError -ErrorAction stop -OutputSqlErrors $true -ConnectionTimeout 0 -QueryTimeout 0
      
        if ($fileInfooutput1 -ne $null -and $fileInfooutput1 -ne ""  -and $isDatabaseExist_on_NotOnlineState -eq $false) 
        {
          $NewPhysicalName = $null
        }

        #troubleshooting purpose
   #      Invoke-Sqlcmd -ServerInstance $ServerName -database master -Query "print 'Step 3 $NewPhysicalName'"
 
      } # if ($NewPhysicalName -ne "" -and $NewPhysicalName -ne $null)
    }
    elseif ($isDatabaseExist -eq $false -and $isDatabaseExist_on_NotOnlineState -eq $false)
    {
     $NewPhysicalName = $FilePhysicalName.Split("\")[-1]
     $NewPhysicalName = $NewPhysicalName.trim()
      $NewPhysicalName_fullpath = $FilePhysicalName  | Out-String
      $NewPhysicalName_fullpath = $NewPhysicalName_fullpath.Trim()

     $fileInfooutput1 = $null
      $fileInfooutput1 =  Invoke-Sqlcmd -ServerInstance $ServerName -database master -Query "select distinct db_name(database_id) as DBName from sys.master_files where db_name(database_id) <> '$FileDatabaseName' and Physical_name like '$NewPhysicalName_fullpath'" -AbortOnError -ErrorAction stop -OutputSqlErrors $true -ConnectionTimeout 0 -QueryTimeout 0
      # check if the same physical file exists for some other database if so, reset $NewPhysicalName to null so that unique file will be generated
      
      $fileInfooutput1 = $fileInfooutput1.DBName  | Out-String
      
        if ($fileInfooutput1 -ne $null -and $fileInfooutput1 -ne ""  -and $isDatabaseExist_on_NotOnlineState -eq $false) 
        {
          $NewPhysicalName = $null
        }

        #troubleshooting purpose
  #   Invoke-Sqlcmd -ServerInstance $ServerName -database master -Query "print 'Step 4 $NewPhysicalName'"

    }
    
     #troubleshooting purpose
  #  Invoke-Sqlcmd -ServerInstance $ServerName -database master -Query "print 'Step 5 $NewPhysicalName'"
  
    #if the file exists already, generate the new file 
    if ($NewPhysicalName -eq $null -or $NewPhysicalName -eq "")
    {
     
     $DateTime = Get-Date -Format yyyyMMddHHmmssfffffff

     #check if the file exists already 
     if (([System.IO.FileInfo]"$File").exists)
     {
     # get only mdf,ldf or ndf file names. not the entire path
     $NewPhysicalName = $FilePhysicalName.Split("\")[-1]
     # introudce the unique file name by adding datetime timestamp
     $NewPhysicalName = $NewPhysicalName.replace(".","_$DateTime.")
     #trim it
     $NewPhysicalName = $NewPhysicalName.Trim()

     #troubleshooting purpose
  #     Invoke-Sqlcmd -ServerInstance $ServerName -database master -Query "print 'Step 6 $NewPhysicalName'"

     }

    } 

 }
 catch
 {
 throw $_.Exception.Message
 }
     #return the final physical file name
     return $NewPhysicalName

}


# function to validate and restore the databases. This function is scoped only for one database at a time. 
function ValidateAndRestore_Database
{
   param(
        [string] $Databasenew,
        [string] $BackupPhysicalFileName,
        [string] $BackupTypeDescription,
        [string] $HasBackupChecksums
            )

    $BackupFile_New = $BackupPhysicalFileName
    
    Writeout -printmsg "Database Name Validation is starting for [$Databasenew]"

    
    #Writeout -printmsg "Backup File Location is [$BackupFile_New]"

    #validate the database names are system Databases
    if ($Databasenew -in ("Master","Model","TempDB","MSDB"))
    {
         Writeout -printmsg "Database validation Failed for [$Databasenew]. Database can not be restored by the same name as System Databases"
                throw "Database validation Failed for [$Databasenew]. Database can not be restored by the same name as System Databases"
                return -1
    }

    
    Writeout -printmsg "Database Name Validation is success for [$Databasenew]"

    #check if the database name exists or not
   [bool] $isDatabaseExist = $server.Databases.name -contains $Databasenew

     $isDatabaseExist_on_NotOnlineState = $false

    #if ($isDatabaseExist -eq $False) # some database could be in restoring state. we need set the status properly. previous statement my not give proper values for databases which are restore state
    #{
         $dbstate_tmp = ""

         $dbstate_tmp = Invoke-Sqlcmd -ServerInstance $ServerInstance -database master -Query "select state_desc from sys.databases where name = '$Databasenew' and state_desc <> 'online'" -AbortOnError -ErrorAction stop -OutputSqlErrors $true -ConnectionTimeout 0 -QueryTimeout 0

         if ($dbstate_tmp -ne $null -and $dbstate_tmp -ne "")
         {
         $isDatabaseExist_on_NotOnlineState = $true
         }

    #}  
    #$isDatabaseExist_on_NotOnlineState

    
    #get only server name. Instance name is not needed
    $Server_tmp =  $ServerInstance.split("\")[0] 

    if ($isDatabaseExist_on_NotOnlineState -eq $true)
    {
        $State_tmp = $true
    }
    else
    {
        $State_tmp = $isDatabaseExist
    }
    
    Writeout -printmsg "[$Databasenew] Database Exists Validation is [$State_tmp]. And OverWriteDatabase Option is [$OverWriteDatabase]"

    if ($OverWriteDatabase -ne 1 -and $State_tmp -eq $true)
    {
    Writeout -printmsg "OverWriteDatabase Option is [$OverWriteDatabase]. You can not restore the database"
    throw
    }
            

    ### Resote MOve Portion - Starts here

     
    Writeout -printmsg "Reading Backup FileList form the Backup [$BackupFile_New]" 


    # Get only one file to reterive Backup FileLists
    $get_BackupFile = $BackupFile_New.split(",")[0]

    #"RESTORE FILELISTONLY FROM $get_BackupFile"
    

    try {
    #get the Database logical and Physical file names from Backup
    $RestoreFileList = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "RESTORE FILELISTONLY FROM $get_BackupFile" -Verbose -OutputSqlErrors $true -OutBuffer $true  -AbortOnError -ErrorAction stop -ConnectionTimeout 0 -QueryTimeout 0
    }
    catch {

        
        Writeout -printmsg "Reading Backup FileList Process is Failed " 
        Writeout -printmsg  $_.Exception.Message
        
                Writeout -printmsg  $_.Exception.Message
                throw

    }

    if ($RestoreFileList -eq $null)
    {
        
        Writeout -printmsg "Reading Backup FileList Process is Failed " 
        Writeout -printmsg  $_.Exception.Message

                Writeout -printmsg  $_.Exception.Message
                throw
    }
 

    
    Writeout -printmsg "Reading Backup FileList Process is success" 

    Writeout -printmsg "Reading Data file list form Backup FileList " 

    #Get the Data files List
    $DataFileList_From_Backup = $RestoreFileList | where-object {$_.Type -eq "D"}  | sort-object FileId

    Writeout -printmsg "Reading Log file list form Backup FileList " 
    #Get the Log files List
    $LogFileList_From_Backup = $RestoreFileList | where-object {$_.Type -eq "L"} | sort-object FileId

   # $DataFileList_From_Backup.count
   # $LogFileList_From_Backup.count


    # Delcare Data file list array
    $RestoreDBFile = @()


       Writeout -printmsg "There could be multiple data & Logs files in single DB. Going to store the logical & physical files names in the array which will be fed into the restore statement later" 
       Writeout -printmsg "Reading Data Files List" 
        #loop through Data files list
        $datafileId = 0
        foreach ($datafilelist in $DataFileList_From_Backup)
        { 

           
            # Validate and form the Data file location
           if ($SQL_dl.count -in (1,$null))
           {
            $DatFileNewFolderPath = $SQL_dl.Name+"\" 
           }
           else
           {
            $DatFileNewFolderPath = ($SQL_dl.getvalue($datafileId)).Name+"\" 
           }



            $DatFileNewFolderPath = "$lunpath$DatFileNewFolderPath"

             $datafileId += 1
             # reset LUNPath
             if (($SQL_dl.count -le $datafileId) -or ($SQL_dl.count -eq $null)) {$datafileId = 0}


             $DatFileNewFolderPath_new = $DatFileNewFolderPath + ($datafilelist.PhysicalName).split("\")[-1] #if needed use spilt-path cmdlet

             #$DatFileNewFolderPath_new


            # Writeout -printmsg "Verify if the data file [$DatFileNewFolderPath_new] exists or not. If it exists, create a new data file name dynamically"
           
            # if ($BackupTypeDescription -eq "database")
          #   {
             
                 $ValidFilename = $null
   
                 
                 try {
                 #$DatFileNewFolderPath_new,$datafilelist.logicalname
                 $ValidFilename = ValidateFileAndGetNewFileName -ServerName $ServerInstance -FilePhysicalName $DatFileNewFolderPath_new -Filelogicalname $datafilelist.logicalname -FileDatabaseName $Databasenew -FileOverWriteDatabase $OverWriteDatabase -isDatabaseExist $isDatabaseExist -debug 
                 }
                 catch
                 {
                  Writeout -printmsg "The data file [$DatFileNewFolderPath_new] does not exist or could not be verified. The new file name value is [$ValidFilename]"
                 }
                 
           
                 if ($ValidFilename -ne "" -and $ValidFilename -ne $null) #if the physical file exits then assign the newly generated file
                 {
                    $DatFileNewFolderPath_new = $DatFileNewFolderPath + $ValidFilename
                 }
                 
            # }
             
           
           
          
         #Writeout -printmsg "The data file path is [$DatFileNewFolderPath_new]. Setting this value in Relocate data file array " 
         # assign on Relocate File object

         $RestoreDBFile += "Move '$($datafilelist.logicalname)' to '$($DatFileNewFolderPath_new)'," 
       
        }

        #$RestoreDBFile

         
        Writeout -printmsg "Reading Log Files List " 

        $RestoreLogFile = @()

        $LogfileId = 0

        #loop through Log files list
        foreach ($Logfilelist in $LogFileList_From_Backup)
        {

          

           if ($SQL_ll.count -in (1,$null))
           {
           $LogFileNewFolderPath = (($SQL_ll.Name).Tostring()) +"\"
           }
           else
           {                        
           $LogFileNewFolderPath = ($SQL_ll.getvalue($LogfileId)).Name+"\"
           }
           $LogFileNewFolderPath = "$lunpath$LogFileNewFolderPath"
           $LogfileId += 1
   


             #ReSet LUNPath
             if (($SQL_ll.count -le $LogfileId) -or ($SQL_ll.count -eq $null)) {$LogfileId = 0}



            # Validate and form the Log file location
            $LogFileNewFolderPath_new = $LogFileNewFolderPath + ($Logfilelist.PhysicalName).split("\")[-1] #if needed use spilt-path cmdlet
           # Writeout -printmsg "Verify if the log file [$LogFileNewFolderPath_new] exists or not. If exists, create a new log file name dynamically"

          # if ($BackupTypeDescription -eq "database")
          # {

            $ValidFilename = $null

            try {
            $ValidFilename = ValidateFileAndGetNewFileName -ServerName $ServerInstance -FilePhysicalName $LogFileNewFolderPath_new -Filelogicalname $Logfilelist.logicalname -FileDatabaseName $Databasenew -FileOverWriteDatabase $OverWriteDatabase -isDatabaseExist $isDatabaseExist -debug 
            }
            catch {
                Writeout -printmsg "The data file [$DatFileNewFolderPath_new] does not exist or could not be verified. The new file name value is [$ValidFilename]"
            }

             if ($ValidFilename -ne "" -and $ValidFilename -ne $null) #if the physical file exits then assign the newly generated file
             {

                $LogFileNewFolderPath_new = $LogFileNewFolderPath + $ValidFilename
             }

         #  } 
            
             
         #Writeout -printmsg "The data file path is [$LogFileNewFolderPath_new]. Setting this value in Relocate Log file array " 
          # assign on Relocate File object
         $RestoreLogFile += "Move '$($Logfilelist.logicalname)' to '$($LogFileNewFolderPath_new)',"
  

        }


        # assign on Data & Log File relocate object into a single Array
        $DBFiles = @()
        $DBFiles += $RestoreDBFile
        $DBFiles += $RestoreLogFile

       # $DBFiles

         
        Writeout -printmsg "Following Logical and Physical File names will be used for restore database command. I.e Printing RestoreDataFile & RestoreLogFile Array"
        #$DBFiles | Format-table -Wrap

        $DBFiles_tmp = $DBFiles | out-string

         Writeout -printmsg $DBFiles_tmp


            #remove any unwanted white space databases
            $Databasenew = $Databasenew.trim()

            Writeout -printmsg "Creating Restore commands for the database [$DatabaseNew] " #with Backupfile located in [$BackupFile_new] "

            #Form the base Restore command with Recovery statement. BUFFERCOUNT = 2200,MAXTRANSFERSIZE = 2097152,BLOCKSIZE=65536 

            $RestoreCmd = "RESTORE DATABASE [$Databasenew] FROM $BackupFile_New WITH $DBFiles_tmp$DBFiles_tmp"
         

             
  
            
                Writeout -printmsg "Adding Options "
                $RestoreCmd += "BUFFERCOUNT = 1200, MAXTRANSFERSIZE = 2097152, STATS = 5,NORECOVERY"

                

                if ($OverWriteDatabase -eq 1)
                {
                  $RestoreCmd += ", REPLACE"
                }
  

               if ($HasBackupChecksums -eq $true)
            {
                Writeout -printmsg "Adding Checksum Option "
                $RestoreCmd += ",CHECKSUM"
            }

            if ($KeepReplication -eq 1)
            {
                Writeout -printmsg "Adding KeepReplication Option "
                $RestoreCmd += " ,KEEPREPLICATION "
            } 

          
                # Print script block
          Writeout -printmsg "Final Restore command is  `n $RestoreCmd"

           
          Writeout -printmsg "Restore with NORecovery is starting for the database [$databasenew]. This Operation could take some time based on the Backup Size. Pleas check the logs periodically"
          Writeout -printmsg ""
          #>


          try{
              #execute the script block
              
              while ($server.GetActiveDBConnectionCount($databasenew) -ne 0)
              {
                 
                 Writeout -printmsg "Open connections exists for the for the database [$databasenew]. Going to Kill those connections. If the looping prooblem exists, stop the application  "
                 try {
                 $server.KillAllProcesses($databasenew) 
                 }
                 catch
                 {
                  Writeout -printmsg "Killing Active Connection Failed on [$databasenew] . Going to try again " 
                  Writeout -printmsg $_.Exception.Message
                  Writeout -printmsg $Error[0].Exception
                 }

              } 

               # Reterive restore command
               

               # Execute Restore
               Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -Query $RestoreCmd -Verbose -OutputSqlErrors $true -OutBuffer $true -AbortOnError -ErrorAction stop -ConnectionTimeout 0 -QueryTimeout 0 
               
               
               # sleep for 1 seconds
               #Start-Sleep -s 5
          }
          catch
          {
               
              Writeout -printmsg "Restore with NORecovery is Failed due to an Exception " 
              Writeout -printmsg $_.Exception.Message
              throw
            

          }

           
          Writeout -printmsg "Restore with NORecovery is Completed for the database [$databasenew]"



 
} # ValidateAndRestore_Database function ends here


# Main CODE blocks stats here *************************************************************************

    [bool] $isDatabaseExist_on_NotOnlineState = $false

    $LunPath = $null


    # Add "\" at the end if it is not there
    if ($BackupFile.Substring($BackupFile.length-1,1) -ne "\")
    {
        $BackupFile = "$BackupFile\"
    }

     $ServerInstance_rep = $ServerInstance.split("\")[0]

     $BackupFile_rep = $BackupFile -replace ":","$"

    $BackupFile_rem = "\\$ServerInstance_rep\$BackupFile_rep"

     $DTfile = Get-Date -Format yyyyMMddHHmmssfffffff
    
    $ExecutionLogFileName = "filesystem::$BackupFile_rem`RestoreLog_$RequestNum`_$DTfile`.txt"
    #$ExecutionLogFileName

 
    Writeout -printmsg   "Automation work  is Starting"
    


    if ($OperationType -notin ("Restore","Attach"))
    {
         Writeout -printmsg   "Please specify valid OperationType. Accepted values are 'Restore' or 'Attach' "
         finaloutput_NotOK -printmsg "Please specify valid OperationType. Accepted values are 'Restore' or 'Attach' "
        break
    }

    if ($OperationType -eq "Restore")
    {

  <##
        if ($DEASQLversion -eq "SQL2008R2")
        {
         $LunPath =  "E:\SQL\I01\RestoredDB\"

        }
        elseif ($DEASQLversion -eq "SQL2016") 
        {
         $LunPath =  "F:\SQL\I02\RestoredDB\"
        }
        else
        {
         

          $LunPath = Invoke-Sqlcmd -ServerInstance $ServerInstance -database master -Query "select Top 1 filename from sys.sysaltfiles where filename like '%ET%' and fileId = 1" -AbortOnError -ErrorAction stop -OutputSqlErrors $true -ConnectionTimeout 0 -QueryTimeout 0 | Format-Table -HideTableHeaders | out-string
 
         $LunPath = Split-Path(split-path($LunPath))  #=  "G:\SQL\I03\DB6001" # 
 
         $LunPath = $LunPath.Trim()
 
         $LunPath += "\"
  

   
        }
##>
        $LunPath=$RestoreLunPath+'\'

        $LunPath_rep = $LunPath -replace ":","$"

        $lunpath_rem = "\\$ServerInstance_rep\$LunPath_rep"

    #$lunpath_rem


      Writeout -printmsg "Getting Target Instance [$ServerInstance] Data & log Luns Dynamically from $LunPath "

     
    

    try {
    $SQL_dl = Get-ChildItem  "filesystem::$lunpath_rem" -ErrorAction stop | Where-Object{$_.name -match "data[0-9]"} | Select name | sort name 

    $SQL_ll = Get-ChildItem  "filesystem::$lunpath_rem" -ErrorAction Stop| Where-Object{$_.name -match "log[0-9]"} | Select name | sort name 

    # Added this code for configDB. ConfigDB does not have dedicated Log Luns
    if ($SQL_ll -eq $null)
    {
      $SQL_ll = $SQL_dl
    }


    }
    catch
    {
     Writeout -printmsg   "[$LunPath] is not valid or does not have Data & Log Luns "
     finaloutput_NotOK -printmsg "[$LunPath] is not valid or does not have Data & Log Luns "
        break
    }


   }
   

 
       # Initialize the Database Restore List array

    $DBRestoreStatus = $null

    $Restoreoutput = $null

    $DBRestoreStatus = $null

    Writeout -printmsg   "Validating Database Name"

 
   #validate the database names

     if ($Database -eq "" -or $Database -eq $null)
     {
    
        finaloutput_NotOK -printmsg "Database Name [$Database] is Invalid. Please specify valid database name. Validation Failed"
        break
     }


    $DBRestoreStatus = UpdateRestoreStatus -dbkey $Database -Last_known_Status "NotStarted" -psobjname $DBRestoreStatus

    if ($Database -in ("Master","Model","TempDB","MSDB"))
    {
        $DBRestoreStatus = UpdateRestoreStatus -dbkey $Database -Last_known_Status "Failed" -psobjname $DBRestoreStatus  -Last_Exception_Message "System Databases can not be restored"
        finaloutput_NotOk -printmsg "System Databases can not be restored."
        break
 
    }


        Writeout -printmsg "Selected Database Name is [$Database]"
     

        $BackupFile = $BackupFile.Trim()

    Writeout -printmsg "Validating Location [$BackupFile]"

       if ($BackupFile -eq "" -or $BackupFile -eq $null)
       {
      
          $DBRestoreStatus = UpdateRestoreStatus -dbkey $Database -Last_known_Status "Failed" -psobjname $DBRestoreStatus -Last_Exception_Message "[$BackupFile] is not a valid Folder. Please specify the valid Folder Location and make sure that the Account does have FULL rights to perform IO operations"
           Writeout -printmsg  "[$BackupFile] is not a valid Folder. Please specify the valid  Location and make sure that Account does have FULL rights to perform IO operations. "
          finaloutput_NotOk -printmsg "[$BackupFile] is not a valid Folder. Please specify the valid Location and make sure that Account does have FULL rights to perform IO operations. "
     
          break
       }

  

       if (-not(([System.IO.DirectoryInfo]"$BackupFile_rem").Exists))
        {
          $DBRestoreStatus = UpdateRestoreStatus -dbkey $Database -Last_known_Status "Failed" -psobjname $DBRestoreStatus -Last_Exception_Message "[$BackupFile] is not a valid Folder. Please specify the Folder Location and make sure that the Account does have FULL rights to perform IO operations."
          Writeout -printmsg  "[$BackupFile] is not a valid Folder. Please specify the valid Location and make sure that Account does have FULL rights to perform IO operations. "
          finaloutput_NotOk -printmsg "[$BackupFile] is not a valid Folder. Please specify the valid Location and make sure that the Account  does have FULL rights to perform IO operations. "
      
          break
        }

        Writeout -printmsg "Directory Location [$BackupFile] validation is success"


     Writeout -printmsg "Registering the SQL Server Instance [$ServerInstance]"


    # register the SQL Server Instance
    try {
        $server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $ServerInstance -Verbose -ErrorAction Stop
        }
    catch
    {
        Writeout -printmsg "Registering the SQL Server Instance [$ServerInstance] is Failed. SQL Instance is Invalid. Please specify Proper SQL Server Instance name and Make sure that it is up and running"
        $DBRestoreStatus = UpdateRestoreStatus -dbkey $Database -Last_known_Status "Failed" -psobjname $DBRestoreStatus -Last_Exception_Message $_.Exception.Message
        finaloutput_NotOk -printmsg $_.Exception.Message
        break
    }

  
    #get list of existing databases
     $ExistingDBList = $server.Databases
    if ($ExistingDBList.count -eq $null) # Validate if only one system DB exists. if does not exists, then SQL Instance is not valid or SQLPS can not connect
    {
    
        Writeout -printmsg "Registering the SQL Server Instance [$ServerInstance] is Failed. SQL Instance is Invalid. Please specify Proper SQL Server Instance name and Make sure that it is up and running"
        $DBRestoreStatus = UpdateRestoreStatus -dbkey $Database -Last_known_Status "Failed" -psobjname $DBRestoreStatus -Last_Exception_Message "SQL Instance is Invalid. Please specify Proper SQL Server Instance name and Make sure that it is up and running"
        finaloutput_NotOk -printmsg "SQL Instance is Invalid. Please specify Proper SQL Server Instance name and Make sure that it is up and running"
        break
        
    }


    Writeout -printmsg "Registering the SQL Server Instance [$ServerInstance] is success"


    if ($operationtype -eq "Restore")
    {

            #Writeout -printmsg "Existing databases will be overwrittern"
            #$OverWriteDatabase = 1

    Writeout -printmsg "Going to read the list of backup files located in the folder [$BackupFile]" 

 
 
    $DBBackuppath="Microsoft.PowerShell.Core\FileSystem::$BackupFile_rem"
     #Name only
    $BackupList = (Get-ChildItem $DBBackuppath -Recurse  | where {$_.name -like "$Database*.bak"} | Sort-Object {$_.name}).fullname 

    
    $Bakcount = $BackupList.Count

    if ($Bakcount -eq 0)
       {
      
      $DBRestoreStatus = UpdateRestoreStatus -dbkey $Database -Last_known_Status "Failed" -psobjname $DBRestoreStatus -Last_Exception_Message "[$BackupFile] does not have have valid backup file"
       Writeout -printmsg  "[$BackupFile] does not have have valid backup file "
      finaloutput_NotOk -printmsg "[$BackupFile] does not have have valid backup file "
     
      break
   }

         
    Writeout -printmsg "[$Bakcount] Backup Files are located in [$BackupFile]" 
    Writeout -printmsg "Storing Backup header information" 

     $BackupHdrDtl = @()
     $BackupFileList = @() 
       

   # get  Backup header from any one backup file 
    foreach ($Backfile in  $BackupList) 
    {
 
     try {

   #    Writeout -printmsg "Storing Backup header information for the file [$Backfile] is starting" 

      #  "RESTORE HEADERONLY FROM DISK = '$Backfile'"

      $BackupHdr = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "RESTORE HEADERONLY FROM DISK = '$Backfile'" -Verbose -OutputSqlErrors $true -OutBuffer $true -AbortOnError -ErrorAction stop -ConnectionTimeout 0 -QueryTimeout 0

         
     }
     catch
     {
        
        Writeout -printmsg "Storing Backup header information for the file [$Backfile] is failed.  Backup file is Invalid  " 
        $DBRestoreStatus = UpdateRestoreStatus -dbkey $Database -Last_known_Status "Failed" -psobjname $DBRestoreStatus -Last_Exception_Message $_.Exception.Message
        finaloutput_NotOk -printmsg $_.Exception.Message
        break
     }

     if ($BackupHdr -eq $null)
     {
        $DBRestoreStatus = UpdateRestoreStatus -dbkey $Database -Last_known_Status "Failed" -psobjname $DBRestoreStatus -Last_Exception_Message "Storing Backup header information for the file [$Backfile] is failed. Backup file is Invalid"
        #Writeout -printmsg "Storing Backup header information for the file [$BackupFile$Backfile] is failed. Backup file is Invalid " 
        finaloutput_NotOk -printmsg "Storing Backup header information for the file [$Backfile] is failed. Backup file is Invalid"
        break
     }

     
     Writeout -printmsg "Storing Backup header information for the file [$Backfile] is Completed" 

     #Set Backup File name so that Backup header and file names can be associated 
     #$BackupHdr.BackupDescription = $Backfile

       $BackupHdrDtl += $BackupHdr
           $BackupListFullPath_str += "Disk = '$Backfile',`n"

     <#    if ($BackupHdr.BackupSetGUID -eq $BackupInfo)
         {
           $BackupHdrDtl += $BackupHdr
           $BackupListFullPath_str += "Disk = '$Backfile',`n"
         }
         #>
    }

    $BackupListFullPath_str = $BackupListFullPath_str -replace [Regex]::Escape($BackupFile_rem) ,$BackupFile

    $BackupListFullPath_str = $BackupListFullPath_str.TrimEnd(",`n")

#    $BackupListFullPath_str



   # $BackupHdrDtl

   
    Writeout -printmsg "Backup header information is stored" 

    $BackupHdrGroupDtl = $BackupHdrDtl | Group-Object databaseName | sort-object name

  #  $BackupHdrGroupDtl

    $BackupDBCnt = $BackupHdrGroupDtl.name.Count

  #  $BackupHdrDtl
  #  Writeout -printmsg "[$BackupDBCnt] databases will be restored. " 
  #  $BackupHdrGroupDtl.name

    if ($BackupDBCnt -eq 0)
    {
       $DBRestoreStatus = UpdateRestoreStatus -dbkey $Database -Last_known_Status "Failed" -psobjname $DBRestoreStatus -Last_Exception_Message "[$BackupFile] does not have have valid backup files or does not match Backup set GUID "
       Writeout -printmsg  "[$BackupFile] does not have have valid backup file matches Backup Info "   
       finaloutput_NotOk -printmsg "Backup file(s) does not exist in [$BackupFile]"
       break
    }

    $sdt = Get-Date -Format G
    $DBRestoreStatus = UpdateRestoreStatus -dbkey $Database -Last_known_Status "Starting" -Restore_StartDateTime $sdt -psobjname $DBRestoreStatus

    #$BackupHdrGroupDtl


    #foreach ($BackDBname in $BackupHdrGroupDtl)
   # {
    for ( $i=0; $i -lt $BackupDBCnt; $i++)
    {

    $returncode = 0

    $db_tmp = $BackupHdrGroupDtl.name

   
   # Writeout -printmsg "Starting Validation and 'Restore with NORecovery' process for the database [$database]"

    $sdt = Get-Date -Format G
    $DBRestoreStatus = UpdateRestoreStatus -dbkey [$database] -Last_known_Status "Restore-with-Recovery-Starting" -Restore_StartDateTime $sdt -psobjname $DBRestoreStatus

   
    $RestoreDBHdr= $BackupHdrDtl | Where-Object {$_.databasename -eq $db_tmp } | Sort-Object $_.BackupFinishDat | select-object -first 1
    
    #$RestoreDBHdr.BackupDescription

    foreach ($RDHr in $RestoreDBHdr)
     {

     
      Writeout -printmsg "Starting Validation and 'Restore with NORecovery' process for the database [$database]"

      try{    
                                 
      ValidateAndRestore_Database -Databasenew $database -BackupPhysicalFileName $BackupListFullPath_str -BackupTypeDescription $RDHr.BackupTypeDescription -HasBackupChecksums $RDHr.HasBackupChecksums
     
      
      Writeout -printmsg "Validation and 'Restore with NORecovery' process for the database [$database] is completed" 

      $sdt = Get-Date -Format G
      $DBRestoreStatus = UpdateRestoreStatus -dbkey $database -Last_known_Status "Restore-with-Recovery-Completed" -Restore_EndDateTime $sdt -psobjname $DBRestoreStatus

      }
      catch
      {
      
      Writeout -printmsg "Validation and 'Restore with NORecovery' process for the database [$database] is failed" 

      $sdt = Get-Date -Format G
      $DBRestoreStatus = UpdateRestoreStatus -dbkey $database -Last_known_Status "Restore-with-Recovery-Failed" -Restore_EndDateTime $sdt -psobjname $DBRestoreStatus -Last_Exception_Message $_.Exception.Message
      $DBRestoreStatus = UpdateRestoreStatus -dbkey $database -Last_known_Status "Completed with some failures" -Restore_EndDateTime $sdt -psobjname $DBRestoreStatus -Last_Exception_Message $_.Exception.Message

      #$returncode = 1
      finaloutput_NotOk -printmsg "Validation and 'Restore with NoRecovery' process for the database [$database] is failed"
      break
      }
      
    
     } #foreach ($RDHr in $RestoreDBHdr)


    } #foreach ($BackDBname in $BackupHdrGroupDtl)

    } # OpertionType -eq "restore
    elseif ($opertionType = "Attach")
    {
    try {

         Attach-Database -Databasenew $database -AttachlunPath $BackupFile -AttachlunPath_rem $BackupFile_rem

      Writeout -printmsg "Database [$database] is Attached to the Instance [$ServerInstance] sucessfully" 

      $sdt = Get-Date -Format G
      $DBRestoreStatus = UpdateRestoreStatus -dbkey $database -Last_known_Status "Attach-Operation-Completed" -Restore_EndDateTime $sdt -psobjname $DBRestoreStatus
    
    }
    catch{
     Writeout -printmsg "Database [$database] Attach Operation is failed" 

      $sdt = Get-Date -Format G
      $DBRestoreStatus = UpdateRestoreStatus -dbkey $database -Last_known_Status "Attach-Operation-Failed" -Restore_EndDateTime $sdt -psobjname $DBRestoreStatus -Last_Exception_Message $_.Exception.Message
      $DBRestoreStatus = UpdateRestoreStatus -dbkey $database -Last_known_Status "Completed with some failures" -Restore_EndDateTime $sdt -psobjname $DBRestoreStatus -Last_Exception_Message $_.Exception.Message

      #$returncode = 1
      finaloutput_NotOk -printmsg "Database [$database] Attach Operation is failed"
      break
    }
    }
                
    finaloutput_OK
# Main CODE blocks ends here

}

#restoredatabase -RequestNum 711 -ServerInstance "IND1P01CB082I04\I04" -Database "ConfigDB" -RestoreType "Database" -BackupFile "H:\SQL\I04\BAK2\ExactTarget11\" -OverWriteDatabase 0 -OperationType "Restore" -Verbose -RestoreLunPath "H:\SQL\I04\D\"
RETURN $get_BackupFile = $BackupFile_New.split(",")[0]