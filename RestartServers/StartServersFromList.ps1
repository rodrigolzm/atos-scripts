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

function invokeForService($servers, $service) {
	Invoke-Command -ComputerName $servers -ArgumentList $service -Credential $cred -ThrottleLimit 2 -ScriptBlock {
		
		$service = $args[0]
		$node = $env:COMPUTERNAME
		
		Write-Host ''    
		Write-Host 'Starting: Service' $service 'in server' $node
		
		Get-Service -name $service | Start-Service
		
		while (get-job -state "Running") { start-sleep 1 }
	}
}

function invokeForCluster($servers, $service) {
	Invoke-Command -ComputerName $servers -ArgumentList $service -Credential $cred -ThrottleLimit 2 -ScriptBlock {

		$service = $args[0]
		$node = $env:COMPUTERNAME
		$master = ((Get-ClusterResource -Name 'Cluster Disk' | SELECT OwnerNode).OwnerNode).Name

		if ($master -eq $node) {

			Write-Host ''
			Write-Host 'Starting: Service' $service 'in cluster' $node

			Get-ClusterGroup 'MEV Role' | Get-ClusterResource $service | Start-ClusterResource

			while (get-job -state "Running") { start-sleep 1 }
		}	
	}
}

function invokeForInfoService($servers, $delay) {
	foreach ($server in $servers) {
		Invoke-Command -ComputerName $server -AsJob -JobName "STARTINFO" -Credential $cred -ScriptBlock {

			$node = $env:COMPUTERNAME
			
			Write-Host ''
			Write-Host 'Starting: Service JBOSS-MEV-EWS in' $node
			
			Get-Service -name "JBOSS-MEV-EWS" | Start-Service

			Write-Host ''
			Write-Host 'Starting: Service JBOSS-MEV-INF in' $node
			
			Get-Service -name "JBOSS-MEV-INF" | Start-Service
			
			while (get-job -state "Running") { start-sleep 1 }
		}

		Start-sleep -s $delay
	}
}

function invokeForLGW($servers) {
	foreach ($server in $servers) {
		Invoke-Command -ComputerName $server -AsJob -JobName "STARTLGW" -Credential $cred -ScriptBlock {

			$node = $env:COMPUTERNAME
			
			Write-Host ''
			Write-Host 'Starting: Service MEV_AMDWMSM in' $node
			
			Get-Service -name "MEV_AMDWMSM" | Start-Service

			Write-Host ''
			Write-Host 'Starting: Service MEV_AMDWQUP in' $node
			
			Get-Service -name "MEV_AMDWQUP" | Start-Service

			#Write-Host ''
			#Write-Host 'Starting: Service MEV_AMDWLGW in' $node
			
			#Get-Service -name "MEV_AMDWLGW" | Start-Service			
			
			while (get-job -state "Running") { start-sleep 1 }
		}
	}
}


if ($lgw_servers.Length -gt 0) {
    invokeForLGW $lgw_servers;
}

if ($odf_servers.Length -gt 0) {
    invokeForCluster $odf_servers "MEV BIF";
    #invokeForCluster $odf_servers "MEV IDF";
}

if ($bif_servers.Length -gt 0) {
    invokeForService $bif_servers "JBOSS-MEV-BIF";
}

if ($dfv_servers.Length -gt 0) {
    invokeForService $dfv_servers "JBOSS-MEV-DFV";
	#invokeForService $dfv_servers "JBOSS-MEV-IDF";
}

if ($ikp_servers.Length -gt 0) {
	invokeForCluster $ikp_servers "MEV_AMDWQUP";
    invokeForCluster $ikp_servers "MEV_DIDSIDK";
}

if ($qps_servers.Length -gt 0) {
    invokeForCluster $qps_servers "MEV_AMDWQ2P";
	invokeForCluster $qps_servers "MEV_AMDWQ2S";
}

if ($idk_servers.Length -gt 0) {
    invokeForCluster $idk_servers "MEV_DIDSIDK";
}

if ($info_servers.Length -gt 0) {
    invokeForInfoService $info_servers 90;
}

if ($myinfo_servers.Length -gt 0) {
    invokeForInfoService $myinfo_servers 90;
}



Write-Host '-------------------------------------------------------------'
Write-Host 'Finished!'
Write-Host ''
