 PARAM(

   [string] $targetDBHost = $env:COMPUTERNAME, #"XTINP1CL09N1",  # "DFW1P05C055N01", #
   [string] $expectedStatus = "RUNNING"

#  \\XTINP1DBA01\GitHub\dbops_workingfolders\dbops\Harold\powerShell\ggStatusCheck.ps1 -targetDBHost "DFW1P05C055I01" -expectedStatus "RUNNING"
#  \\XTINP1DBA01\GitHub\dbops_workingfolders\dbops\Harold\powerShell\ggStatusCheck.ps1 -targetDBHost "DFW1P05C055I01" -expectedStatus "STOPPED"

#  \\XTINP1DBA01\GitHub\dbops_workingfolders\dbops\Harold\powerShell\ggStatusCheck.ps1 -targetDBHost "XTINP1CL09D7" -expectedStatus "RUNNING"
#  \\XTINP1DBA01\GitHub\dbops_workingfolders\dbops\Harold\powerShell\ggStatusCheck.ps1 -targetDBHost "XTINP1CL09D7" -expectedStatus "STOPPED"
    )
function find-drive ([string] $driveService )
{
    $driveService = $driveService.replace("GGMGR_","")
    $driveService = $driveService.replace("I0","I")  #just in case 

    write-host `t"Working with: $driveService"

    switch ($driveService) 
    { 
        I1  {$driveService = "E:"} 
        I2  {$driveService = "F:"} 
        I3  {$driveService = "G:"} 
        I4  {$driveService = "H:"} 
        I5  {$driveService = "J:"} 
        I6  {$driveService = "K:"} 
        I7  {$driveService = "L:"}
        I8  {$driveService = "M:"} 
        I9  {$driveService = "N:"} 
        I10 {$driveService = "O:"} 
        I11 {$driveService = "P:"} 
        I12 {$driveService = "S:"} 
        I13 {$driveService = "U:"} 
        I14 {$driveService = "V:"} 
        I15 {$driveService = "W:"} 
        I16 {$driveService = "X:"} 
        default {$driveService = "BAD INSTANCE"}
    }

    Write-HOST `t`t"Verify existence of drive: $driveService"

    # return "$driveService"

    $remoteCMD = "Invoke-Command -ComputerName $targetDBHost -ScriptBlock { Get-ChildItem -Path $driveService -Filter ggsci.exe -Recurse -ErrorAction SilentlyContinue -Force | Select-Object -Property FullName }"
    $result = Invoke-Expression $remoteCMD

    $dynamicGGSCI = $result.FullName
   # write-host "GGSCI location: $dynamicGGSCI"
    return $dynamicGGSCI

}

function Get-status ([string] $exePath, [string] $expectedValue)
{    <####################################
      # Golden Gate Status Monitor
      # Developed: Sarjen Haque
      #####################################>

     $objectStatus = ""

     $String = "CMD /c echo Status All | $exePath "
     write-host `t`t`t"$String"

     $remoteCMD = "Invoke-Command -ComputerName $targetDBHost -ScriptBlock { $String }"
     $result = Invoke-Expression $remoteCMD
     #Invoke-Expression $remoteCMD
     #$result

     #write-output $result 
     $raw = $result -match 'EXTRACT|REPLICAT' # we are not searching for one process

     #write-output $raw
     [StringSplitOptions]$Options = "RemoveEmptyEntries"
    
     # loop through each line and break
     foreach ($line in $raw)
     {
           $wrd = $line.Split(" ", $Options)
           $lg = $wrd[3].Split(":")
           $tm = $wrd[4].Split(":")
                    
           $result2 = [Ordered]@{
                    "Program" = $wrd[0];
                    "Status" = $wrd[1];
                    "Name" = $wrd[2];
                    "LagMin" = [int]$lg[0] * 60 + [int]$lg[1];
                    "Lag" = $wrd[3];
                    "ChkPt" = $wrd[4];
                    "ChkPtMin" = [int]$tm[0] * 60 + [int]$tm[1];
           }
           $obj = New-Object -TypeName PSObject -Property $result2

           #write-output `t"Confirm $targetDBHost $whatType Status $expectedValue"
           $objectName = $result2.Name
           $objectStatus = $result2.Status
          
          # Write-Output $obj
          # RETURN

            If($objectStatus -eq $expectedValue)
            {
                write-output `t`t"[OK] $objectName - $objectStatus"
            }
            ELSE
            {
                If(!$objectStatus) {$objectStatus = "NONEXISTENT" }
                write-output `t`t"[FAIL] $objectName - $objectStatus - raise CRITICAL alert"
                #EXIT
       
            } 
     }
           
  
     
}

write-output "[] Started: $((Get-Date).ToString())"
Write-Output "[] TargetDBHost: $targetDBHost "
Write-Output "   "

write-output "[] Discover GGMgr services on host: "
$servicesList = Invoke-Command -ComputerName $targetDBHost -ScriptBlock { get-service |  Where-object {$_.Name -like "GGMGR*"  } }

forEach( $service in $servicesList)
{
    write-host " "
    $ggsciSourcePath = ""
    
    # Does Root Drive exist on this host?
    # Invoke-Command -ComputerName XTINP1CL09N1 -ScriptBlock { GET-WMIOBJECT –query “SELECT * from win32_logicaldisk where DriveType = '3' and DeviceID = 'G:' ”  }
    $ggsciSourcePath = find-drive $service
    #$ggsciSourcePath = $ggsciDrive + $ggsciSourcePath
    #write-host  $ggsciSourcePath

    IF(  $ggsciSourcePath -ne $null )
    {
        # If root drive exists is GGMGR running?
 
        # If Root drive exists and GGMG is running are Extract, Pumps and Replicats running?
        write-output `t`t"Confirm status = $expectedStatus "
            Get-status $ggsciSourcePath $expectedStatus 
    }
    ELSE
    {
        write-host `t"[Warning] No Root Drive - Assumption is this instance is on another server in this cluster"
    }
} 
