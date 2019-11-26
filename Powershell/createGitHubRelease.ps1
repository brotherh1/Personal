$GHRoot = "https://github.exacttarget.com/api/v3" # do not change
$Org = "dbauto" # do not change
$TempZipPath = "C:\Users\hbrotherton\myGit\ZIP"
$ReleaseFileDestination = "C:\Users\hbrotherton\myGit\releases"
$searchRepo = ''
$dryRun = 1

function Get-BasicAuthCreds {
    param([string]$Username,[string]$Password)
    $AuthString = "{0}:{1}" -f $Username,$Password
    $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
    return [Convert]::ToBase64String($AuthBytes)
}

function New-Repo 
{
    $Repo = "" | select Name, Status, Ahead, Behind
    $Repo | Add-Member -MemberType ScriptProperty -Name Branches -Value {
        Invoke-RestMethod -Uri "$GHRoot/repos/$($this.name)/branches?per_page=200" -Headers @{"Authorization"="Basic $BasicCreds"} #| %{($_ | ?{$_.name -like "release*"})}
        } -PassThru |
    Add-Member -MemberType ScriptProperty -Name Releases -Value {
        $this.Branches | %{($_ | ?{$_.Name -match "release/\d+."})}
        } -PassThru |
    Add-Member -MemberType ScriptProperty -Name MostRecentRelease -Value {
        if($this.releases.count -eq 0)
        {"master"}
        else
        {
            "release/$($this.Releases | %{[System.Version]$_.Name.Replace(`"release/`", `"`")} | sort -Descending | select -first 1)"#  sort -Property name -Descending | Select -first 1).Name
        }
        
        } -PassThru |
    Add-Member -MemberType ScriptProperty -Name MostRecentCommit -Value {
        ($this.branches | ?{$_.name -eq "develop"}).commit.sha
        
        } -PassThru |
    Add-Member -MemberType ScriptProperty -Name NextRelease -value {
        if($this.MostRecentRelease -eq 'master'){[System.Version]"1.0.0"}
        else
        {
            $latest = [System.Version]$this.MostRecentRelease.Replace("release/", "")

            $newVersion = New-Object -TypeName System.Version -ArgumentList $latest.Major, ($latest.Minor+1), 0
            $newVersion;
        }
    } -PassThru |
    Add-Member -MemberType ScriptMethod -Name CreateReleaseBranch -Value {
        $uri = "$GHRoot/repos/$($this.name)/git/refs"
        Invoke-RestMethod -Method Post -Uri $uri -Headers @{"Authorization"="Basic $BasicCreds"} -Body "{`"ref`": `"refs/heads/release/$($this.NextRelease.ToString())`",`"sha`": `"$($this.MostRecentCommit)`"}"
        
        } -PassThru

}

$BasicCreds = Get-BasicAuthCreds -Username "hbrotherton" -Password "cbaa10d037e8ea421dc2a62f2f7f4cbbe24d0d3b"

$Repos = @();

IF( $searchRepo -eq '' )
    {
        $RawRepos = Invoke-RestMethod -Uri "$GHRoot/orgs/$Org/repos" -Headers @{"Authorization"="Basic $BasicCreds"}
    }
ELSE
    {
        $rawRepos = Invoke-RestMethod -Uri "$GHRoot/orgs/$Org/repos" -Headers @{"Authorization"="Basic $BasicCreds"} | %{($_ | ?{$_.name -eq "$searchRepo"})}
    }

foreach ($RawRepo in $RawRepos)
{
    IF( $dryRun -eq 0 )
        {
            $Repo = New-Repo;
            $Repo.Name = $RawRepo.full_name;
        }
    #$Repo.Releases = (Invoke-RestMethod -Uri "$GHRoot/repos/$($RawRepo.full_name)/branches" -Headers @{"Authorization"="Basic $BasicCreds"} | %{($_ | ?{$_.name -like "release*"})} )
    $RawCompare = Invoke-RestMethod -Uri "$GHRoot/repos/$($RawRepo.full_name)/compare/master...develop" -Headers @{"Authorization"="Basic $BasicCreds"}
    IF( $dryRun -eq 0 )
        {
            $Repo.Status = $RawCompare.status;
            $Repo.Ahead = $RawCompare.ahead_by;
            $Repo.Behind = $RawCompare.behind_by;
    
            if($Repo.Status -ne 'identical' -and $Repo.Status -ne 'behind' )#-and ($Repo.Name -eq 'dbauto/UtilityDB'))
            {
                #$Repo
                $Repo.CreateReleaseBranch();
        
                #$RawRepo

                $ReleaseCompare = Invoke-RestMethod -Uri "$GHRoot/repos/$($RawRepo.full_name)/compare/master...$($Repo.MostRecentRelease)" -Headers @{"Authorization"="Basic $BasicCreds"}
        
                #Check/create repo directory in the temp zip path
                $TempRepoZipPath = "$($TempZipPath)\$($Repo.name.replace("/", "_"))"
            
                if(!(Test-Path -Path $TempRepoZipPath))
                {
                    New-Item -Path $TempRepoZipPath -ItemType Directory    
                }

                foreach($file in $ReleaseCompare.files)
                {
            
                   # WRITE-VERBOSE $file


                    if($file.status -ne 'removed')
                    {
                
                        #Build out subfolders
                        if($file.filename -like "*/*")
                        {
                            $TempFileZipSubfolders = $file.filename.split("/");
                            $TempFileZipSubfolderPath = "$($TempRepoZipPath)"
                            foreach($folder in $TempFileZipSubfolders[0..($TempFileZipSubfolders.length -2)])
                            {
                                $TempFileZipSubfolderPath = "$TempFileZipSubfolderPath\$($folder)"
                                if(!(Test-Path -Path $TempFileZipSubfolderPath))
                                {
                                    New-Item -ItemType Directory -Path $TempFileZipSubfolderPath
                                }
                            }
                        }

                        $TempFileZipPath = "$($TempRepoZipPath)\$($file.filename)"

                        #download the files to the new repo directory
                        $Rawfile = Invoke-RestMethod -Uri "$GHRoot/repos/$($repo.name)/git/blobs/$($file.sha)" -Headers @{"Authorization"="Basic $BasicCreds"}
                        [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($RawFile.Content)) | out-file $TempFileZipPath -Encoding utf8 -force

                    }
                }

                #Zip them up
                Add-Type -AssemblyName "system.io.compression.filesystem"
                $RepoReleaseDestination = "$ReleaseFileDestination\$($Repo.name.replace(`"/`", `"_`"))_$($Repo.MostRecentRelease.Replace(`"release/`", `"`")).zip"
                if(Test-Path $RepoReleaseDestination){Remove-Item $RepoReleaseDestination}
                #check/create version directory in the target version path
                if(!(Test-Path "$ReleaseFileDestination"))
                {
                    New-Item -ItemType Directory -Path "$ReleaseFileDestination"
                }
                [io.compression.zipfile]::CreateFromDirectory($TempRepoZipPath, $RepoReleaseDestination)

                #Delete temp zip path
               # Remove-Item -Path $TempRepoZipPath -recurse
            }
        }
    ELSE
        {
             if($RawCompare.Status -ne 'identical' -and $RawCompare.Status -ne 'behind' )
                {
                    $RawRepo.name
                    $rawCompare.files.filename 
                }
        }

    $Repos += $Repo;
}
#/repos/:owner/:repo/compare/user1:branchname...user2:branchname
#$Compares = @()
#$Repos | %{Invoke-RestMethod -Uri "$GHRoot/repos/$($_.full_name)/compare/master...develop" -Headers @{"Authorization"="Basic $BasicCreds"} | %{$Compares += $_}}

$repos | ?{$_.Status -ne 'identical' -and $_.Status -ne 'behind'}

#Invoke-RestMethod -Method GET -Uri "https://github.exacttarget.com/api/v3/repos/dbauto/master/refs" -Headers @{"Authorization"="Basic $BasicCreds"} -Body "{`"ref`": `"refs/heads/release/$($this.NextRelease)`",`"sha`": `"$($this.MostRecentCommit)`"}"
#invoke-webrequest -Method Get - https://github.exacttarget.com/api/v3/orgs/dbauto/repos -u kneier:a935c77fec6214ff6118edacd8b17b4813020615