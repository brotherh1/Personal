#-- Ticket W-4583784
[string] $domainName = ".XT.LoCaL"        # "<Domain>"
[string] $targetServer = "IND1P01C089I06" # "<TargetServer>"
[string] $targetInstance = "I06"          # "<TargetInstance>"
[string] $targetDBID = "143"              # "<TargetDBID>"
# ClusterName manual input - going to calculate it
[string] $emptySpace = "   "
    $sourceServerFQDN = $sourceServer + $domainName 

    IF ([System.Int32]::TryParse($targetServer.substring($targetServer.length-3), [ref] 0)) 
        {$f_targetInstance ="I" + $targetServer.substring($targetServer.length-3)
         $f_targetCluster = $targetServer.substring(0,$targetServer.length-4) + $domainName}
    ELSEIF ([System.Int32]::TryParse($targetServer.substring($targetServer.length-2), [ref] 0))
        {$f_targetInstance ="I" + $targetServer.substring($targetServer.length-2)
         $f_targetCluster = $targetServer.substring(0,$targetServer.length-3) + $domainName}
    ELSEIF ([System.Int32]::TryParse($targetServer.substring($targetServer.length-1), [ref] 0)) 
        {$f_targetInstance ="I" + $targetServer.substring($targetServer.length-1)
         $f_targetCluster = $targetServer.substring(0,$targetServer.length-2) + $domainName}

If($targetInstance -eq $f_targetInstance )
    {
        $instanceLUNs = "*" +"_DB"+ $targetDBID +"*"
    }
ELSE
    {
        THROW [System.IO.FileNotFoundException] "Instance mismatch - check names"
    }

$remoteCMD = 'invoke-command -computerName '+ $f_targetCluster +' -ScriptBlock { get-clusterresource | where-object {$_.resourceType.name -eq "physical disk"  -and $_.ownergroup -eq "'+ $targetInstance +'" } | Get-ClusterOwnerNode } '
$ownerNodes =  invoke-expression $remoteCMD #| select -exp Name, ownerNodes
$remoteCMD = "invoke-command -computerName $f_targetCluster -ScriptBlock { Get-ClusterNode -Cluster $f_targetCluster | Sort-Object } "
$nodeList = invoke-expression $remoteCMD


$infoHeader = "Possible Owners: "
$infoHeader
$emptySpace + $nodelist.Name 
$emptySpace

IF($ownerNodes.Count -gt 0)
    {
        ForEach ($LUN in $ownerNodes )
        {
            $LUN.ClusterObject + " - Checking Possible Owners"
            #Possible efficiency update - create array for preferred owners - compare to nodelist array.
 
            #Assumption: Preferred owners should equal to or be greater than cluster nodes in count (node being offline could affect count)
            #problem is it will not be revealed if we don't loop - removing "IF/ELSE" statement.
            #If($ownerNodes.Count -ge $nodeList.Count)
            #    {
                    $misMatch = $nodeList.Count
                    ForEach($node in $nodeList)
                    {
                        #$mismatch
                        ForEach ($singleLUN in $LUN.OwnerNodes )
                        { 
                            IF($node.Name -eq $singleLUN)
                            {
                                # write-host "matchfound"  Physical node is in possible owner list.
                                $emptySpace + $node.Name +" Physical node found in possible owners."
                                --$mismatch 
                            }
                        }
            
                    }

                    IF( $mismatch -eq 0 )
                        { 
                            $successMSG = "Success - All available nodes in cluster listed as possible owners." 
                            $successMSG
                        } 
                    else 
                        { 
                            THROW [System.IO.FileNotFoundException] "MisMatch between nodes in Cluster and Possible Owners" 
                        }
            #    }
            #ELSE
            #    {
            #            THROW [System.IO.FileNotFoundException] "Preferred owner Count less than node count - " 
            #    }
        }
    }
ELSE
    {
        THROW [System.IO.FileNotFoundException] "No storage allocated to instance: $targetInstance for DBID: $targetDBID"
    }
;

