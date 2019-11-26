[CmdletBinding(SupportsShouldProcess=$true)]
Param
(
    [string] $sourceInstance = 'IND1P01C236I07\I07',
    [string] $targetInstance = 'IND1P01CB084I07.XT.LOCAL\I07,10001',
    [string] $sizeUnits = 'GB'
)

#Create Results DataTable
$ResultsTable = New-Object System.Data.DataTable 
    [void]$ResultsTable.Columns.Add("Severity")
    [void]$ResultsTable.Columns.Add("SourceInstance")
    [void]$resultsTable.Columns.Add("SourcePath")
    [void]$resultsTable.Columns.Add("SourceSize$($sizeUnits.ToUpper())")
    [void]$resultsTable.Columns.Add("TargetInstance")
    [void]$ResultsTable.Columns.Add("TargetPath")
    [void]$ResultsTable.Columns.Add("TargetSize$($sizeUnits.ToUpper())")

SWITCH ($sizeUnits)
{
    {$_ -eq "mb"} {$conversionUnit = 1}
    {$_ -eq "GB"} {$conversionUnit = 1024}
    {$_ -eq "tB"} {$conversionUnit = 1048576}
    DEFAULT {WRITE-HOST "Unknown Unit Type"; EXIT}
}

function compare-instance([string] $f_sourceInstance, [string] $f_targetInstance, [int] $f_conversionUnit)
{
    $sqlString = 'EXEC [Utility].[DBARpts].[DBARpts_mountPointSpace]'
    $sourceSpace = invoke-sqlcmd -serverInstance $f_sourceInstance -query $sqlString
    $targetSpace = invoke-sqlcmd -serverInstance $f_targetInstance -query $sqlString

    forEach( $sourcePath in $sourceSpace )
    {
        IF( $sourcePath.dPath -like '*\sql\*' )
        {
            WRITE-VERBOSE "Source Info: $($sourcePath.dPath) $([Math]::Truncate($sourcePath.TotalMB/$f_conversionUnit)) $($sourcePath.FreeMB)"
            WRITE-VERBOSE "Target INFO: $($targetSpace.dPath[$targetSpace.dPath.IndexOf($sourcePath.dPath)]) $([Math]::Truncate($targetSpace.TotalMB[$targetSpace.dPath.IndexOf($sourcePath.dPath)]/$f_conversionUnit)) $($targetSpace.FreeMB[$targetSpace.dPath.IndexOf($sourcePath.dPath)])"

            IF( $([Math]::Truncate(($sourcePath.TotalMB/$f_conversionUnit)+.01)) -gt $([Math]::Truncate(($targetSpace.TotalMB[$targetSpace.dPath.IndexOf($sourcePath.dPath)]/$f_conversionUnit)+.01)) )
                {
                    WRITE-VERBOSE "[ALERT] Drive undersized!!!! "
                    [void]$ResultsTable.Rows.Add("1", $sourceInstance, $sourcePath.dPath, [Math]::Truncate(($sourcePath.TotalMB/$f_conversionUnit)+.01), $targetInstance, $($targetSpace.dPath[$targetSpace.dPath.IndexOf($sourcePath.dPath)]), [Math]::Truncate(($targetSpace.TotalMB[$targetSpace.dPath.IndexOf($sourcePath.dPath)]/$f_conversionUnit)+.01))
                }
            ELSE
                {
                    [void]$ResultsTable.Rows.Add("2", $f_sourceInstance, $sourcePath.dPath, [Math]::Truncate($sourcePath.TotalMB/$f_conversionUnit), $f_targetInstance, $($targetSpace.dPath[$targetSpace.dPath.IndexOf($sourcePath.dPath)]), [Math]::Truncate($targetSpace.TotalMB[$targetSpace.dPath.IndexOf($sourcePath.dPath)]/$f_conversionUnit))
                }
        }
    }
}

## Use Inventory to interrogate everything

##Interrogate single isntance
compare-instance $sourceInstance $targetInstance $conversionUnit

## display results
IF ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent)
	{
        $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
        $ResultsTable | format-Table -AutoSize
    }
ELSE
    {
        $ResultsTable | WHERE {$_.Severity -eq 1} | format-Table -AutoSize
    }

 <#####################################################################
Purpose:  
     This script will interrogate instances using the stored procedure for space and display differences. 
History:  
     20191025 hbrotherton W-###### CREATED
     

     YYYYMMDD USERID W-000000000 This is what I changed.
Comments:
     .\compareLUN.ps1 -SourceInstance [FQDN\INST] -TargetInstance [FQDN\INST] -SizeUnits [MB/GB/TB] -VERBOSE
#######################################################################>