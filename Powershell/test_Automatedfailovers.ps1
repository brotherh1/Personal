  remove-module "AutomatedFailover-Module"
   import-module .\AutomatedFailover-Module.psm1 -verbose 

get-help Set-InMaintenance -Full
get-help check-preFailover -full
get-help check-postFailover -full

$myCred = get-credential

Set-InMaintenance -instanceList ATL1QA1C012I12#I12 -maintStatus 1 -maintDuration 90 -maintComments "I am attempting to destroy this instance for 90 minutes_HKB" -Credential $myCred 
Set-InMaintenance -instanceList ATL1QA1C012I12#I12 -maintStatus 1 -maintDuration 90 -maintComments "I am about to destroy this instance for 90 minutes_HKB" -Credential $myCred -takeAction

check-preFailover -instanceList "ATL1QA1C012I12#I12" -Credential $myCred
check-preFailover -instanceList "ATL1QA1C012I12#I12" -Credential $myCred -takeAction

<#############  SOME SORT OF DESCTRUCTIVE ACTION WAS TAKEN AND THE INSTANCE IS NOW RECOVERED ################>

check-postFailover -instanceList "ATL1QA1C012I12#I12" -Credential $myCred
check-postFailover -instanceList "ATL1QA1C012I12#I12" -Credential $myCred -takeAction

Set-InMaintenance -instanceList ATL1QA1C012I12#I12 -maintStatus 0 -maintComments "I am done destroying this instance_HKB" -Credential $myCred 
Set-InMaintenance -instanceList ATL1QA1C012I12#I12 -maintStatus 0 -maintComments "I am done destroying this instance_HKB" -Credential $myCred -takeAction