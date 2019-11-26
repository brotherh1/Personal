Function fetch-sourceList
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [int] $searchTypeID = 999,
		    [int] $targetStack = 999,
            [boolean] $SuppressDetail,
		    [string] $invDB = "SQLmonitor",
		    [string] $invServer = "XTINOPSD2\I2",
            [switch] $Custom
        )

    IF( $targetStack -eq 999 -AND $searchTypeID -ne 999)
        {
            WRITE-VERBOSE 'NonSpecific Search'
            $searchSQL = 'SELECT DB.Stack,DBT.AppDatabaseTypeID,DB.DatabaseName,INST.InstanceName
            FROM  [SQLMonitor].[dbo].[Database] AS DB 
	            LEFT JOIN [SQLMonitor].[dbo].[Instance] AS INST ON (DB.HostInstance = INST.InstanceID)
	            LEFT JOIN [SQLMonitor].[dbo].[DatabaseTypes] AS DBT ON (DB.DatabaseTypeID = DBT.DatabaseTypeID)
            WHERE DB.IsProduction = 1 AND DB.Stack != 999 AND DBT.AppDatabaseTypeID = '+ $searchTypeID
        }
    ELSEIF( $searchTypeID -ne 999)
        {
            WRITE-VERBOSE 'Specific Search'
            $searchSQL = 'SELECT DB.Stack,DBT.AppDatabaseTypeID,DB.DatabaseName,INST.InstanceName
            FROM  [SQLMonitor].[dbo].[Database] AS DB 
	            LEFT JOIN [SQLMonitor].[dbo].[Instance] AS INST ON (DB.HostInstance = INST.InstanceID)
	            LEFT JOIN [SQLMonitor].[dbo].[DatabaseTypes] AS DBT ON (DB.DatabaseTypeID = DBT.DatabaseTypeID)
            WHERE DB.IsProduction = 1 AND DB.Stack = '+ $targetStack +' AND DBT.AppDatabaseTypeID = '+ $searchTypeID
        }

    WRITE-VERBOSE $searchSQL

    $dbOBJ = Invoke-Sqlcmd -ServerInstance $invServer -Database $invDB -Query $searchSQL -QueryTimeout 65535

    return $dbOBJ
}

function search-routes
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
             [Object[]] $ss_dbOBJ,
             [string] $whereRouteName,
             [switch] $Custom
        )

    $sourceinstance = $ss_dbOBJ.InstanceName
    $sourceDatabase = $ss_dbOBJ.DatabaseName
    $selectSQL = "use "+ $ss_dbOBJ.DatabaseName +";select '"+ $sourceinstance +"' AS InstanceName, name from sys.routes "+ $whereRouteName +" Group by name;"
    WRITE-VERBOSE $selectSQL

    $sourceRoutes = Invoke-Sqlcmd -ServerInstance $sourceinstance -Database $sourceDatabase -Query $selectSQL -QueryTimeout 65535

    return $sourceRoutes
}

function search-services
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
             [Object[]] $ss_dbOBJ,
             [string] $whereServiceName,
             [switch] $Custom
        )

    $targetInstance = $ss_dbOBJ.InstanceName
    $targetDatabase = $ss_dbOBJ.DatabaseName
    $selectSQL = "use "+ $ss_dbOBJ.DatabaseName +";select '"+ $targetInstance +"' AS InstanceName, serviceName from dbo.ReplicationSubscriber "+ $whereServiceName +" Group by serviceName;"
    WRITE-VERBOSE $selectSQL

    $sourceRoutes = Invoke-Sqlcmd -ServerInstance $targetInstance -Database $targetDatabase -Query $selectSQL -QueryTimeout 65535

    return $sourceRoutes
}

function fetch-targetList
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [int] $searchTypeID = 26,
		    [int] $targetStack = 999,
            [boolean] $SuppressDetail,
		    [string] $invDB = "SQLmonitor",
		    [string] $invServer = "XTINOPSD2\I2",
            [switch] $Custom
        )
    
    WRITE-VERBOSE 'Target Search'
    $searchSQL = 'SELECT DB.Stack,DBT.AppDatabaseTypeID,DB.DatabaseName,INST.InstanceName
    FROM  [SQLMonitor].[dbo].[Database] AS DB 
	    LEFT JOIN [SQLMonitor].[dbo].[Instance] AS INST ON (DB.HostInstance = INST.InstanceID)
	    LEFT JOIN [SQLMonitor].[dbo].[DatabaseTypes] AS DBT ON (DB.DatabaseTypeID = DBT.DatabaseTypeID)
    WHERE DB.IsProduction = 1 AND DB.Stack != '+ $targetStack +' AND DBT.AppDatabaseTypeID = '+ $searchTypeID

    WRITE-VERBOSE $searchSQL

    $dbOBJ = Invoke-Sqlcmd -ServerInstance $invServer -Database $invDB -Query $searchSQL -QueryTimeout 65535

    return $dbOBJ
}


#################################################
function process-info
{
    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
            [int] $searchTypeID = 26,
		    [int] $targetStack = 999,
            [boolean] $SuppressDetail,
		    [string] $invDB = "SQLmonitor",
		    [string] $invServer = "XTINOPSD2\I2",
            [switch] $customVerbose
            )

    ## GET SOURCE(S)
    $sourceList =  fetch-sourceList $searchTypeID $targetStack -Custom:$CustomVerbose -whatif
    $sourceList | Sort-Object -Property Stack | Format-Table -Auto

    IF( $targetStack -ne 999 )
        {
            ForEach( $sourceInstance in $sourceList)
            {
                $sourceRoutes = search-routes $sourceInstance "where name <> 'AutoCreatedLocal'" -Custom:$CustomVerbose -whatif
            }

            $sourceRoutes | Format-Table -Auto
            $sourceRoutes.Count
        }
    ELSE
        {
            WRITE-VERBOSE 'DONE - not searching local routes'
        }


    ## GET TARGET(S)
    IF( $targetStack -ne 999 )
        {
            $targetList =  fetch-targetList $searchTypeID $targetStack -Custom:$CustomVerbose -whatif
            $targetList | Sort-Object -Property Stack | Format-Table -Auto
        }
    ELSE
        {
            WRITE-VERBOSE 'DONE - not searching for target hosts'
        }


    ## CHECK INBOUND SERVICE
    IF( $targetStack -ne 999 )
        {
            ForEach( $sourceInstance in $sourceList)
            {
                $targetServiceNames = @()
                ForEach( $targetInstance in $targetList)
                {
                    $tempWhere = "where serviceName = 'ReplicationInboundService"+  $sourceInstance.DatabaseName.replace('DB','') + $sourceInstance.InstanceName.replace('\','_') +"'" 
                    $targetServiceNames += search-services $targetInstance $tempWhere -Custom:$CustomVerbose -whatif

                }
                $targetServiceNames | Format-Table -Auto
                $targetServiceNames.count
             }
        }
    ELSE
        {
            WRITE-VERBOSE 'DONE - not searching remote services'
        }

    ## CHECK INBOUND ROUTE
    IF( $targetStack -ne 999 )
        {
            ForEach( $sourceInstance in $sourceList)
            {
                $targetInboundRoutes = @()
                ForEach( $targetInstance in $targetList)
                {
                    $tempWhere = "where name = 'ReplicationInboundService"+  $sourceInstance.DatabaseName.replace('DB','') + $sourceInstance.InstanceName.replace('\','_') +"Route'" 
                    $targetInboundRoutes += search-routes $targetInstance $tempWhere -Custom:$CustomVerbose -whatif

                    #$serviceVerboseMessage = "Target Service Count: "+ $targetInstance.InstanceName +" "+ $sourceInstance.InstanceName.replace('\','_') +" "+ $serviceNames.serviceName.Count
                    #WRITE-VERBOSE $serviceVerboseMessage
                }
                $targetInboundRoutes | Format-Table -Auto
                $targetInboundRoutes.count
             }
        }
    ELSE
        {
            WRITE-VERBOSE 'DONE - not searching local routes'
        }

    ## CHECK OUTBOUND ROUTE
    IF( $targetStack -ne 999 )
        {
            ForEach( $sourceInstance in $sourceList)
            {
                $targetOutboundRoutes = @()
                ForEach( $targetInstance in $targetList)
                {
                    $tempWhere = "where name = 'ReplicationOutboundService"+  $sourceInstance.DatabaseName.replace('DB','') + $sourceInstance.InstanceName.replace('\','_') +"Route'" 
                    $targetOutboundRoutes += search-routes $targetInstance $tempWhere -Custom:$CustomVerbose -whatif

                    #$serviceVerboseMessage = "Target Service Count: "+ $targetInstance.InstanceName +" "+ $sourceInstance.InstanceName.replace('\','_') +" "+ $serviceNames.serviceName.Count
                    #WRITE-VERBOSE $serviceVerboseMessage
                }
                $targetOutboundRoutes | Format-Table -Auto
                $targetOutboundRoutes.count
             }
        }
    ELSE
        {
            WRITE-VERBOSE 'DONE - not searching local routes'
        }

    ## Check SYSTEM DB


    ## CHECK ConfigDBmaster


    ## check configDB


    ## compile large object
    IF( $targetStack -ne 999 )
        {
            ForEach( $sourceInstance in $sourceList )
            {
                $tempSource = $sourceInstance.InstanceName.Replace("\","_")

                ForEach( $possibleTarget in $targetList )
                {   
                    $possibleTarget
                    $tempTarget = $possibleTarget.InstanceName.Replace("\","_")
                
                    ForEach( $sourceRoute in $sourceRoutes ) # does the source stack have routes to the possible targets?
                    {
                        IF($sourceRoute.name -match $tempTarget){$sourceRoute.name}
                    }

                    ForEach( $targetService in $targetServiceNames)  # Does the target stack have Inbound 
                    {
                        #$targetService.servicename
                        IF( $targetService.serviceName -match $tempSource -AND $targetService.InstanceName -eq $possibleTarget.InstanceName) { $targetService.serviceName }
                    }

                    ForEach( $InboundRoute in $targetInboundRoutes)  # Does the target stack have Inbound 
                    {
                        #$targetService.servicename
                        IF( $InboundRoute.Name -match $tempSource -AND $InboundRoute.InstanceName -eq $possibleTarget.InstanceName) { $InboundRoute.Name }
                    }

                    ForEach( $OutboundRoute in $targetOutboundRoutes)  # Does the target stack have Inbound 
                    {
                        #$targetService.servicename
                        IF( $OutboundRoute.Name -match $tempSource -AND $OutboundRoute.InstanceName -eq $possibleTarget.InstanceName) { $OutboundRoute.Name }
                    }
                }
            }
       # $sourceRoutes.name
        }
}

<##

process-info 26 -verbose -whatif    

process-info 26  1 -verbose -whatif
process-info 26  2 -verbose -whatif
process-info 26  3 -verbose -whatif #nothing
process-info 26  4 -verbose -whatif
process-info 26  5 -verbose -whatif
process-info 26  6 -verbose -whatif
process-info 26  7 -verbose -whatif
process-info 26  8 -verbose -whatif
process-info 26  9 -verbose -whatif #nothing
process-info 26 10 -verbose -whatif
process-info 26 11 -verbose -whatif


Compare-Object -ReferenceObject $sccm -DifferenceObject $wpt -IncludeEqual 

##>