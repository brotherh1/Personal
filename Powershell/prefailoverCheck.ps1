PARAM(
    [string] $targetInstance ='IND2Q00DBA02.QA.LOCAL\I2',
    [string] $targetPolicy = '', #'policy.MSDTCactive',
    [string] $targetAction = '',
    [string] $takeAction = 0



)

Function process-policy( [string] $f_targetInstance, [string] $f_policy, [string] $f_action, [string] $f_takeAction )
{
    WRITE-HOST "[] Processing: $f_policy "
    $execSQL = "DECLARE @returnValue int;EXECUTE @returnValue = $f_policy; SELECT @returnValue as returnValue"
    IF( $f_debug -eq 1 )
        {
            WRITE-HOST `t`t"Execute SQL: $execSQL "
            #WRITE-HOST `t"invoke-sqlcmd -ServerInstance $f_targetInstance -Database UTILITY -Query `"$execSQL`" | select returnValue "
            $returnAction = 1
        }
    ELSE
        {
            $returnValue = invoke-sqlcmd -ServerInstance $f_targetInstance -Database UTILITY -Query $execSQL | select returnValue 
            #invoke-sqlcmd -ServerInstance $f_targetInstance -Database UTILITY -Query $execSQL | select returnValue 
            $returnAction = $returnValue.returnValue
            WRITE-HOST `t"Return Value: $returnAction "
        }
    #If $returnAction <> 0 and $f_action <> ''
    If( $returnAction -ne 0 -AND $f_action -ne '' )
        {
            WRITE-HOST `t"Issues reported attemping: $f_action "
            $execSQL = "DECLARE @returnValue int;EXECUTE @returnValue = $f_action; SELECT @returnValue as returnValue"
            IF( $f_takeAction -eq 0 )
                {
                    WRITE-HOST `t`t"Execute SQL: $execSQL "
                    #WRITE-HOST `t"invoke-sqlcmd -ServerInstance $f_targetInstance -Database UTILITY -Query `"$execSQL`" | select returnValue "
                    $returnAction = 1
                }
            ELSE
                {
                    $returnValue = invoke-sqlcmd -ServerInstance $f_targetInstance -Database UTILITY -Query $execSQL | select returnValue 
                    #invoke-sqlcmd -ServerInstance $f_targetInstance -Database UTILITY -Query $execSQL | select returnValue 
                    $returnAction = $returnValue.returnValue
                    WRITE-HOST `t"Return Value: $returnAction "
                }    

            IF( $returnAction -eq 0 )
                {
                    WRITE-HOST "[] Successful action: $f_Action "
                }
            ELSE
                {
                    WRITE-HOST "[] FAILED action: $f_Action "
                }
        }
    ELSEIF( $returnValue -ne 0 -AND $f_action -eq '' )
        {
            IF( $f_debug -eq 1 )
            {
                WRITE-HOST "[] FAILED policy: $f_policy with no define corrective action. "

            }
        }
    ELSEIF( $returnAction -eq 0 )
        {
            IF( $f_debug -eq 1 )
                {
                    WRITE-HOST "[] Successful policy evaluation: $f_policy "

                }  
        }
    WRITE-HOST " "
}

WRITE-HOST "[] Target Instance: $targetInstance "
WRITE-HOST "[] Instance Type: normal/restore/AG/...."
WRITE-HOST "[] Target Policy: $targetPolicy "
WRITE-HOST "[] Policy Action: $targetAction "
WRITE-HOST "[] Debug: $debug"
WRITE-HOST "[] WhatIF: $whatIf "
WRITE-HOST " "

If( $targetPolicy -eq '' )
    {

        process-policy $targetInstance policy.InstanceInMaintenance action.SetMaintenance $debug $whatIf 
        process-policy $targetInstance policy.ActiveTransactionDuration action.KillLongRunningSPID $debug $whatIf 
        process-policy $targetInstance policy.InFlightTransactionSize action.KillLargeActiveTransaction $debug $whatIf 
        process-policy $targetInstance policy.LogSpaceUsed '' $debug $whatIf
        process-policy $targetInstance policy.NoBackupIsRunning action.StopFullBackup $debug $whatIf 
        process-policy $targetInstance policy.NoDeprecationJobsEnabled action.DisableDeprecationJobs $debug $whatIf 
        process-policy $targetInstance policy.NoDeprecationJobsRunning action.StopDeprecationJobs $debug $whatIf 
        process-policy $targetInstance policy.NoSPIDsInRollback '' $debug $whatIf
        process-policy $targetInstance policy.AuditsDisabled action.StopAudits $debug $whatIf 
        process-policy $targetInstance policy.NoRestoreIsRunning '' $debug $whatIf

        # Standby Instances
        process-policy $targetInstance policy.LogShippingPaused action.PauseLogShipping $debug $whatIf 

        # AsyncAPIScale Instances
        process-policy $targetInstance policy.IsAsyncAPIScaleDBReadOnly action.MarkAsyncAPIScaleDBReadOnly $debug $whatIf 
        process-policy $targetInstance policy.IsAsyncAPIScaleDBMarkedDown action.MarkAsyncAPIScaleDBDown $debug $whatIf 
        process-policy $targetInstance policy.IsAsyncAPIScaleQueueClear '' $debug $whatIf
    }
ELSE
    {
        process-policy $targetInstance $targetPolicy $targetAction $debug $whatIf
    }