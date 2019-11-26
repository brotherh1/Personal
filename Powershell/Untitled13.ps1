CLS
$filecount = 10 # This would be retrieved automatically from a get-childitem

$server = "Localhost\fake"
$failureCounter = 1
$divisionCount = 0
$process = "Started"
WHILE( $process -ne "Succesful" -AND $failureCounter -lt $filecount ) # AND attempts less thatn file count
{
    $process = "Started"
    WRITE-HOST "[$process] Attempt   $failureCounter "


   WHILE( $divisionCount -lt $filecount ) # process files
    {
        
        try
        {
            IF ($divisionCount -eq 5 -and $failureCounter -lt 8 ){$divider = 0}ELSE{ $divider = $divisionCount}
            WRITE-HOST `t"Attempting 100/$divider"
            $nothing = 100/$divider
            WRITE-HOST `t"this is nothing : $nothing "
            #Invoke-Sqlcmd -Query "SELECT DB_NAME() as [Database]" -Server $server -ErrorAction Stop
            IF($process -ne "FAILED"){ $Process = "Succesful" }

        }
        catch
        {
            WRITE-Host "Failures: $failureCounter - FAilure to divide stupid numbers 100/$divider  " 
Write-Host($error)
            $process = "FAILED"
           
        }
         WRITE-HOST "Current Process: $process"
        $divisionCount++
    }

    WRITE-HOST "[] reevaluate "
    $divisionCount = 1
    $failureCounter ++
   
}

WRITE-HOST "PRocess was $process"