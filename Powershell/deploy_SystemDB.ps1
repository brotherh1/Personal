<#
	.\deploy -targetDB "OrderManager" -sqlSource "\\inms149\DEPLOY\SQL2008_PROD\OM\" -targetHost "web1.sql.herffjones.hj-int,1539"

	\\inms149\DEPLOY\deploy.ps1 -targetDB "Order_Manager" -sqlSource "\\inms149\DEPLOY\SQL2008_PROD\OM\" -targetHost "web1.sql.herffjones.hj-int,1539"
#>

PARAM(
		[Parameter(Position=0)]
		[Alias("package")]
		[string]$targetDB="SQLMonitor",

		[Parameter(Position=1)]
		[Alias("source")]
		[string]$sqlSource="C:\SQL\"+ $targetDB,
	#	[string]$sqlSource="C:\SQL\SQLMonitor-master\Table\",
    #   [string]$sqlSource="C:\SQL\SQLMonitor-master\View\",
    #   [string]$sqlSource="C:\SQL\SQLMonitor-master\Synonym\",
    #   [string]$sqlSource="C:\SQL\SQLMonitor-master\UserDefinedFunction\",
    #   [string]$sqlSource="C:\SQL\SQLMonitor-master\StoredProcedure\",
		
		[Parameter(Position=2)]
		[Alias("target")]
		[string]$targetHost="localhost\I1",

		[switch]$force
	)
$ErrorActionPreference="Continue";

#[void][System.Reflection.Assembly]::LoadWithPartialName("System.Xml.XmlDocument");
#[void][System.Reflection.Assembly]::LoadWithPartialName("System.IO");
#Add-PSSnapin Microsoft.Exchange.Management.Powershell.Admin -erroraction silentlyContinue
function sendmail
{
     Write-Output "Sending Email"
	 
	$smtpServer = "mail.herffjones.hj-int"
	$att = new-object Net.Mail.Attachment("$sqlSource$outputFile")
	$msg = new-object Net.Mail.MailMessage
	$smtp = new-object Net.Mail.SmtpClient($smtpServer)
	$msg.From = "SQL_DEPLOY@HERFFJONES.com"
	$msg.To.Add("agporosoff@herffjones.com.com")
	$msg.CC.Add("hkbrotherton@herffjones.com")
	$msg.Subject = "$targetDB DEPLOY output for script $currentFile $count/$total"
	$msg.Body = "Attached is the output from SQL deploy script $currentFile"
	$msg.Attachments.Add($att)
	$smtp.Send($msg)
	$att.Dispose()
}	


function processfolder ( [string] $f_sqlSourcePath )
{
    $total = 0

    get-childitem -recurse -path $f_sqlSourcePath -filter $filter | % {
        $file = $_
        $total ++
        # etc ...
    }
    Write-Output " "
    write-output "[] Source Location: $f_sqlSourcePath"
    write-output "[] Files to process: $total"
    Write-Output "[] Target DB: $targetDB"
    Write-Output "[] Target Host: $targetHost"
    IF( $total -gt 0 )
        {
            get-childitem -recurse -path $f_sqlSourcePath -filter $filter | % {
                $file = $_
	            $currentFile = $file.name
                Write-Output `t"PROCESSING: $currentFile"
	            $outputFile = $f_sqlSourcePath +"\output\"+ $_.BaseName+'.txt'
	            #Write-Output $outputFile
	            $count++

                TRY
                {
	                Invoke-Sqlcmd -ServerInstance $targetHost -Database $targetDB -InputFile $f_sqlSourcePath$currentFile -Verbose | Out-File -filePath $outputFile #$f_sqlSourcePath\output\$outputFile
	                Invoke-Sqlcmd -ServerInstance $targetHost -Database $targetDB -Query "select getdate()"  | Out-File -filePath $outputFile -append #$f_sqlSourcePath\output\$outputFile -append
                }
                CATCH
                {
                        ##sendMail
                }
        }
    }
}
	
#clear

$filter = '*.sql'
$count = 0
$total =0

#$createDB_SQL = $sqlSource +"\createDB.sql"
#Invoke-Sqlcmd -ServerInstance $targetHost -Database $targetDB -InputFile $createDB_SQL -QueryTimeout 0
	
processFolder "$sqlSource\Schema\"
processFolder "$sqlSource\PartitionFunction\"
processFolder "$sqlSource\PartitionScheme\"
#processFolder "$sqlSource\UserDefinedFunction\"
#processFolder "$sqlSource\StoredProcedure\"
processFolder "$sqlSource\Table\"
processFolder "$sqlSource\View\"
processFolder "$sqlSource\Synonym\"
## moved to the top to create dependencies to reduce red output  :)
processFolder "$sqlSource\UserDefinedFunction\"
processFolder "$sqlSource\StoredProcedure\"