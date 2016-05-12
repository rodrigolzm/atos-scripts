Function Get-RecoverMessages {
    
	[CmdletBinding()]
    Param (
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string]$dateTime,

        [Parameter(Position=1,Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [int16]$idkInterval = 40,

        [Parameter(Position=2,Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [int16]$idfInterval = 20
    )

	$cred  = Get-Credential
	
	$idkInterval = $idkInterval * -1
	$idfInterval = ($idfInterval / 60) * -1

	$dateTimeDisaster = [datetime]::ParseExact($dateTime, "yyyy-MM-dd HH:mm", $null)
	$timeRecoverIDK = ($dateTimeDisaster).AddMinutes($idkInterval)
	$timeRecoverIDF = ($dateTimeDisaster).AddMinutes($idfInterval)

	$servers = @()
	$servers = get-content 'LGWs.txt'

	foreach($server in $servers) {

		$node1 = $server + "-001"
		$node2 = $server + "-002"

		startProcess $node1 $node2 $timeRecoverIDK $timeRecoverIDF;

	}	
	
}

function startProcess($server1, $server2, $idk, $idf) {

    $server1IsValid = isValid $server1
    $server2IsValid = isValid $server2

    if ($server1IsValid) {

        $dateNode1 = Invoke-Command -ComputerName $server1 -Credential $cred -ScriptBlock {

            $finds = (Select-String -Path "D:\LOG\IAGLGW\AMDWLGW.log" -SimpleMatch "be Master")
            return ($finds[-1]).Line.Substring(0, 19)

        }

    } else {

		Write-Host ''
		Write-Host $server1 'will not recover messages'

	}

    if ($server2IsValid) {

        $dateNode2 = Invoke-Command -ComputerName $server2 -Credential $cred -ScriptBlock {

            $finds = (Select-String -Path "D:\LOG\IAGLGW\AMDWLGW.log" -SimpleMatch "be Master")
            return ($finds[-1]).Line.Substring(0, 19)

	    } 
    
    } else {

		Write-Host ''
		Write-Host $server2 'will not recover messages'
    
    }

    if ($server1IsValid -and $server2IsValid) {

        if ($dateNode1 -gt $dateNode2) {
            $master = $server1
            $slave = $server2
        } else {
            $master = $server2
            $slave = $server1
        }
    
    } elseif ($server1IsValid) {
    
        $master = $server1
        $slave = ""
    
    } elseif ($server2IsValid) {
        
        $master = $server2
        $slave = ""
    
    } else {

        $master = ""
        $slave = ""

    }

    if ($slave -ne "") {
        stopLGW $slave
    }

    if ($master -ne "") {
        stopLGW $master
    }

    if ($master -ne "") {
        copyMessages $master $idk $idf
    }

    if ($slave -ne "") {
        copyMessages $slave $idk $idf
    }

    if ($master -ne "") {
        startLGW $master
		Start-Sleep -Seconds 60
    }

    if ($slave -ne "") {
        startLGW $slave
    }

}

function isValid($server) {
	
    if ($server -ne "") {
        return Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {

            $node = $env:COMPUTERNAME
	        $service = (Get-Service -name "MEV_AMDWLGW").Status
	        $environment = $env:ENVIRONMENT
		
	        Write-Host ''
	        Write-Host 'Checking' $node '>> Service is' $service 'and Env is' $environment

            return ($service -eq "Running" -and ($environment -eq "OPE" -or $environment -eq "PPE"))

        }
    } else {
        return $false
    }

}

function stopLGW($server) {

	Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {

        $node = $env:COMPUTERNAME
		
	    Write-Host ''
	    Write-Host 'Stopping' $node

        cmd.exe /c 'D:\Atos\scripts\stopLGW.bat'

    }
}

function copyMessages($server, $idk, $idf) {

	Invoke-Command -ComputerName $server -ArgumentList $idk,$idf -Credential $cred -ScriptBlock {

        $timeRecoverIDK = $args[0]
        $timerecoverIDF = $args[1]

        $node = $env:COMPUTERNAME
	    $environment = $env:ENVIRONMENT

        Write-Host ''
	    Write-Host $node '>> copying messages from processed to received'
		
	    $folders = Get-ChildItem -Path "D:\DATA\persistency\$environment\qp\queues\"

        foreach ($folder in $folders) {

            if ($folder.Name.Contains("LGW")) {
           		
                $processed = $folder.FullName + "\Processed\"
    		    $received = $folder.FullName + "\Received\0000\"

                if ($folder.Name.Contains("IDK")) {
                    
                    Get-ChildItem -Path $processed -File *.MSG -Recurse | where {$_.CreationTime -ge $timeRecoverIDK} | Copy-Item -Destination $received
                
                } elseif ($folder.Name.Contains("IDF")) {

                    Get-ChildItem -Path $processed -File *.MSG -Recurse | where {$_.CreationTime -ge $timerecoverIDF} | Copy-Item -Destination $received
                    
                }
            }
        }
    }
}

function startLGW($server) {

    Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {

        $node = $env:COMPUTERNAME
	    Write-Host ''
	    Write-Host 'Starting' $node

        $environment = $env:ENVIRONMENT
        cmd.exe /c "D:\Atos\scripts\startLGW.bat $environment"
    
    }

}


