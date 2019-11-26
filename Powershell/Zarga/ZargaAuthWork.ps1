<### 
    Returns '98p98hap5r8gjp0385j4gp0835jg'

    This is passed into Zarga endpoints that require $AuthString
##>
function Get-AuthString {
        param([string]$Username,[string]$Password)
        $AuthString = "{0}:{1}" -f $Username,$Password
        $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
        return "$([Convert]::ToBase64String($AuthBytes))"
        }

$cred = Get-Credential

$AuthString = Get-AuthString $cred.UserName $cred.GetNetworkCredential().password

<### 
    Returns 'Basic 98p98hap5r8gjp0385j4gp0835jg'

   This is the required authentication used to access ZARGA endpoints
###>
function Get-BasicAuthCreds {
        param([string]$Username,[string]$Password)
        $AuthString = "{0}:{1}" -f $Username,$Password
        $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($AuthString)
        return "Basic $([Convert]::ToBase64String($AuthBytes))"
        }

$cred = Get-Credential

$BasicCreds = Get-BasicAuthCreds $cred.UserName $cred.GetNetworkCredential().password

<###
    Execute ZARGA endpoint

    Manual execution:
        http://ind2q00dbapi01.qa.local/swagger
        https://zarga.internal.marketingcloud.com/swagger
###>
