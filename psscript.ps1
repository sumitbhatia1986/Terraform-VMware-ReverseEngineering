#Sample master IP here is x.x.x.x
#Repository IP where the addminion.ps1 script reside is x.x.x.x
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } 
$webclient = New-Object system.net.webclient
for ($i;$i -lt 6;$i++) {
    $webclient.DownloadFile("https://x.x.x.x:8443/repository/addminion.ps1", "$env:TEMP\addminion.ps1") #Repository path where your addminion.ps1 script is placed. This patch should be accessible by the VM because this code will run inside the VM you deploying by Terraform.
    if (Test-Path -Path $env:TEMP\addminion.ps1){break } else { sleep 5 }  }
& "$env:TEMP\addminion.ps1" -master x.x.x.x -stateful -defaults
