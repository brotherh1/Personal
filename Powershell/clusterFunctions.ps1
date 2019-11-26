FUNCTION getCluster-Hardware ( [string] $myCluster )
{

    $nodeList = Get-ClusterNode -Cluster $myCluster
    $nodeCount = $nodeList.Count
    WRITE-HOST `t"Node Count: $nodeCount "
    ForEach($node in $nodeList)
        {
            $ipInfo = [System.Net.Dns]::GetHostAddresses("$node")
            $nodeIP = $ipInfo.IPAddressToString
            $nodeBuildDate = gcim Win32_OperatingSystem -computerName $node | select  -exp InstallDate 
            #WRITE-HOST `t`t"Node - $node - $nodeIP - $nodeBuildDate"

            $ipInfo = [System.Net.Dns]::GetHostAddresses("$node")
            $nodeIP = $ipInfo.IPAddressToString
            WRITE-HOST `t"[]Node - $node - $nodeIP - $nodeBuildDate"
            #$serverInfo = invoke-command -computerName XTINP1CL03n3 -ScriptBlock { systemInfo }  # systeminfo | find /V /I "hotfix" | find /V "KB"
            $serverInfo = invoke-command -computerName $node -ScriptBlock { systemInfo }  # systeminfo | find /V /I "hotfix" | find /V "KB"
            #  get-WmiObject win32_logicaldisk -Computername XTINP1CL03n3
            $tempSockets = $serverInfo | findStr /r /C:"Processor(s)[ ]Installed"
            WRITE-HOST `t`t"$tempSockets"
            WRITE-HOST `t`t"Cores"
            $tempRAM = $serverInfo | findStr /r /C:"Total[ ]Physical[ ]Memory:"
            # $tempRAM = [MATH]::Round($tempRAM / 1GB)
            WRITE-HOST `t`t"$tempRAM"
            #$cDriveInfo = get-WmiObject win32_logicaldisk -Computername XTINP1CL03n3 | where caption -eq "C:"
            $cDriveInfo = get-WmiObject win32_logicaldisk -Computername $node | where caption -eq "C:"
            $cDriveSize = [MATH]::Round($cDriveInfo.Size / 1GB)
            WRITE-HOST `t`t"C: Drive Size: $cDriveSize GB"
            #$dDriveInfo = get-WmiObject win32_logicaldisk -Computername XTINP1CL03n3 | where caption -eq "C:"
            $dDriveInfo = get-WmiObject win32_logicaldisk -Computername $node | where caption -eq "D:"
            $dDriveSize = [MATH]::Round($dDriveInfo.Size / 1GB)
            WRITE-HOST `t`t"D: Drive Size: $dDriveSize GB"
            $tempNIC = $serverInfo | findStr /r /C:"Network[ ]Card(s)"
            WRITE-HOST `t`t"$tempNIC"
            $tempOSbuild = $serverInfo | findStr /r /C:"Original[ ]Install[ ]Date:"
            WRITE-HOST `t`t"$tempOSbuild"
            $tempManufacturer = $serverInfo | findStr /r /C:"System[ ]Manufacturer:"
            WRITE-HOST `t`t"$tempManufacturer"
            $tempSystemModel = $serverInfo | findStr /r /C:"System[ ]Model:"
            WRITE-HOST `t`t"$tempSystemModel"
        }
}

 <#####################################################################
Purpose:  
     This script returns information for the hardware in a cluster - similar to what might be in inventory. 
History:  
     20181030 hbrotherton W-5417461 CREATED
     
     YYYYMMDD USERID W-000000000 This is what I changed.
Comments:
     . .\clusterFunctions.ps1
     
     getCluster-Hardware -myCluster IND2QA1C001
#######################################################################>
