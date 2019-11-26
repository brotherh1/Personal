### Invoke-RestMethod -Method GET -Uri "https://github.exacttarget.com/api/v3/repos/dbauto/master/refs" -Headers @{"Authorization"="Basic $BasicCreds"} -Body "{`"ref`": `"refs/heads/release/$($this.NextRelease)`",`"sha`": `"$($this.MostRecentCommit)`"}"


### https://developer.github.com/enterprise/2.10/v3/repos/#list-tags
### https://developer.github.com/enterprise/2.10/v3/repos/releases/

$GHRoot = "https://github.exacttarget.com/api/v3" # do not change
$Org = "dbauto" # do not change

function Get-BasicAuthCreds {
    param([string]$Username,[string]$Password)
    $AuthString = "{0}:{1}" -f $Username,$Password
    $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
    return [Convert]::ToBase64String($AuthBytes)
}

$BasicCreds = Get-BasicAuthCreds -Username "hbrotherton" -Password "cbaa10d037e8ea421dc2a62f2f7f4cbbe24d0d3b"

## POST /repos/:owner/:repo/releases
## POST /repos/dbauto/sharedScripts/releases
$body = "{
  `"tag_name`": `"v1.6.0`",
  `"target_commitish`": `"release/1.6.0`",
  `"name`": `"SharedScripts 1.6.0`",
  `"body`": `"Description of the release`",
  `"draft`": true,
  `"prerelease`": false
}"

$uri = "$GHRoot/repos/$org/sharedScripts/releases"
$newReleaseTag = Invoke-RestMethod -Method Post -Uri $uri -Headers @{"Authorization"="Basic $BasicCreds"} -Body $body

## Display $newReleaseTag info ?
$newReleaseTag

##Not working on uploading ZIP file - Release creation containst link to 
### Invoke-RestMethod -Method POST https://<upload_url>/repos/:owner/:repo/releases/:release_id/assets?name=foo.zip
## $uploadURI = $newReleaseTag.upload_URL
# Invoke-RestMethod -Method POST -Uri "https://github.exacttarget.com/api/uploads/repos/dbauto/sharedscripts/releases/7980/assets?name=dbauto_sharedscripts_1.6.0.zip&label=release.zip" -Headers @{"Authorization: Basic $BasicCreds", "Content-Type: application/zip"}


## DELETE /repos/:owner/:repo/releases/:release_id
## DELETE /repos/dbauto/SharedScripts/releases/7977

## Invoke-RestMethod -Method DELETE -Uri $uri/7978 -Headers @{"Authorization"="Basic $BasicCreds"} 