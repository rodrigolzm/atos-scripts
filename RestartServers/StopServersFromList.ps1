$cred  = Get-Credential

$servers = get-content "ListServers.txt"

$dfv_servers = @()
$bif_servers = @()
$odf_servers = @()
$idk_servers = @()
$info_servers = @()
$myinfo_servers = @()
$lgw_servers = @()
$qps_servers = @()
$ikp_servers = @()

ForEach ($server in $servers) {
    if ($server.Contains("IAD")) {
        $dfv_servers += $server
    } elseif ($server.Contains("BIF")) {
		$bif_servers += $server
	} elseif ($server.Contains("ODF")) {
		$odf_servers += $server
	} elseif ($server.Contains("IDK")) {
		$idk_servers += $server
	} elseif ($server.Contains("INF")) {
		$info_servers += $server
	} elseif ($server.Contains("MNF")) {
		$myinfo_servers += $server
    } elseif ($server.Contains("LGW")) {
        $lgw_servers += $server
	} elseif ($server.Contains("QPS")) {
		$qps_servers += $server
    } elseif ($server.Contains("IKP")) {
        $ikp_servers += $server
	}
}

function removeMessagesFromDFS($service, $servers) {

	if ($servers[0].Contains("OPE")) {
		$environment = "OPE"
	} elseif ($servers[0].Contains("OT1")) {
		$environment = "OT1"
	} elseif ($servers[0].Contains("OT2")) {
		$environment = "OT2"
	} elseif ($servers[0].Contains("PPE")) {
		$environment = "PPE"
	} elseif ($servers[0].Contains("PT1")) {
		$environment = "PT1"
	} elseif ($servers[0].Contains("PT2")) {
		$environment = "PT2"
	} elseif ($servers[0].Contains("OSE")) {
		$environment = "OSE"
	}
	
	if (($environment -eq "OPE") -or ($environment -eq "PPE")) {
		$dfs_servers = "PDC-S2DFSAG-001","PDC-S2DFSAG-002"
	} elseif (($environment -eq "OT1") -or ($environment -eq "PT1")) {
		$dfs_servers = "E2E-L2IDSDS-001","E2E-L2IDSDS-002"
	} elseif (($environment -eq "OT2") -or ($environment -eq "PT2")){
		$dfs_servers = "ITL-L2IDSDG-001"
	} elseif ($environment -eq "OSE"){
		$dfs_servers = "SDC-S2DFSAG-001","SDC-S2DFSAG-002"
	}

	Invoke-Command -ComputerName $dfs_servers -ArgumentList $service,$environment -Credential $cred -ThrottleLimit 2 -ScriptBlock {

		$service = $args[0]
		$environment = $args[1]
		$node = $env:COMPUTERNAME
		$master = ((Get-ClusterResource -Name 'Cluster Disk' | SELECT OwnerNode).OwnerNode).Name

		if ($master -eq $node) {

			if ($service -eq "MEV IDF") {
				
				Write-Host ''
				Write-Host 'Removing: IDF Listener and Sender counters from shared folder in' $node

				Remove-Item E:\Shares\IDS\$environment\IDF\repository\Common\status\Listeners\* -Recurse

				Remove-Item E:\Shares\IDS\$environment\IDF\repository\Common\status\Senders\* -Recurse

				$folders = Get-ChildItem -Path E:\Shares\IDS\$environment\IDF\repository\Common\*

				foreach ($folder in $folders) {
					if (($folder.Name.substring(0,4) -eq "2015") -or ($folder.Name.substring(0,4) -eq "2016")) {
						
						Write-Host ''
						Write-Host 'Removing: IDF messages from' $folder.Name 'in' $node

						Remove-Item $folder -Recurse
					}
				}
			
			} elseif ($service -eq "MEV BIF") {

				Write-Host ''
				Write-Host 'Removing: BIF messages from shared folder in' $node

				Remove-Item E:\Shares\IDS\$environment\BIF\repository\messages\* -Recurse

				Remove-Item E:\Shares\IDS\$environment\BIF\repository\tmp\* -Recurse

				Remove-Item E:\Shares\IDS\$environment\BIF\repository\zip\* -Recurse
			
			} elseif ($service -eq "JBOSS-MEV-DFV") {
				
				Write-Host ''
				Write-Host 'Removing: DFV messages from shared folder in' $node

				Remove-Item E:\Shares\IDS\$environment\DFV-1\indexes\* -Recurse

				Remove-Item E:\Shares\IDS\$environment\DFV-1\messages\* -Recurse

				Remove-Item E:\Shares\IDS\$environment\DFV-2\indexes\* -Recurse

				Remove-Item E:\Shares\IDS\$environment\DFV-2\messages\* -Recurse
			}
		}
		
		while (get-job -state "Running") { start-sleep 1 }
	}
}

function invokeForService($servers, $service, $removeMessages, $removeLogs) {
	Invoke-Command -ComputerName $servers -ArgumentList $service,$removeMessages,$removeLogs -Credential $cred -ThrottleLimit 2 -ScriptBlock {
		
		$service = $args[0]
		$removeMessages = $args[1]
		$removeLogs = $args[2]
		$node = $env:COMPUTERNAME
		
		Write-Host ''    
		Write-Host 'Stoping: Service' $service 'in server' $node
		
		Get-Service -name $service | Stop-Service
		
		while (get-job -state "Running") { start-sleep 1 }
		
		if ($removeLogs) {

			Write-Host ''
			Write-Host 'Removing: Log files in' $node

			if ($service -eq "JBOSS-MEV-DFV") {
				
				Remove-Item D:\LOG\DFV\* -Recurse
			
			} elseif ($service -eq "JBOSS-MEV-IDF") {
			
				Remove-Item D:\LOG\IDF\* -Recurse

			} elseif ($service -eq "JBOSS-MEV-BIF") {
			
				Remove-Item D:\LOG\BIF\* -Recurse
			
			}
		}
	}
	
	if ($removeMessages) {
		removeMessagesFromDFS $service $servers;
	}

}

function invokeForCluster($servers, $service, $removeMessages, $removeLogs) {
	Invoke-Command -ComputerName $servers -ArgumentList $service,$removeMessages,$removeLogs -Credential $cred -ThrottleLimit 2 -ScriptBlock {

		$service = $args[0]
		$removeMessages = $args[1]
		$removelogs = $args[2]
		$node = $env:COMPUTERNAME
		$master = ((Get-ClusterResource -Name 'Cluster Disk' | SELECT OwnerNode).OwnerNode).Name
		
		if ($master -eq $node) {

			Write-Host ''
			Write-Host 'Stoping: Service' $service 'in cluster' $node

			Get-ClusterGroup 'MEV Role' | Get-ClusterResource $service | Stop-ClusterResource
			
			if ($removeMessages -And ($service -eq "MEV IDF")) {

				Write-Host ''
				Write-Host 'Removing: IDF Listener and Sender counters from local folder in' $node
			
				Remove-Item F:\DATA\IDS\IDF\SRV\APP\repository\local\status\Listeners\* -Recurse

				Remove-Item F:\DATA\IDS\IDF\SRV\APP\repository\local\status\Senders\* -Recurse
			}
			
			while (get-job -state "Running") { start-sleep 1 }
		}
		
		if ($removeLogs) {
		
			Write-Host ''
			Write-Host 'Removing: Log files in' $node
		
			if ($service -eq "MEV IDF") {
				
				Remove-Item D:\LOG\IDSIDF\* -Recurse
			
			} elseif ($service -eq "MEV BIF") {
			
				Remove-Item D:\LOG\IDSBIF\* -Recurse
			
			} elseif ($service -eq "MEV_DIDSIDK") {
			
				Remove-Item D:\LOG\IDSIDK\* -Recurse
							
			} elseif ($service -eq "MEV_AMDWQUP") {
			
				Remove-Item D:\LOG\IAGQUP\* -Recurse
				Remove-Item D:\DATA\IAG\MDW\COR\persistencyOT2\* -Recurse
			
			} elseif ($service -eq "MEV_AMDWQ2S") {
			
				Remove-Item D:\LOG\IAGQ2S\* -Recurse
			
			} elseif ($service -eq "MEV_AMDWQ2P") {
			
				Remove-Item D:\LOG\IAGQ2P\* -Recurse
				Remove-Item D:\Atos\IAG\MDW\Q2P\APP\tmp\* -Recurse
			}
		}
	}

	if ($removeMessages) {
		removeMessagesFromDFS $service $servers;
	}
}

function invokeForInfoService($servers, $deleteTmp) {
	Invoke-Command -ComputerName $servers -ArgumentList $deleteTmp -Credential $cred -ThrottleLimit 10 -ScriptBlock {

		$deleteTmp = $args[0]
		$node = $env:COMPUTERNAME
		
		Write-Host ''
		Write-Host 'Stoping: Service JBOSS-MEV-INF in' $node
		
		Get-Service -name "JBOSS-MEV-INF" | Stop-Service

		Write-Host ''
		Write-Host 'Stoping: Service JBOSS-MEV-EWS in' $node
		
		Get-Service -name "JBOSS-MEV-EWS" | Stop-Service
		
		if ($deletetmp) {

			Write-Host ''
			Write-Host 'Removing: TMP files in' $node
		
			Remove-Item D:\TMP\* -Recurse
		}
	}
}

function invokeForLGW($servers, $cleanUp) {
	Invoke-Command -ComputerName $servers -ArgumentList $cleanUp -Credential $cred -ThrottleLimit 2 -ScriptBlock {
		
		$cleanUp = $args[0]
        $node = $env:COMPUTERNAME
		
		#Write-Host ''    
		#Write-Host 'Stoping: Service MEV_AMDWLGW in server' $node
		
		#Get-Service -name "MEV_AMDWLGW" | Stop-Service

		Write-Host ''    
		Write-Host 'Stoping: Service MEV_AMDWQUP in server' $node
		
		Get-Service -name "MEV_AMDWQUP" | Stop-Service

		Write-Host ''    
		Write-Host 'Stoping: Service MEV_AMDWMSM in server' $node
		
		Get-Service -name "MEV_AMDWMSM" | Stop-Service

	    if ($cleanUp) {

		    Write-Host ''
		    Write-Host 'Removing: persistency files in' $node

		    Remove-Item D:\DATA\persistency\* -Recurse
	    }

		while (get-job -state "Running") { start-sleep 1 }
    }
}

if ($info_servers.Length -gt 0) {
    invokeForInfoService $info_servers $true;
}

if ($myinfo_servers.Length -gt 0) {
    invokeForInfoService $myinfo_servers $true;
}

if ($odf_servers.Length -gt 0) {
    invokeForCluster $odf_servers "MEV IDF" $true $true;
    invokeForCluster $odf_servers "MEV BIF" $true $true;
}

if ($idk_servers.Length -gt 0) {
    invokeForCluster $idk_servers "MEV_DIDSIDK" $true $false;
}

if ($ikp_servers.Length -gt 0) {
    invokeForCluster $ikp_servers "MEV_DIDSIDK" $false $true;
	invokeForCluster $ikp_servers "MEV_AMDWQUP" $false $true;
}

if ($qps_servers.Length -gt 0) {
    invokeForCluster $qps_servers "MEV_AMDWQ2P" $false $true;
	invokeForCluster $qps_servers "MEV_AMDWQ2S" $false $true;
}

if ($bif_servers.Length -gt 0) {
    invokeForService $bif_servers "JBOSS-MEV-BIF" $true $true;
}

if ($dfv_servers.Length -gt 0) {
    invokeForService $dfv_servers "JBOSS-MEV-DFV" $true $true;
	invokeForService $dfv_servers "JBOSS-MEV-IDF" $true $true;	
}

if ($lgw_servers.Length -gt 0) {
    invokeForLGW $lgw_servers $true;
}

Write-Host '-------------------------------------------------------------'
Write-Host 'Finished!'
Write-Host ''
