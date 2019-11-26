.\deployGitHubObjects.ps1  -targetDB "SQLMonitor" -phase "staging" -filter "dbauto_DWH_1.12.0.ZIP" -curretnDomain ".QA.LOCAL"
.\deployGitHubObjects.ps1  -targetDB "utility" -phase "staging" -filter "dbauto_UtilityDB_1.12.0.ZIP" -currentDomain ".QA.LOCAL" -repositoryRoot "C:\Users\hbrotherton\myGit\Releases"
 .\deployGitHubObjects.ps1  -targetDB "Utility" -phase "staging" -filter "dbauto_UtilityDB_1.12.0.ZIP" -currentDomain ".QA.LOCAL" -repositoryRoot "C:\Users\hbrotherton\myGit\Releases\Utility"  -dryRun 0
#.\deployGitHubObjects.ps1  -targetDB "StandardJobs" -phase "staging" -filter "dbauto_Utility_1.11.0.ZIP" -curretnDomain ".QA.LOCAL"
.\deployGitHubObjects.ps1  -targetDB "SystemDB" -phase "staging" -filter "dbauto_SharedScripts_1.11.0.ZIP" -curretnDomain ".QA.LOCAL"


.\deployGitHubObjects.ps1  -targetDB "utility" -phase "staging" -filter "dbauto_Janus_1.11.0.ZIP" -curretnDomain ".QA.LOCAL"
.\deployGitHubObjects.ps1  -targetDB "utility" -phase "staging" -filter "dbauto_ScriptNinja_1.11.0.ZIP" -curretnDomain ".QA.LOCAL"
