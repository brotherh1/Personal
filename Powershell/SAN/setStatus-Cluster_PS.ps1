
<#  CONTINUE TO USE MAINTENANCE DIRECTOR   #>
function setStatus-deprecation ( [string] $f_targetHost, [string] $newStatus  )
{
   IF($newStatus -eq "")
        {
            WRITE-HOST "[] No status - display current"
            checkStatus-deprecation $f_targetHost
        }
    ELSE
        {
            IF( $newStatus -eq "OFF" ){ $f_status = 0 } ELSE { $f_status = 1 }
            $f_selectSQL = "UPDATE msdb..sysjobs SET enabled = $f_status where (name like 'Deprecation%' or name like 'DEDeprecation%') "
            invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL | format-table -AutoSize
        }
}

<#  CONTINUE TO USE MAINTENANCE DIRECTOR  #>
function setStatus-Audit ( [string] $f_targetHost, [string] $newStatus )
{
    IF($newStatus -eq "")
        {
            WRITE-HOST "[] No Status - display current"
            #checkStatus-Audit $f_tagetHost
        }
    ELSE
        {
            $f_selectSQL = "USE [MASTER];ALTER SERVER AUDIT [Audit_Cmdshell] WITH (STATE = $newStatus);"
            invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL -QueryTimeout 65000
            $f_selectSQL = "USE [MASTER];ALTER SERVER AUDIT [Members_CreateDate] WITH (STATE = $newStatus);"
            invoke-sqlcmd -ServerInstance $f_targetHost -Query $f_selectSQL -QueryTimeout 65000
        }
}

function setStatus-Standby ( [string] $f_targethost, [string] $newStatus )
{
    switch ($sourceHost) 
    {
        {($_ -LIKE "xtinP1*")}  {$standbyMGR = 'XTINBSD2\I2'        ; break}
        {($_ -LIKE "IND1P01*" )} {$standbyMGR = "XTINBSD2\I2"        ; break}
        {($_ -LIKE "xtinP2*")}  {$standbyMGR = 'XTINBSD2\I2'        ; break}
        {($_ -LIKE "IND1P02*" )} {$standbyMGR = "XTINBSD2\I2"        ; break}
        {($_ -LIKE "xtnv*")}    {$standbyMGR = 'XTNVP1BSD2\I2'      ; break}
        {($_ -LIKE "las*" )}    {$standbyMGR = 'XTNVP1BSD2\I2'      ; break}
        {($_ -LIKE "xtga*")}    {$standbyMGR = 'XTGAP4DBA01\I1'     ; break}
        {($_ -LIKE "atl*" )}    {$standbyMGR = 'XTGAP4DBA01\I1'     ; break}
        {($_ -LIKE "DFW*" )}    {$standbyMGR = 'DFW1P05DBA01I04\I04'; break}
        default {$standbyMGR = "UNKNOWN"}
    }

    #Code to alter all in a cluster to 'ACTIVE' or 'PAUSED'  Where status != "disabled"

##	$pauseAllLogshippingQuery = "UPDATE StandbyDBManager.dbo.StandbyConfig
##	                                SET Status = 'Paused'
##	                                WHERE StandbyConfigID IN (899, 897, 898, 863, 864, 859, 875, 874, 867, 872, 869, 860, 871, 862, 865, 880, 873, 866, 892, 870, 902, 868, 891, 905);";
##
##	cls;
##
##	try
##	{
##	    Invoke-Sqlcmd -ServerInstance $standbyMGR -Database MASTER -Query $pauseAllLogshippingQuery -QueryTimeout 180 -ErrorAction Stop;
##	    
##	    Write-Host "All log shipping is now paused for Ally DR!" -ForegroundColor Yellow;
##	}
##	catch
##	{
##	    Write-Host "There was an error!";
##	}
}

<#  CONTINUE TO USE MAINTENANCE DIRECTOR  #>
function setCluster-Status ( [string] $f_targetHost, [string] $f_command, [string] $f_status )
{
    WRITE-HOST "[] Inventory Server: $targetINV"
    $f_selectSQL = "SELECT [SQLInstallation] FROM [DBA].[dbo].[ExactTargetSQLInstallations] where servergroupname = 'Cluster "+ $f_targetHost +"' "
    WRITE-HOST `t $f_selectSQL
    $instanceList = @( invoke-sqlcmd -ServerInstance $targetINV -Query $f_selectSQL | select -exp sqlinstallation )

    ForEach( $instance in $instanceList )
    {
        WRITE-HOST $instance
        if (test-Connection -ComputerName $instance.substring(0,$instance.IndexOf('\')) -Count 2 -Quiet ) 
        {  
            switch ($f_command) 
             { 
               {($_ -LIKE "deprecation")}   { setStatus-deprecation $instance $f_status }
               #{($_ -LIKE "readiness")}    { checkFailover-readiness $instance }
               #{($_ -LIKE "service")}      { checkStatus-service $instance }
               {($_ -LIKE "audit")}         { setStatus-Audit $instance $f_status }
               {($_ -LIKE "standby")}       { setStatus-standby $instance $f_status }

                default {WRITE-HOST "BAD Parameter"}
            }
        }
        ELSE
        {
            WRITE-HOST "Instance not online"
            WRITE-HOST " "
        }
    }
}


Function getadvanced-Command ( [string] $f_helptopic)
{
    get-ChildItem function:\ | where { $_ -like 'checkStatus-*' }
    get-ChildItem function:\ | where { $_ -like 'setStatus-*' }
}

<#
TAKE FIRST INSTANCE RESOURCES DOWN
    setStatus-Audit Ind1p01c029D2\I2 OFF
    setStatus-Deprecation Ind1p01c029D2\I2 OFF
CONFIRM READY TO TAKE DOWN
    checkStatus-Deprecation Ind1p01c029D2\I2
    checkFailover-readiness Ind1p01c029D2\I2
    checkStatus-transaction Ind1p01c029D2\I2

SET CLUSTER RESOURCES DOWN
    setCluster-Status Ind1p01c029 Audit OFF
    setCluster-Status Ind1p01c029 Deprecation OFF
CONFIRM
    checkStatus-Cluster Ind1p01c029 Audit
    checkStatus-Cluster Ind1p01c029 Deprecation

INSTANCE IS BACK ONLINE 
    checkStatus-service Ind1p01c029D1\I1
    checkStatus-instance  Ind1p01c029D1\I1
    checkStatus-MSDTC Ind1p01c029D2\I2

IF DB IN RECOVERY
    checkMember-recovery Ind1p01c029D1\I1

IF DB USES AVAILABILTY GROUPS
    checkStatus-Availability Ind1p01c029D1\I1

AFTER MIGRATION IS COMPLETED
    setCluster-Status Ind1p01c029 audit ON
    setCluster-Status Ind1p01c029 Deprecation ON
#>
