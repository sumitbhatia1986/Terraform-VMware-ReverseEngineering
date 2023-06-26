#Sample master IP here is 136.252.235.185
#Repository IP where the addminion.ps1 script reside is 10.196.184.8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } 
$webclient = New-Object system.net.webclient
for ($i;$i -lt 6;$i++) {
    $webclient.DownloadFile("https://10.196.184.8:8443/repository/raw-salt-nobrowse/salt/client/addminion.ps1", "$env:TEMP\addminion.ps1") 
    if (Test-Path -Path $env:TEMP\addminion.ps1){break } else { sleep 5 }  }
& "$env:TEMP\addminion.ps1" -master 136.252.235.185 -stateful -defaults