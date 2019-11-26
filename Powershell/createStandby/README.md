# Create Standby
This repository is for objects that we run manually to create standbys  

Purpose of the following subfolders:
-  createStandby-CR.ps1 - creates a standard CR for building a standby
-  createNewStandby.ps1 - takes last nights backup and moves it to standby and builds everything.
-  RestoreDatabase_ET.ps1 - used by createNewSTandby.ps1
-  cmdLine-Standby.ps1 - used by createNewSTandby.ps1
-  monitorFullBackup.ps1 - should be used by SQL Agent job to send alerts to SLACK channel

____
