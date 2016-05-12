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

        Write-Host '-----------------------------------------------------------------------------------'
        Write-Host 'Starting the recover message process in' $node1 'and' $node2
        Write-Host '-----------------------------------------------------------------------------------'

		startProcess $node1 $node2 $timeRecoverIDK $timeRecoverIDF;

        Write-Host ''
        Write-Host '-----------------------------------------------------------------------------------'
        Write-Host 'Finished the recover message process in' $node1 'and' $node2
        Write-Host '-----------------------------------------------------------------------------------'
	}	
}

function startProcess($server1, $server2, $idk, $idf) {

    Write-Host 'Stage 1 ---------------------------------------------------------------------------'

    Write-Host 'Stage 1 >> Checking environment and LGW status'

    $server1IsValid = isValid $server1

    Write-Host 'Stage 1 ['$server1'] >> Is it a valid server?' $server1IsValid

    $server2IsValid = isValid $server2

    Write-Host 'Stage 1 ['$server2'] >> Is it a valid node?' $server2IsValid

    Write-Host 'Stage 2 ---------------------------------------------------------------------------'

    Write-Host 'Stage 2 >> Checking who is master'

    if ($server1IsValid) {

        $dateNode1 = Invoke-Command -ComputerName $server1 -Credential $cred -ScriptBlock {

            $finds = (Select-String -Path "D:\LOG\IAGLGW\AMDWLGW.log" -SimpleMatch "be Master")
            return ($finds[-1]).Line.Substring(0, 19)

        }

        Write-Host 'Stage 2 ['$server1'] >> Date / Time:' $dateNode1

    } else {

		Write-Host 'Stage 2 ['$server1'] >> Date / Time: null'

	}

    if ($server2IsValid) {

        $dateNode2 = Invoke-Command -ComputerName $server2 -Credential $cred -ScriptBlock {

            $finds = (Select-String -Path "D:\LOG\IAGLGW\AMDWLGW.log" -SimpleMatch "be Master")
            return ($finds[-1]).Line.Substring(0, 19)

	    } 

        Write-Host 'Stage 2 ['$server2'] >> Date / Time:' $dateNode2
    
    } else {

		Write-Host 'Stage 2 ['$server2'] >> Date / Time: null'
    
    }

    if ($server1IsValid -and $server2IsValid) {
        if ($dateNode1 -gt $dateNode2) {
            $master = $server1
            $slave = $server2

            Write-Host 'Stage 2 ['$server1'] >> Is it master or slave? master'
            Write-Host 'Stage 2 ['$server2'] >> Is it master or slave? slave'

        } else {
            $master = $server2
            $slave = $server1

            Write-Host 'Stage 2 ['$server1'] >> Is it master or slave? slave'
            Write-Host 'Stage 2 ['$server2'] >> Is it master or slave? master'
        }
    } elseif ($server1IsValid) {
        $master = $server1
        $slave = ""

        Write-Host 'Stage 2 ['$server1'] >> Is it master or slave? master'
        Write-Host 'Stage 2 ['$server2'] >> Server is invalid and will not recover messages'
    } elseif ($server2IsValid) {
        $master = $server2
        $slave = ""

        Write-Host 'Stage 2 ['$server1'] >> Server is invalid and will not recover messages'
        Write-Host 'Stage 2 ['$server2'] >> Is it master or slave? master'
    } else {
        $master = ""
        $slave = ""
        
        Write-Host 'Stage 2 ['$server1'] >> Server is invalid and will not recover messages'
        Write-Host 'Stage 2 ['$server2'] >> Server is invalid and will not recover messages'
    }

    Write-Host 'Stage 3 ---------------------------------------------------------------------------'

    Write-Host 'Stage 3 >> Stopping servers'

    if ($slave -ne "") {
        stopLGW $slave
        Write-Host 'Stage 3 ['$slave'] >> Server stopped'
    }

    if ($master -ne "") {
        stopLGW $master
        Write-Host 'Stage 3 ['$master'] >> Server stopped'
    }

    Write-Host 'Stage 4 ---------------------------------------------------------------------------'

    Write-Host 'Stage 4 >> Copying messages from Processed to Received folder'

    if ($master -ne "") {
        copyMessages $master $idk $idf
    }

    if ($slave -ne "") {
        copyMessages $slave $idk $idf
    }

    Write-Host 'Stage 5 ---------------------------------------------------------------------------'
    
    Write-Host 'Stage 5 >> Starting servers'

    if ($server1IsValid -or $server2IsValid) {
        startLGW $server1
        Write-Host 'Stage 5 ['$server1'] >> Server started'
        
        startLGW $server2
        Write-Host 'Stage 5 ['$server2'] >> Server started'
    }
}

function isValid($server) {
	
    if ($server -ne "") {
        return Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {

            $node = $env:COMPUTERNAME
	        $service = (Get-Service -name "MEV_AMDWLGW").Status
	        $environment = $env:ENVIRONMENT
		
	        Write-Host 'Stage 1 ['$node'] >> Environment:' $environment
            Write-Host 'Stage 1 ['$node'] >> LGW status:' $service

            return ($service -eq "Running" -and ($environment -eq "OPE" -or $environment -eq "PPE"))

        }
    } else {
        return $false
    }
}

function stopLGW($server) {

	Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {

        $node = $env:COMPUTERNAME

        cmd.exe /c 'D:\Atos\scripts\stopLGW.bat'

        while (Get-Job -State "Running") {
            Start-Sleep 1
        }
    }
}

function copyMessages($server, $idk, $idf) {

	Invoke-Command -ComputerName $server -ArgumentList $idk,$idf -Credential $cred -ScriptBlock {

        $timeRecoverIDK = $args[0]
        $timerecoverIDF = $args[1]

        $node = $env:COMPUTERNAME
	    $environment = $env:ENVIRONMENT

	    $folders = Get-ChildItem -Path "D:\DATA\persistency\$environment\qp\queues\"

        foreach ($folder in $folders) {

            if ($folder.Name.Contains("LGW")) {
           		
                $processed = $folder.FullName + "\Processed\"
    		    $received = $folder.FullName + "\Received\0000\"

                if ($folder.Name.Contains("IDK")) {
                    
                    $messages_idk = Get-ChildItem -Path $processed -File *.MSG -Recurse | where {$_.CreationTime -ge $timeRecoverIDK} 

                    foreach ($message_idk in $messages_idk) {
                        Copy-Item $message_idk -Destination $received

                        Write-Host 'Stage 4 ['$node'] >> Copying' $message_idk
                    }
                
                } elseif ($folder.Name.Contains("IDF")) {

                    $messages_idf = Get-ChildItem -Path $processed -File *.MSG -Recurse | where {$_.CreationTime -ge $timerecoverIDF}

                    foreach ($message_idf in $messages_idf) {
                        Copy-Item $message_idf -Destination $received

                        Write-Host 'Stage 4 ['$node'] >> Copying' $message_idf
                    }
                }
            }
        }
    }
}

function startLGW($server) {

    Invoke-Command -ComputerName $server -Credential $cred -ScriptBlock {

        $node = $env:COMPUTERNAME
        $environment = $env:ENVIRONMENT

        cmd.exe /c "D:\Atos\scripts\startLGW.bat $environment"

        while (Get-Job -State "Running") {
            Start-Sleep 1
        }
    }
}
