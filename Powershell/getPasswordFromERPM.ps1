 Function Get-ErpmSharedPassword
        {
            [CmdletBinding()]
            param(  [Parameter(Mandatory=$true)] [string]$AccountName,
                    [Parameter(Mandatory=$true)] [string]$SystemName,
                    [Parameter(Mandatory=$true)] [string]$PasswordList,
                    [Parameter(Mandatory=$true)] [ValidateSet("QA","CT")] [string]$Environment,
                    [Parameter(Mandatory=$true)] [PSCredential]$Credential,
                    [Parameter(Mandatory=$false)] [string]$Comment="Get-ErpmSharedPassword Database Automated Checkout"
                 )

            # Get ERPM Server
            switch ($Environment) {
                "QA"{$Server = "erpm.qa.local"}
                "CT"{$Server = "erpm.xt.local"}
               # "XT"{$Server = "erpm.xt.local"}  #do not use this 
                default {$Server = $null}
            }

            if ($Server -eq $null) {
                # Fail and semi-insult the user.
                Write-Error "Somehow the value for the Server is null which is odd considering it's build off of a MANDATORY parameter.  Script might be broken, please consult with the SFMC-DBAAutomation team for assistance."
            }
            else
            {
                # Static Variables
                $uri = "https://$Server/ERPMWebService/json/V2/AuthService.svc/"
                $login = "$uri`DoLogin2"
                $logout = "$uri`DoLogout"
                $checkin = "$uri`AccountStoreOps_SharedCredential_CheckOut"
                $checkout = "$uri`AccountStoreOps_SharedCredential_CheckIn"


                # Body Variable Used for REST Authentication
                $body = @{
                            "Authenticator" = $Environment
                            "LoginType" = "2"
                            "Username" = $Credential.UserName
                            "Password" = $Credential.GetNetworkCredential().Password
                        }
                $json = $body | convertto-json
 
                # Login to ERPM REST Api and Get Session Token
                $session = Invoke-RestMethod -Method Post -Body $json -Uri $login -ContentType application/json
                $token = $session.OperationMessage

                if ([string]::IsNullOrEmpty($token))
                {
                    # Fail and semi-insult the user.
                    Write-Error "No token was received and a failure to log into ERPM happen."

                }
                else
                {
                    # Body Variable Used for Checking in and Checking Out Password
                    $body = @{
                                "AuthenticationToken"="$token"
                                "Comment"="$Comment"
                                "SharedCredentialIdentifier"=@{
                                                                "AccountName"="$AccountName"
                                                                "SharedCredentialListName"="$PasswordList"
                                                                "SystemName"="$SystemName"
                                                            }
                            }
                    $json = $body | convertto-json
                    # Checkin Password, Store As Variable, Checkout Password
                    $result = Invoke-RestMethod -Method Post -body $json -Uri $checkin -ContentType application/json
                    Invoke-RestMethod -Method Post -body $json -Uri $checkout -ContentType application/json | Out-Null
                    # Disconnect Session and Return
                    Invoke-RestMethod -Method Post -Body $json -Uri $logout -ContentType application/json | Out-Null

                    return $result
                }
            }
        }


$Credential = Get-Credential
$Comment = $Credential.UserName + " checked out " + $SystemName + " on " + $(Get-Date -format G)

<##
$OutputAccount = Get-ErpmSharedPassword -AccountName $AccountName `
                                        -SystemName $SystemName `
                                        -PasswordList $PasswordList `
                                        -Environment $Environment `
                                        -Credential $Credential `
                                        -Comment $Comment
#>

#$OutputAccount = Get-ErpmSharedPassword -AccountName "accountName" -SystemName "systemName" -PasswordList "pwordList" -Environment "CT" -Credential $Credential -Comment $Comment #CT is for PROD
$OutputAccount = Get-ErpmSharedPassword -AccountName "SA" -SystemName "SA - Effective 9/12/2017" -PasswordList "DBAs" -Environment "CT" -Credential $Credential -Comment $Comment #CT is for PROD
$outputAccount.Password