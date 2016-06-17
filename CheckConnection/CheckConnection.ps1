[xml]$xmlClients = Get-Content -Path C:\clients.xml
$clients = $xmlClients['client-list'].ChildNodes
foreach($client in $clients) {
    $httpAddress = $client.http.Substring(7)
    if ($httpAddress.Contains("/")) {
        $httpAddress = $httpAddress.Substring(0, $httpAddress.IndexOf("/"))
    }
    if ($httpAddress.Contains(':')) {
        $ip = $httpAddress.Substring(0, $httpAddress.IndexOf(":"))
        $port = $httpAddress.Substring($httpAddress.IndexOf(":") + 1)
    } else {
        $ip = $httpAddress
        $port = 80
    }
    try {
        $connection = New-Object System.Net.Sockets.TcpClient -ArgumentList $ip,$port
    } catch {
		Write-Host $client.Name '>>' $ip':'$port '>>' $client.http
    }
}


