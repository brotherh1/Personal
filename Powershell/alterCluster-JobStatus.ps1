  PARAM(
   [string] $targetINV ='XTINP1DBA01\DBAdmin',
   [string] $targetCluster = '',
   [string] $targetJob = '',
   [string] $targetStatus = ''
   )

   # .\alterCluster-JobStatus -targetCluster IND1P01CB086 -targetJob dbMaintRingBuffers -targetStatus 0
   # .\alterCluster-JobStatus -targetCluster IND1P01CB086 -targetJob dbMaintRingBuffers -targetStatus 1

    WRITE-HOST "[] Target Cluster: $targetCluster"
    WRITE-HOST "[] Target Job: $targetJob"
    IF($targetStatus -ne '')       
        {
            WRITE-HOST "[] Target Status (0 or 1): $targetStatus "
        }
    ELSE
        {
            WRITE-HOST "[] Display Current Status"
        }

    $Readhost = Read-Host "Continue? ( y / n ) "
    Switch ($ReadHost) 
     { 
       Y { WRITE-HOST "[] Inventory Server: $targetINV" }
       N { RETURN } 
       Default { RETURN } 

     } 
    WRITE-HOST " "

    If( $targetCluster -ne '')
    {
        
        $f_selectSQL = "SELECT [SQLInstallation] FROM [DBA].[dbo].[ExactTargetSQLInstallations] where servergroupname = 'Cluster "+ $targetCluster +"' order by ipAddress"    
        WRITE-HOST `t $f_selectSQL
        WRITE-HOST " "
        $instanceList = @( invoke-sqlcmd -ServerInstance $targetINV -Query $f_selectSQL | select -exp sqlinstallation )
        IF(!$instanceList)
            { 
                WRITE-HOST "[ALERT] No Instance returned for Cluster: $f_targetHost "
            }
        ELSE
            {
                ForEach( $instance in $instanceList )
                {
                    WRITE-HOST "[] $instance CURRENT status of: $targetJob "
                    $selectSQL = "select name, enabled from msdb..sysjobs where name = '"+ $targetJob +"'"
                    invoke-sqlcmd -ServerInstance $instance -Query $selectSQL | format-table -AutoSize         
                    
                    IF($targetStatus -ne '')       
                    {
                        write-HOST "[] Setting new status"
                        $execSQL = "EXEC msdb.dbo.sp_update_job @job_name=N'"+ $targetJob +"', @enabled="+ $targetStatus
                        invoke-sqlcmd -ServerInstance $instance -Query $execSQL

                        WRITE-HOST "[] $instance NEW status of: $targetJob "
                        $selectSQL = "select name, enabled from msdb..sysjobs where name = '"+ $targetJob +"'"
                        invoke-sqlcmd -ServerInstance $instance -Query $selectSQL | format-table -AutoSize
                    }
                }
            }
    }
    ELSE
    {
        write-host "NAME
    alterCluster-JobStatus
    
SYNTAX
    alterCluster-JobStatus [-targetCluster <string[]> [-targetJob <string[]> [-targetStatus <string[]>]
    
    alterCluster-JobStatus [[-targetINV] <string>] -targetCluster <string[]> [-targetJob <string[]> [-targetStatus <string[]>]] 
    

ALIASES
    NONE
    

REMARKS
    Something importatnt."
    }