Function check-preFailover
{
    [cmdletbinding()]
    PARAM ( 
            [Parameter( Mandatory = $True, ValueFromPipeline = $True )][string[]] $instanceList ='IND2Q00DBA02.QA.LOCAL\I2',
            #[string] $targetPolicy = '', #'policy.MSDTCactive',
            #[string] $targetAction = '',
            [Parameter(Mandatory=$false)][switch] $takeAction = $false#,
            #[Parameter(Mandatory=$false)][switch] $verbose
          )

    #IF($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) { WRITE-HOST "VERBOSE" }
        
    function process-policy
    {
        PARAM ( [string] $serverinstance,
                [string] $policy,
                [string[]] $action,
                [string] $BasicCreds )

        $policy = $policy.toLower()
        $action = $action.toLower()
        $serverinstance = $serverinstance.replace('#','%23')
        $policyEndpoint = "/dbserver/$serverinstance/$policy" 
  
        $actionEndpoint = @()
        $actionEndpoint = $action | ForEach-Object { "/dbserver/$serverinstance/$_" }
  
        WRITE-VERBOSE "[] Processing: $endpoint"

        $policyEndpointList = @( $policyEndpoint )
        $actionEndpointList = @( $actionEndpoint )

        ForEach($actionEP in $actionEndpoint)
            {
                #$actionEndpoint = "/dbserver/$serverinstance/$action"
                WRITE-VERBOSE "[] Possible EndPoint: $actionEP"
            }

        #Hit some endpoints
        TRY
            {
                WRITE-VERBOSE "Invoke-RestMethod -Uri `"$URLRoot/$policyEndpointList`" -Method GET -Headers @{`"Authorization`"=`"$BasicCreds`"}"
                $policyResults =  $policyEndpointList | %{Invoke-RestMethod -Uri "$URLRoot/$($_)" -Method GET -Headers @{"Authorization"="$BasicCreds"}}
            }
        CATCH
            {
                $myDetail = $_.Exception.Message -replace('The remote server returned an error: ','')
                IF($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) # Display GET ERROR
                    {  
                        $policyResults = @{ Status = "RED"; Value = "3"; State = "ERROR"; DETAIL = "$myDetail"; }
                    }
                ELSE
                    {
                        $policyResults = @{ Status = "RED"; Value = "3"; State = "ERROR"; DETAIL = "CALL DBA"; }
                    }
            }

        IF( ($policyResults.Value -ne "0") -AND ($action.Count -ne 0) -AND ($policyResults.State -ne "ERROR") )#-AND ($policyResults.DETAIL -ne "CALL DBA") )
            {
                IF( $takeAction )
                    {
                        WRITE-VERBOSE "Taking Action: $action "
                        TRY
                            {
                                WRITE-VERBOSE "Invoke-RestMethod -Uri `"$URLRoot/$($_)`" -Method POST -Headers @{`"Authorization`"="$BasicCreds"}"
                                $actionResults =  $endpointList | %{Invoke-RestMethod -Uri "$URLRoot/$($_)" -Method POST -Headers @{"Authorization"="$BasicCreds"}}
                            }
                        CATCH
                            {
                                #$myDetail = $_.Exception.Message -replace('The remote server returned an error: ','')
                                $actionResults = @{ Status = "RED"; Value = "3"; State = "ERROR"; DETAIL = "CALL DBA"; }
                                #$actionResults = @{ Status = "RED"; Value = "3"; State = "CALL DBA"; DETAIL = "$myDetail"; }
                            }
                        
                        WRITE-VERBOSE "Attemping POLICY again - even IF action fails..."
                        TRY
                            {
                                $policyResults =  $policyEndpointList | %{Invoke-RestMethod -Uri "$URLRoot/$($_)" -Method GET -Headers @{"Authorization"="$BasicCreds"}}
                            }
                        CATCH
                            {
                                $myDetail = $_.Exception.Message -replace('The remote server returned an error: ','')
                                IF($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) # Display GET ERROR
                                    {  
                                        $policyResults = @{ Status = "RED"; Value = "3"; State = "ERROR"; DETAIL = "$myDetail"; }
                                    }
                                ELSE
                                    {
                                        $policyResults = @{ Status = "RED"; Value = "3"; State = "ERROR"; DETAIL = "CALL DBA"; }
                                    }
                            }
                    }
                ELSE
                    {
                        WRITE-VERBOSE `t"Not Taking Action"
                    }
            }
        ELSEIF( ($policyResults.Value -ne "0") -AND ($policyResults.State -eq "ERROR") ) #-AND ($policyResults.DETAIL -eq "CALL DBA") )
            {
                IF( $action.Count -eq 0 )
                    {
                        WRITE-VERBOSE `t"Process Failure - No action "
                    }
                ELSE
                    {
                        WRITE-VERBOSE `t"Process Failure - Not taking action: $action "
                    }
            }
        ELSEIF( ($policyResults.Value -ne "0") -AND ($action -eq "") )
            {
                WRITE-VERBOSE "No actions to take."
            }

        #$Results | Format-table -AutoSize
        #$Results.Count
        $itemPolicy = $policy -REPLACE("policy/","")

        ForEach($item in $policyResults)
        {
            IF( $item.status -eq "RED" )
                {
                    WRITE-HOST $itemPolicy.padRight(32-$itemPolicy.status.Length) -f white -nonewline;WRITE-HOST $item.status.padRight(9-$item.status.Length), $item.Value.ToString().padRight(6-$item.Value.Length), $item.State.padRight(15-$item.state.Length), $item.Detail -foregroundColor $item.status | format-table -AutoSize
                }
            ELSEIF( $item.status -eq "YELLOW" )
                {
                    WRITE-HOST $itemPolicy,$item.status.padRight(11-$item.status.Length) -f white -nonewline;WRITE-HOST  $item.Value.ToString().padRight(6-$item.Value.Length), $item.State.padRight(15-$item.state.Length), $item.Detail -foregroundColor $item.status | format-table -AutoSize
                }
            ELSE # GREEN
                {
                    WRITE-HOST $itemPolicy.padRight(32-$itemPolicy.status.Length) -f white -nonewline;WRITE-HOST $item.status.padRight(11-$item.status.Length), $item.Value.ToString().padRight(6-$item.Value.Length), $item.State.padRight(15-$item.state.Length), $item.Detail -foregroundColor $item.status | format-table -AutoSize
                }
        }
        WRITE-HOST " "

    }

    function Get-BasicAuthCreds 
    {
        param([string]$Username,[string]$Password)
        $AuthString = "{0}:{1}" -f $Username,$Password
        $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
        return "Basic $([Convert]::ToBase64String($AuthBytes))"
    }

    #$cred = Get-Credential

    $BasicCreds = Get-BasicAuthCreds $cred.UserName $cred.GetNetworkCredential().password

    ForEach( $targetInstance in $instanceList )
    {
        
        WRITE-VERBOSE "[] Target Instance: $targetInstance "
        WRITE-VERBOSE "[] Take Action: $takeAction "
        WRITE-VERBOSE " "

        WRITE-HOST "POLICY                         ","Status","Value","State     ","Detail"
        WRITE-HOST "-------------------------------","------","-----","----------","------"
        If( $targetPolicy -eq '' )
            {
# Soemthing else  SETS InMaintenace
                process-policy $targetInstance "policy/instanceInMaintenance" "action/SetMaintenance" $BasicCreds #action.SetMaintenance $debug $whatIf 
                process-policy $targetInstance "policy/activeTransactionDuration" "#action/KillLongRunningSPID" $BasicCreds #action.KillLongRunningSPID $debug $whatIf 
                process-policy $targetInstance "policy/inFlightTransactionSize" "action/KillLargeActiveTransaction" $BasicCreds #action.KillLargeActiveTransaction $debug $whatIf 
                process-policy $targetInstance "policy/logSpaceUsed" "" $BasicCreds #'' $debug $whatIf
                process-policy $targetInstance "policy/noBackupIsRunning" "action/StopFullBackup" $BasicCreds #action.StopFullBackup $debug $whatIf 
                process-policy $targetInstance "policy/noDeprecationJobsEnabled" "action/DisableDeprecationJobs" $BasicCreds #action.DisableDeprecationJobs $debug $whatIf 
                process-policy $targetInstance "policy/noDeprecationJobsRunning" "action/StopDeprecationJobs" $BasicCreds #action.StopDeprecationJobs $debug $whatIf
# should this be last?                 
                process-policy $targetInstance "policy/noSPIDsInRollback" "" $BasicCreds #'' $debug $whatIf
                process-policy $targetInstance "policy/auditsDisabled" "action/StopAudits" $BasicCreds #act#ion.StopAudits $debug $whatIf 
                process-policy $targetInstance "policy/noRestoreIsRunning" "" $BasicCreds #'' $debug $whatIf

                # Standby Instances
                process-policy $targetInstance "policy/LogShippingPaused" "action/PauseLogShipping" $BasicCreds #action.PauseLogShipping $debug $whatIf 
                process-policy $targetInstance "policy/LogShippingActive" "action/EnableLogShipping" $BasicCreds #action.PauseLogShipping $debug $whatIf 

                # AsyncAPIScale Instances
                process-policy $targetInstance "policy/IsAsyncAPIScaleDBReadOnly" "action/MarkAsyncAPIScaleDBReadOnly" $BasicCreds #action.MarkAsyncAPIScaleDBReadOnly $debug $whatIf 
                process-policy $targetInstance "policy/IsAsyncAPIScaleDBMarkedDown" "action/MarkAsyncAPIScaleDBDown" $BasicCreds #action.MarkAsyncAPIScaleDBDown $debug $whatIf 
                 $actionIsAsyncAPIScaleQueueClear = @("action1","Action2")
                process-policy $targetInstance "policy/IsAsyncAPIScaleQueueClear" $actionIsAsyncAPIScaleQueueClear $BasicCreds #'' $debug $whatIf
            }
        ELSE
            {
                process-policy $targetInstance $targetPolicy $targetAction $BasicCreds
            }
    }
    ##


}


#check-preFailover

# remove-module "Untitled8"

# import-module .\Untitled8.psm1 -verbose