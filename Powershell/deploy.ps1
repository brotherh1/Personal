<#
	.\deploy.ps1 -targetDB "snabackupDB" -sqlSource "C:\SQL\snabackupDB-master" -targetHost "GARBAGEMA03\I03,10001"
#>

PARAM(
		[Parameter(Position=0)]
		[Alias("package")]
		[string]$targetDB="snabackupDB",
		[Parameter(Position=1)]
		[Alias("source")]
		[string]$sqlSource="C:\SQL\snabackupDB-master",
		[Parameter(Position=2)]
		[Alias("target")]
		[string]$targetHost="GARBAGEMA03\I03",
		[switch]$force
	)
$ErrorActionPreference="Continue";


function processfolder ( [string] $f_sqlSourcePath )
{
    get-childitem -recurse -path $f_sqlSourcePath -filter $filter | % {
        $file = $_
        $total ++
        # etc ...
    }
    write-output "Source Location: $f_sqlSourcePath"
    write-output "Files to process: $total"
    Write-Output "Target DB: $targetDB"
    Write-Output "Target Host: $targetHost"
    Write-Output " "

    get-childitem -recurse -path $f_sqlSourcePath -filter $filter | % {
        $file = $_
	    $currentFile = $file.name
        Write-Output $currentFile
	    $outputFile = $_.BaseName+'.txt'
	    #Write-Output $outputFile
	    $count++
	    Invoke-Sqlcmd -ServerInstance $targetHost -Database $targetDB -InputFile $f_sqlSourcePath$currentFile | Out-File -filePath $f_sqlSourcePath$outputFile
    }
}
	
#clear

$filter = '*.sql'
$count = 0
$total =0

processFolder "$sqlSource\Role\"	
processFolder "$sqlSource\Schema\"
processFolder "$sqlSource\Table\"
processFolder "$sqlSource\View\"
processFolder "$sqlSource\Type\"
processFolder "$sqlSource\Synonym\"
processFolder "$sqlSource\UserDefinedFunction\"
processFolder "$sqlSource\StoredProcedure\"
processFolder "$sqlSource\Init\"
processFolder "$sqlSource\AgentJobs\"