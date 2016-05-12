
$node = $env:COMPUTERNAME
$service = (Get-Service -name "MEV_AMDWLGW").Status
$environment = $env:ENVIRONMENT

if ($service -eq "Running") {
	
	cmd.exe /c 'D:\Atos\scripts\stopLGW.bat'
	
	while (Get-Job -State "Running") {
    	Start-Sleep 1
    }
	
	$timeRecoverIDK = $args[0]
    $timerecoverIDF = $args[1]

	$folders = Get-ChildItem -Path "D:\DATA\persistency\$environment\qp\queues\"

	foreach ($folder in $folders) {

		if ($folder.Name.Contains("LGW")) {
			
			$processed = $folder.FullName + "\Processed\"

			if ($folder.Name.Contains("IDK")) {

				Get-ChildItem -Path $processed -File *.MSG -Recurse | Remove-Item
				
			}
		}
	}

	cmd.exe /c "D:\Atos\scripts\startLGW.bat $environment"
}
