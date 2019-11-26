                                                                <#
    Author: Jane Palmer
    Description: Will pull log space utilization and full backup progress from a backup and will e-mail the results
#>

PARAM
(
    [Parameter(Mandatory=$true)] [string] $targetDatabase = '',
    [Parameter(Mandatory=$true)] [string] $targetInstance = '',
    [string] $emailRecipients = 'h6z3o0x3f1l8b1j1@sf-mc.slack.com' # channel? 'm0t9g2a5g5u3j3z1@sf-mc.slack.com '

)

# Add SQL Module
Add-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100

function Get-BackupProgress
{
    $backupProgressSQL = "SELECT getdate() as [Current Time],
r.session_id as SPID,
CONVERT(NUMERIC(6,2),r.percent_complete)
AS [Percent Complete],
CONVERT(VARCHAR(20),DATEADD(ms,r.estimated_completion_time,GetDate()),20) AS [ETA Completion Time],
CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0) AS [ETA Min],
CONVERT(NUMERIC(10,2),r.estimated_completion_time/1000.0/60.0/60.0) AS [ETA Hours]
FROM sys.dm_exec_requests r  
WHERE 
command IN ('BACKUP DATABASE') AND DB_Name(database_id) like N'$targetDatabase%'
GO"
    
    <#SELECT DB_NAME (e.database_id) AS DatabaseName,
e.encryption_state,
e.percent_complete
FROM sys.dm_database_encryption_keys AS e
LEFT JOIN master.sys.asymmetric_keys AS c
ON e.encryptor_thumbprint = c.thumbprint
WHERE DB_NAME (e.database_id) Like N'$targetDatabase%'
AND e.encryption_state = 2;";
#>
    $backupProgressResult = @(Invoke-Sqlcmd -ServerInstance $targetInstance -Database "master" -Query $backupProgressSQL);
    
    return $backupProgressResult;

}

function Get-LogSpaceUtilization
{
    $logSpaceUtilizationSQL = "DBCC SQLPERF(LOGSPACE);";

    $logSpaceUtilization = @(Invoke-Sqlcmd -ServerInstance $targetInstance -Database "master" -Query 
$logSpaceUtilizationSQL);
    
    return $logSpaceUtilization;
}

function Send-StatusEmail
{
    param (
        $backupProgress,
        $logSpaceUsage
    )

    # Start the e-mail body
    $emailBody = "Backup of $targetDatabase is in progress.`n`nSource Server: $targetInstance`n`n";

    # Prepare the section for Backup Status
    $databaseBackupProgress = "";
    Foreach ($backupProgressResult in $backupProgress)
    {
    $databaseBackupProgress = "`n
    SPID: "+$BackupProgressResult[1]+", `n
    Percent Complete: "+$BackupProgressResult[2]+"%, `n
    ETA Hours: "+$BackupProgressResult[5]+"hours,`n
    ETA Mins: "+$backupProgressResult[4]+"minutes `n
    ";
    }

    $backupMessage = "Backup Progress: $databaseBackupProgress";

    # Prepare the section for the Log Space utilization
    # First, grab the database's utilization
    $databasesLogSpaceUtilization = "";

    foreach ($logspaceUtilization in $logSpaceUsage)
    {
        if ($logspaceUtilization[0] -eq $targetDatabase)
        {
            $databasesLogSpaceUtilization = $logspaceUtilization[2];
        }
    }

    $logSpaceMessage = "Log Space Utilization: $databasesLogSpaceUtilization%";
    
    $emailBody += $backupMessage;
    $emailBody += $logSpaceMessage;
    $targetInstanceFrom = $targetInstance -replace ".{4}$"  #drop last 4 characters ie \I0n

    # Send the e-mail
    $smtpServer = "mailrelay.XT.local"
    $smtpFrom = "$TargetInstanceFrom@XT.LOCAL"
    $smtpTo = $emailRecipients;
    $messageSubject = "Backup of $targetDatabase in progress"
 
    $message = New-Object System.Net.Mail.MailMessage $smtpFrom,$smtpTo;
    $message.Subject = $messageSubject;
    $message.IsBodyHTML = $false;

    $message.Body = $emailBody;
 
    $smtp = New-Object Net.Mail.SmtpClient($smtpServer)
    $smtp.Send($message)
}

function Send-LastEmail
{
    param (
        $backupProgress,
        $logSpaceUsage
    )

    # Start the e-mail body
    $emailBody = "Backup of $targetDatabase has completed.`n`nSource Server: $targetInstance`n`n";
    $emailBody += "Disabling SQL Agent Job: HADR - MonitorBackup_$($targetDatabase.replace('ExactTarget','ET'))"

    $backupMessage = "Backup Completed.";

    $targetInstanceFrom = $targetInstance -replace ".{4}$"  #drop last 4 characters ie \I0n

    # Send the e-mail
    $smtpServer = "mailrelay.XT.local"
    $smtpFrom = "$TargetInstanceFrom@XT.LOCAL"
    $smtpTo = $emailRecipients;
    $messageSubject = "Backup of $targetDatabase has finished"
 
    $message = New-Object System.Net.Mail.MailMessage $smtpFrom,$smtpTo;
    $message.Subject = $messageSubject;
    $message.IsBodyHTML = $false;

    $message.Body = $emailBody;
 
    $smtp = New-Object Net.Mail.SmtpClient($smtpServer)
    $smtp.Send($message)
}

function Test-BackupProgress
{
    # Check the full backup progress
    $backupProgress = @(Get-BackupProgress);

    # If there is no full backup running, end the script
    if ($backupProgress.Count -eq 0)
    {
        Write-Host "No full backup is running!";
        Send-LastEmail

        ## CLEANUP ##
        
        #disable monitor job?
        $disableCMD = "EXEC MSDB..sp_update_Job @job_name = 'HADR - MonitorBackup_$($targetDatabase.replace('ExactTarget','ET'))', @enabled=0"
        Invoke-Sqlcmd -ServerInstance $targetInstance -Database "MSDB" -Query $disableCMD
        
        #confirm one time job is removed/disabled ?
   
      return;
    }
    
    # Get the Log Space utilization
    $logSpaceUsage = @(Get-LogSpaceUtilization);


    # Send the status e-mail
    Send-StatusEmail -backupProgress $backupProgress -logSpaceUsage $logSpaceUsage;
    
}

Test-BackupProgress;