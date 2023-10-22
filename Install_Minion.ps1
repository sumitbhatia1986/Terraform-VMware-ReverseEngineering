$SALTMASTER = 'x.x.x.x' #Required field
$MINIONNAME = $env:COMPUTERNAME
echo $MINIONNAME

# Do not Deploy if Salt is already on the system
if ([System.IO.File]::Exists("c:\salt\bin\python.exe")) {
    Write-output "nothing to do - Salt is already installed" 
    #exit 0
}

Write-output "Salt is not installed, Starting Salt Deployment script"


#This downloads the Salt install to Temp
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } 
$webclient = New-Object system.net.webclient
$tempfolder = $env:TEMP
Write-output "Downloading Salt Minion to $tempfolder"

$webclient.DownloadFile("https://repo.saltproject.io/salt/py3/windows/latest/Salt-Minion-3006.3-Py3-AMD64-Setup.exe", "$tempfolder\saltminion.exe") #Downloading minion from SALT website.


if (![System.IO.File]::Exists("$tempfolder\saltminion.exe")) {
    Write-output "FAILED - Failed to find $tempfolder\saltminion.exe , was supposed to download from https://repo.saltproject.io/salt/py3/windows/latest/Salt-Minion-3006.3-Py3-AMD64-Setup.exe, please investigate, exiting script."
    exit 1
}

if ([System.IO.File]::Exists("$tempfolder\saltminion.exe")) {
    Write-output " SALT executable download successfull "

}


$MINIONCONF = @"
id: $MINIONNAME
master: $SALTMASTER
tcp_keepalive: True
tcp_keepalive_idle: 60
"@

new-item -Path "C:\ProgramData\Salt Project\Salt\conf" -itemtype directory
new-item -Path "C:\ProgramData\Salt Project\Salt\conf\minion.d" -itemtype directory

Set-Content "C:\ProgramData\Salt Project\Salt\conf\minion.d\minion.conf" $MINIONCONF


Start-Process -FilePath $tempfolder'\saltminion.exe' -ArgumentList "/S /master=$SALTMASTER /minion-name=$MINIONNAME", /install-dir="C:\salt" -Wait  #Minion installation

New-Item -ItemType SymbolicLink -Path "C:\salt\conf" -Target "C:\ProgramData\Salt Project\Salt\conf"
New-Item -ItemType SymbolicLink -Path "C:\salt\var" -Target "C:\ProgramData\Salt Project\Salt\var"

sleep 5
if (-not (Get-Service 'salt-minion'  -ErrorAction SilentlyContinue)) {
    Write-output "Did not find salt-minion service , sleeping 30 seonds and retrying."
    sleep 30
    if (-not (Get-Service 'salt-minion'  -ErrorAction SilentlyContinue)) {
        Write-output "FAILED - Did not find salt-minion service."
        Write-output "removing c:\salt because salt installed failed"
        Remove-Item -Path c:\salt -Force -Recurse
        Write-output "FAILED - Salt Minion Failed to Install, please investigate, exiting script."
        exit 1
    }
}
if( Get-Service 'salt-minion') {
        write-output "Salt Service is running"
}

Write-output "-------------------------------------------"
Write-output "Installation of SaltMinion was successful!"
Write-output "-------------------------------------------"
exit 0
