function Get-BasicAuthCreds {
    param([string]$Username,[string]$Password)
    $AuthString = "{0}:{1}" -f $Username,$Password
    $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
    return [Convert]::ToBase64String($AuthBytes)
}


Function syncGroup-gitHubFile
{
[CmdletBinding()]
PAram ( 
                             
        [string] $GHRoot = "https://github.exacttarget.com/api/v3", # do not change
        [string] $Org = "dbauto", # do not change
        [string] $searchRepo = 'UtilityDB',
        [string] $searchFolder = 'StandardJobs',
        [string] $searchFile = 'StandardJobScript_UltimateEdition.sql',
        [string] $searchBranch ='', ## If null will go to master
        [string] $targetInstance = '',
        [string] $user, [String] $token, <# not password - github Toke #> 
        [string] $dryRun = 1
     )
    $selectSQL = "SELECT [SQLInstallation]  FROM [DBA].[dbo].[ExactTargetSQLInstallations]  where serverType = '$($targetInstance)'"
    $instanceList = @(Invoke-Sqlcmd -ServerInstance 'XTINP1DBA01\DBADMIN' -Database 'DBA' -DisableVariables -ErrorAction Stop -Query $selectSQL | select -exp SQLinstallation )

    ForEach( $instance in $instanceList )
    {

        WRITE-VERBOSE "[] Processing $instance "
        WRITE-VERBOSE "`t deploy-gitHubFile '$GHRoot' '$Org' '$searchRepo' '$searchFolder' '$searchFile' '$searchBranch' '$instance'  '$user' '$token' -dryRun $dryRun -verbose"
        deploy-gitHubFile $GHRoot $Org $searchRepo $searchFolder $searchFile $searchBranch $instance $user $token -dryRun $dryRun -verbose
    }
}

function deploy-gitHubFile 
{
[CmdletBinding()]
PAram ( 
                             
        [string] $GHRoot = "https://github.exacttarget.com/api/v3", # do not change
        [string] $Org = "dbauto", # do not change
        [string] $searchRepo = 'UtilityDB',
        [string] $searchFolder = 'StandardJobs',
        [string] $searchFile = 'StandardJobScript_UltimateEdition.sql',
        [string] $searchBranch ='', ## If null will go to master
        [string] $targetInstance = '',
        [string] $user, [String] $token, <# not password - github Toke #> 
        [string] $dryRun = 1
    )
#{

    $BasicCreds = Get-BasicAuthCreds -username $user -password $token

    #$targetInstance = $targetInstance -replace '#',".$env:USERDNSDOMAIN\"
   
    IF( $searchRepo -eq '' )
        {
            $RawRepos = Invoke-RestMethod -Uri "$GHRoot/orgs/$Org/repos" -Headers @{"Authorization"="Basic $BasicCreds"}
        }
    ELSE
        {
            WRITE-VERBOSE "Invoke-RestMethod -Uri `"$GHRoot/orgs/$Org/repos`" -Headers @{`"Authorization`"=`"Basic $BasicCreds`"} | %{($_ | ?{$_.name -eq `"$searchRepo`"})}"
            $rawRepos = Invoke-RestMethod -Uri "$GHRoot/orgs/$Org/repos" -Headers @{"Authorization"="Basic $BasicCreds"} | %{($_ | ?{$_.name -eq "$searchRepo"})}
        }

    IF( $dryRun -eq 1 )
        {
            #cls
            WRITE-HOST "[DryRun] GHroot: $GHRoot "#https://github.exacttarget.com/api/v3", # do not change
            WRITE-HOST "[DryRun] GHorg: $Org  "#dbauto", # do not change
            WRITE-HOST "[DryRun] GHrepo: $searchRepo "#= 'UtilityDB',
            WRITE-HOST "[DryRun] GHpath:$searchFolder"# = 'StandardJobs',
            WRITE-HOST "[DryRun] GHfile: $searchFile "#= 'StandardJobScript_UltimateEdition.sql',
            WRITE-HOST "[DryRun] GHrepo: $searchBranch "#='', ## If null will go to master
            WRITE-HOST "[DryRun] targetInstance: $targetInstance "#= '',
            WRITE-HOST "[DryRun] DryRun: $dryRun "#= 1
           

            #WRITE-HOST "Invoke-Sqlcmd -ServerInstance $targetInstance -Database UTILITY -DisableVariables -ErrorAction Stop -Query <SOMETHING>"
        }

    foreach ($RawRepo in $RawRepos) ## left it like this incase we allow array input later.  Seems like a bad idea though......
        {
            IF( $searchBranch -eq '' ) #pull from master
                {
                    WRITE-VERBOSE "Invoke-RestMethod -Uri '$GHRoot/repos/$Org/$searchRepo/contents/$searchFolder/$searchFile'"
                    $rawFile = Invoke-RestMethod -Uri "$GHRoot/repos/$Org/$searchRepo/contents/$searchFolder/$searchFile" -Headers @{"Authorization"="Basic $BasicCreds"}
                }
            ELSE
                {
                    WRITE-VERBOSE "Invoke-RestMethod -Uri `"$GHRoot/repos/$Org/$searchRepo/contents/$searchFolder/$searchFile`?ref=$searchBranch`" -Headers @{`"Authorization`"=`"Basic $BasicCreds`"}"
                    $rawFile = Invoke-RestMethod -Uri "$GHRoot/repos/$Org/$searchRepo/contents/$searchFolder/$searchFile`?ref=$searchBranch" -Headers @{"Authorization"="Basic $BasicCreds"}
                }
    
            ## Need to be able to determine the file by extension and only convert .TXT .SQL ....
            $cleanFile = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($RawFile.Content))
            #$cleanFile

        ## Need to be able to determine the file by extension and run .SQL                
        ## Need to be able to determine the file by extension and copy .TXT .VBS
            If( $searchFile -like '*.ps1' )
                {
                    WRITE-VERBOSE "Copying $searchFile to new host $targetInstance"
                    $selectSQL = "SELECT  isNull(LEFT(convert(varchar(100), serverproperty('InstanceDefaultDataPath')), 1) ,'E') + '$\SQL\' + convert(varchar(5), serverproperty('Instancename')) + '\UTILITY\DBAScripts\' as destPath"
                    WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $targetInstance -Database UTILITY -DisableVariables -ErrorAction Stop -Query $selectSQL"
                    [string] $destPath = Invoke-Sqlcmd -ServerInstance $targetInstance -Database UTILITY -DisableVariables -ErrorAction Stop -Query $selectSQL | select -exp destPath
                    WRITE-VERBOSE "`t $searchFile | out-file \\$($targetInstance.substring(0,$targetInstance.IndexOf('\')))\$($destPath)$($searchFile)"
                    $cleanFile | out-file \\$($targetInstance.substring(0,$targetInstance.IndexOf('\')))\$($destPath)$($searchFile)
                }
            ELSEIF( $searchFile -like '*.txt')
                {
                    WRITE-VERBOSE "Is this supposed to be a Declaritive Data file ?"
                }
            ELSE
                {
                    WRITE-VERBOSE "Invoke-Sqlcmd -ServerInstance $targetInstance -Database UTILITY -DisableVariables -ErrorAction Stop -Query $cleanFile"
                    IF( $dryRun -eq 0 )
                    {       
                            Invoke-Sqlcmd -ServerInstance $targetInstance -Database UTILITY -DisableVariables -ErrorAction Stop -Query  

                    }
                }

        }

}

<#####################################################################
Purpose:  
     This will take a single file convert it to the appropriate type and deploy based on file exstention. 
History:  
     20180612 hbrotherton W-####### Created
     YYYYMMDD USERID W-000000000 This is what I changed.
Comments:
     Currently this only works for extention .sql  
     
     The server name contains "#" be cuase that is how ZARGA processes 
     instance names and that is what will be supplied from ZARGA
Quip Documentaion:
     
## To be commented out when in ZARGA 
## NORMAL RUN
# deploy-gitHubFile 'https://github.exacttarget.com/api/v3' 'dbauto' 'UtilityDB' 'StandardJobs' 'StandardJobScript_UltimateEdition.sql' 'master' 'ATL1Q51CB016I02#I02' 'GIT HUB USER' 'GIT HUB TOKEN' 0

## VERBOSE RUN
# deploy-gitHubFile 'https://github.exacttarget.com/api/v3' 'dbauto' 'UtilityDB' 'StandardJobs' 'StandardJobScript_UltimateEdition.sql' 'master' 'ATL1Q51CB016I02#I02' 'GIT HUB USER' 'GIT HUB TOKEN' 0 -verbose
# deploy-gitHubFile 'https://github.exacttarget.com/api/v3' 'dbauto' 'UtilityDB' 'StandardJobs' 'StandardJobScript_UltimateEdition.sql' 'develop' 'ATL1Q51CB016I02#I02' 'GIT HUB USER' 'GIT HUB TOKEN' 0 -verbose
# deploy-gitHubFile 'https://github.exacttarget.com/api/v3' 'dbauto' 'UtilityDB' 'StandardJobs' 'StandardJobScript_UltimateEdition.sql' 'release/1.8.0' 'ATL1Q51CB016I02#I02' 'GIT HUB USER' 'GIT HUB TOKEN' 0 -verbose

##dryRun
# deploy-gitHubFile 'https://github.exacttarget.com/api/v3' 'dbauto' 'UtilityDB' 'StandardJobs' 'StandardJobScript_UltimateEdition.sql' 'master' 'ATL1Q51CB016I02#I02'  'brotherton' 'cbaa10d037e8ea421dc2a62f2f7f4cbbe24d0d3b' -dryRun 1 -verbose

## VERBOSE DRY RUN
# deploy-gitHubFile 'https://github.exacttarget.com/api/v3' 'dbauto' 'SnapbackupDB' 'powershell' 'verifyCopySource.ps1' 'Harold-Work' 'ATL1Q51CB016I02#I02' 'brotherton' 'cbaa10d037e8ea421dc2a62f2f7f4cbbe24d0d3b' -dryRun 1 -verbose

deploy-gitHubFile 'https://github.exacttarget.com/api/v3' 'dbauto' 'SnapBackupDB' 'powershell' 'verifyCopySource.ps1' 'hbrotherton-work' 'ATL1P04C01MA03\I03'  'brotherton' 'cbaa10d037e8ea421dc2a62f2f7f4cbbe24d0d3b' -dryRun 1 -verbose
deploy-gitHubFile 'https://github.exacttarget.com/api/v3' 'dbauto' 'SnapBackupDB' 'powershell' 'verifyCopySource.ps1' 'hbrotherton-work' 'SnapShot'  'brotherton' 'cbaa10d037e8ea421dc2a62f2f7f4cbbe24d0d3b' -dryRun 1 -verbose


#######################################################################>
