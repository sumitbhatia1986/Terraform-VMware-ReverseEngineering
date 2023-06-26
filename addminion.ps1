#
# Creator Sumit Bhatia
# log file wil be at C:\Users\Public\Documents\salt-agent-deploy.log
# leave this at the top of the script
param([alias('master')][string]$saltmaster='undefined',[alias('env')]$environment='default',[alias('minionid')][string]$minonname,
      [string]$ssr="metadata",[string]$notificationemail='creator',[string]$nexusrepo='10.196.184.8:8443',[string]$saltver='3004.2',
      [string]$runjobs="",
      [alias('h')][switch]$help,
      [string]$VER='7.14.0',
      [switch]$autoaccept,[switch]$dryrun,[switch]$failtest,[switch]$localrepo,[switch]$norepo, 
      [switch]$py2,[switch]$py3,[switch]$verbose,
      [string]$masterless_zip,[int]$masterlesstimeout=3600,
      [switch]$noreboots, [switch]$postdeploydebug,[switch]$noextendedapps,[switch]$uft,
      [switch]$nostateful,[switch]$notstateful,[switch]$postdeployonly,[switch]$saltmanaged,[switch]$stateful,
      [switch]$defaults,[switch]$emailalways,[switch]$minimal,
      [switch]$adjoin,[switch]$adreplace,[switch]$bigfix,[switch]$ciscat_eval,[switch]$ciscat_remediation,
      [switch]$firewall_managed,[switch]$flexera,[switch]$hpomi,[switch]$netbackup,
      [switch]$network_managed,[switch]$qualys,[switch]$slb_certs,
      [switch]$noadjoin,[switch]$noadreplace,[switch]$noautoaccept,[switch]$nobigfix,[switch]$nociscat_eval,
      [switch]$nociscat_remediation,[switch]$nodefaults,[switch]$nofirewall_managed,[switch]$noflexera,
      [switch]$nohpomi,[switch]$nonetbackup,[switch]$nonetwork_managed,[switch]$noqualys,[switch]$noslb_certs)
if ($help){ Get-Help $MyInvocation.MyCommand.Definition ; return }

# this checks to see if this script was called with no parameters
if ( $PSBoundParameters.Values.Count -eq 0 -and $args.count -eq 0 ){ 
    write-output "No Arguments passed , using script defaults in variables hardcoded into the script"
        #ADJOIN needs to be True or False , It's default is False if missing
        $ADJOIN= $False
        # adreplace will automaticallty remove AD account if it already exists
        $adreplace= $False
        # AUTOACCEPT set to $True will upload servername to nexus for minion join automation 
        $autoaccept= $False
        # ENVIRONMENT This is used for testing environments in salt leeave it at 'default' unless you need to set it to test salt environments
        $ENVIRONMENT=''
        $FORCE=$False
        #LOCALREPO is a setting to test locarepo, It will 
        #          copy agents to local folder
        #          set localrepo grain to true
        $LOCALREPO = $False
        # MINIONNAME is the name of the minion, usually computer name, leave blank to use default
        $MINIONNAME=''
        # NEXUSREPO is the nexus repo ip and port , leave black to use default
        $NEXUSREPO=''
        # NOREPO will added hosts entry for slitrepo.it.slb.com to 127.0.0.1
        # If you set this to True while LOCALREPO is False you will get lots of failures
        # as the Nexus will not be avaialable and you won't have local copies of Agents
        $NOREPO = $False
        # Setting REINSTALL to $True will reinstall salt-minion uf ut's already installed
        $REINSTALL = $False
        # SALTMASTER is Salt Master Server IP
        # SaltMaster Ip's
        # Dev and Beta are for special cases almost all servers should be in AZR or GCP based on cloud that server is in
        # SaltDev 10.196.144.208
        # SaltBeta 10.196.184.9
        # AZR 10.192.255.36
        # GCP 10.196.184.4
        # masterless for masterless salt
        # you need to set an IP hwere for the script to work
        $SALTMASTER = 'x.x.x.x'
        # STATEFUL is whether machine is stateful and run post deployment configuration management
        $STATEFUL   = $False
        $postdeployonly=$False
        #Turn on/off software individualy, True to Install
        $bigfix=$False
        $ciscat_eval=$False
        $ciscat_remediation=$False
        $firewall_managed=$True
        $network_managed=$True
        $flexera=$False
        $hpomi=$False
        $netbackup=$False
        $qualys=$False
        $slb_certs=$True
    }

$MINIONNAME_default = $env:COMPUTERNAME.ToLower()
$NEXUSREPO_default   = '10.196.184.8:8443'
$ErrorActionPreference = "Continue"
$osver = [environment]::OSVersion.Version

if ( -not $NEXUSREPO ){ $NEXUSREPO = $NEXUSREPO_default }
if ( -not $MINIONNAME ){ $MINIONNAME = $MINIONNAME_default}

if ( -not $masterless_zip ) { $LOCALSALT="https://$NEXUSREPO/repository/raw-salt-nobrowse/salt/masterless/salt.zip" }
else { $LOCALSALT= $masterless_zip } 
if ( $py2 ) { $minionlocation =  "https://$NEXUSREPO/repository/proxy-salt-raw/windows/Salt-Minion-$saltver-Py2-AMD64-Setup.exe" }
else   { $minionlocation =  "https://$NEXUSREPO/repository/proxy-salt-raw/windows/Salt-Minion-$saltver-Py3-AMD64-Setup.exe"   }     

$REPOFILES = @{}
$REPOFILES.Add("bigfix",@{source_folder = "/repository/raw-slit/besclient/windows/" ; dest = 'c:\salt\srv\localrepo\bigfix\' ; files = @("BESRemove9.5.11.191.exe","BigFix-BES-Client-9.5.11.191.exe")})
$REPOFILES.Add("flexera",@{source_folder = "/repository/raw-slit/flexera/windows/" ; dest = 'c:\salt\srv\localrepo\flexera\' ; files = @('FlexAgent.zip')})
$REPOFILES.Add("hpomi",@{source_folder = "/repository/raw-slit/hpom/windows/12.05/" ; dest = 'c:\salt\srv\localrepo\hpomi\' ; files = @('OA_12.05-WIN64.zip')})
$REPOFILES.Add("netbackup",@{source_folder = "/repository/raw-slit/netbackup/windows/" ; dest = 'c:\salt\srv\localrepo\netbackup\' ; files = @('Netbackup_8.1.zip')})
$REPOFILES.Add("qualys",@{source_folder = "/repository/raw-slit/qualys/windows/" ; dest = 'c:\salt\srv\localrepo\qualys\' ; files = @('QualysCloudAgent.exe')})

$MinionMap = @{}
# Add more maapings as masters are added
$MinionMap.Add("xx.xx.xx.xx","Master 1")

if ($MinionMap[$saltmaster]) { $mastername=$MinionMap[$saltmaster] }
else { $mastername="unknown" }

# Added this log function to put a log of Salt Install in C:\Users\Public\Documents\salt-agent-deploy.log
function Write-Log 
{ 
    [CmdletBinding()] 
    Param 
    ( 
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 
 
        [Parameter(Mandatory=$false)] 
        [Alias('LogPath')] 
        [string]$Path="C:\Users\Public\Documents\salt-minion-deployment.log", 
         
        [Parameter(Mandatory=$false)] 
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level="Info", 
         
        [Parameter(Mandatory=$false)] 
        [switch]$NoClobber 
    ) 
 
    Begin 
    { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        #$VerbosePreference = 'Continue' 
    } 
    Process 
    { 
         
        $ErrorActionPreference = "Continue"
        # If the file already exists and NoClobber was specified, do not write to the log. 
        if ((Test-Path $Path) -AND $NoClobber) { 
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
            Return 
            } 
 
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
        elseif (!(Test-Path $Path)) { 
            Write-Verbose "Creating $Path." 
            New-Item $Path -Force -ItemType File 
            } 
 
        else { 
            # Nothing to see here yet. 
            } 
 
        # Format Date for our Log File 
        $FormattedDate = Get-Date -Format "yyyyMMddHH.mmss" 
 
        # Write message to error, warning, or verbose pipeline and specify $LevelText 
        switch ($Level) { 
            'Error' { 
                Write-Error $Message 
                $LevelText = 'ERROR:' 
                } 
            'Warn' { 
                Write-Warning $Message 
                $LevelText = 'WARNING:' 
                } 
            'Info' { 
                Write-Verbose $Message 
                $LevelText = 'INFO:' 
                } 
            } 
         
        # Write log entry to $Path 
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append 
    } 
    End 
    { 
    } 
}

# Do not Deploy if Salt is already on the system
if ([System.IO.File]::Exists("c:\salt\bin\python.exe")) {
    Write-output "nothing to do - Salt is already installed" 
    exit 0
}

Write-log -level warn "Starting Salt Deployment script Ver $VER"

if ( $PSBoundParameters.Values.Count -eq 0 -and $args.count -eq 0 ){ 
    write-log -level warn "No Arguments passed , using script defaults"}

if ( ( $defaults -or $stateful -or $postdeployonly ) -and -not $nodefaults -and -not $minimal ) {
        if ( $defaults ) { Write-Log -Level Warn "defaults set to True so all software installs set to True" }
        else { Write-Log -Level Warn "stateful true and no software selected so all software installs set to True" }
        $adjoin=$True
        $adreplace=$True
        $bigfix=$True
        $ciscat_eval=$True
        $ciscat_remediation=$True
        $firewall_managed=$True
        $flexera=$True
        $hpomi=$True
        $netbackup=$True
        $network_managed=$True
        $qualys=$True
        $slb_certs=$True
    }

    if ($SALTMASTER -eq "masterless" ){
        $adjoin=$False
        $adreplace=$False
        $network_managed=$True
        $firewall_managed=$True
        $slb_certs=$True
        if ( -not $minimal ){
            $bigfix=$True
            $ciscat_eval=$True
            $ciscat_remediation=$True
            $flexera=$True
            $hpomi=$True
            $netbackup=$False
            $qualys=$True
        }
    }

if ( $minimal ){
    #$adjoin=$True
    #$adreplace=$True
    #$bigfix=$True
    #$ciscat_eval=$True
    #$ciscat_remediation=$True
    $firewall_managed=$True
    #$flexera=$True
    #$hpomi=$True
    #$netbackup=$True
    $network_managed=$True
    #$qualys=$True
    $slb_certs=$True
    $postdeployonly=$True
}
    
if ( $nodefaults ) {
        Write-Log -Level Warn "nodefaults set all software installs set to False , this can cause issues on the build if you do not select essential packages" 
    }

if ( $noextendedapps )         { $extendedapps = $False }
else { $extendedapps = $True }
if ( $nostateful )             { $stateful = $False }
if ( $notstateful )            { $stateful = $False }
if ( $noadjoin )               { $adjoin = $False }
if ( $noadreplace )            { $adreplace = $False }
if ( $noautoaccept )           { $autoaccept = $False }
if ( $nobigfix )               { $bigfix = $False }
if ( $nociscat_eval )          { $ciscat_eval = $False }
if ( $nociscat_remediation )   { $ciscat_remediation = $False }
if ( $nofirewall_managed )     { $firewall_managed = $False }
if ( $noflexera )              { $flexera = $False }
if ( $nohpomi )                { $hpomi = $False }
if ( $nonetbackup )            { $netbackup = $False }
if ( $nonetwork_managed )      { $network_managed = $False }
if ( $noqualys )               { $qualys = $False }
if ( $noslb_certs )            { $slb_certs = $False }

if ( -not $NEXUSREPO ){ $NEXUSREPO = $NEXUSREPO_default }
if ( -not $MINIONNAME ){ $MINIONNAME = $MINIONNAME_default}
if ( $debug ){ write-output ($PSBoundParameters) }

if ( $args.count -ne 0 ){
    write-log -level warn ("ERROR: Unknown agruments passed, '$args'")
    return 1
    }  

Write-log -level warn "saltmaster=$saltmaster MINIONNAME=$MINIONNAME stateful=$stateful postdeployonly=$postdeployonly  minimal=$minimal"
Write-log -level warn "postdeploydebug=$postdeploydebug testfail=$testfail extendedapps=$extendedapps ssr=$ssr saltver=$saltver"
Write-log -level warn "environment=$environment autoaccept=$autoaccept NEXUSREPO=$NEXUSREPO py2=$py2 saltmanaged=$saltmanaged"
Write-log -level warn "dryrun=$dryrun verbose=$verbose norepo=$norepo localrepo=$localrepo emailalways=$emailalways noreboots=$noreboots"
if ($SALTMASTER -eq "masterless" ){
    Write-log -level warn "masterless_zip=$masterless_zip"
    Write-log -level warn "masterlesstimeout=$masterlesstimeout"
    Write-log -level warn "LOCALSALT=$LOCALSALT" 
}
Write-log -level warn "runjobs=$runjobs"
Write-log -level warn "adjoin=$adjoin adreplace=$adreplace  bigfix=$bigfix ciscat_eval=$ciscat_eval ciscat_remediation=$ciscat_remediation "
Write-log -level warn "firewall_managed=$firewall_managed flexera=$flexera hpomi=$hpomi netbackup=$netbackup uft=$uft"
Write-log -level warn "network_managed=$network_managed qualys=$qualys slb_certs=$slb_certs"

if ( $SALTMASTER -eq 'x.x.x.x' -or $SALTMASTER -eq 'undefined' -or $SALTMASTER -eq '<master_ip_address>' ) {
    Write-log -level warn "FAILED - master ($SALTMASTER) needs to be assigned a master ip address or set to masterless, please fix and rerun script, exiting script."
    exit 1
  }
  
  if ( $ssr -eq '<ssr_id>' ) {
    Write-log -level warn "FAILED - ssr ($ssr) needs to be a proper SSR, please fix and rerun script, exiting script."
    exit 1
  }
  

$portfailed=$False
#https://learn-powershell.net/2013/03/14/get-available-constructors-using-powershell/
# For 2008 R2 or older use this .NET Call
$ErrorActionPreference = "Continue"
For ($i=0; $i -le 5; $i++) {
	if ($SALTMASTER -ne "masterless" ) {
		$result=New-Object Net.Sockets.TCPClient -ArgumentList $SALTMASTER,4505
		if (! $result.connected) {
		Write-log -level warn "Failed to connect to salt master $SALTMASTER port 4505"
		$portfailed=$False
		}
	}
	
	if ($SALTMASTER -ne "masterless" ) {
		$result=New-Object Net.Sockets.TCPClient -ArgumentList $SALTMASTER,4506
		if (! $result.connected) {
		Write-log -level warn "Failed to connect to salt master $SALTMASTER port 4506"
		$portfailed=$False
		}
	}
	$NEXUSIP= $NEXUSREPO.split(":")[0]
	$result=New-Object Net.Sockets.TCPClient -ArgumentList $NEXUSIP,8443
	if (! $result.connected) {
	Write-log -level warn "Failed to connect to Nexus repo $NEXUSIP port 8443"
	$portfailed=$True
	}
	if ($portfailed ) {
		Write-log -level warn "Network Failure Retrying in 15 seconds, Attempt $i of 5"
		start-sleep -seconds 15
		continue
	}
	break
}

if ( $portfailed ) {
    if ($FORCE) {
        Write-log -level warn "FAILED - network connection failure, FORCE is True, so attempting agent install"
    }
    else {
        Write-log -level warn "FAILED - network connection failure, exiting"
        exit 1
    }
}

#This downloads the Salt install to Temp
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } 
$webclient = New-Object system.net.webclient
$tempfolder = $env:TEMP
Write-log -level warn "Downloading Salt Minion to $tempfolder"

$webclient.DownloadFile($minionlocation, "$tempfolder\saltminion.exe") 
#$webclient.DownloadFile("https://$NEXUSREPO/repository/raw-slit/salt/win/Salt-Minion-3001.1-Py3-AMD64-Setup.exe", "$tempfolder\saltminion.exe") 
#$webclient.DownloadFile("https://$NEXUSREPO/repository/raw-slit/salt/win/Salt-Minion-2019.2.6-Py2-AMD64-Setup.exe", "$tempfolder\saltminion.exe") 
if (![System.IO.File]::Exists("$tempfolder\saltminion.exe")) {
    Write-log -level warn "FAILED - Failed to find $tempfolder\saltminion.exe , was supposed to download from https://$NEXUSREPO/repository/raw-slit/salt/win/Salt-Minion-3001.1-Py3-AMD64-Setup.exe, please investigate, exiting script."
    exit 1
}
new-item -Path "C:\ProgramData\Salt Project\Salt\conf" -itemtype directory
new-item -Path "C:\ProgramData\Salt Project\Salt\conf\minion.d" -itemtype directory
# the std_stateful is needed so the standard state will be applied
$GRAINS = @"
postdeploy:
  adjoin: $ADJOIN
  adreplace: $adreplace
  bigfix: $bigfix
  ciscat_eval: $ciscat_eval
  ciscat_remediation: $ciscat_remediation
  deploydate: $(Get-Date -Format "yyyyMMddHH.mmss")
  emailalways: $emailalways
  extendedapps: $extendedapps
  failtest: $failtest
  firewall_managed: $firewall_managed
  flexera: $flexera
  hpomi: $hpomi
  localrepo: $LOCALREPO
  netbackup: $netbackup
  network_managed: $network_managed
  notificationemail: '$notificationemail'
  noreboots: $noreboots
  postdeploydebug: $postdeploydebug
  postdeployonly: $postdeployonly
  qualys: $qualys
  runjobs: '$runjobs'
  saltmanaged: $saltmanaged
  slb_certs: $slb_certs
  ssr: $ssr
  stateful: $STATEFUL
  uft: $uft
"@
Set-Content "C:\ProgramData\Salt Project\Salt\conf\grains" $GRAINS

if ($SALTMASTER -eq "masterless") {
    $LOCALCONF = @"
file_client: local
file_roots:
  base:
    - 'c:\salt\srv\salt'
pillar_roots:
  base:
    - 'c:\salt\srv\salt\pillar'   
winrepo_dir: 'c:\salt\srv\salt\win\repo'
winrepo_dir_ng: 'c:\salt\srv\salt\win\repo-ng'
"@
    Set-Content "C:\ProgramData\Salt Project\Salt\conf\minion.d\salt_local.conf" $LOCALCONF
$MINIONCONF = @"
id: $MINIONNAME
master: localhost
tcp_keepalive: True
tcp_keepalive_idle: 60
"@
    }
else {
        $MINIONCONF = @"
id: $MINIONNAME
master: $SALTMASTER
tcp_keepalive: True
tcp_keepalive_idle: 60
"@
    }

if ( $ENVIRONMENT -ne "default" ) { 
    Write-Log -level warn  "Setting environment to $ENVIRONMENT in  C:\ProgramData\Salt Project\Salt\conf\minion.d\minion.conf"
    $MINIONCONF += "`r`n"+ "saltenv: "+ $ENVIRONMENT
}
 
Set-Content "C:\ProgramData\Salt Project\Salt\conf\minion.d\minion.conf" $MINIONCONF
#Start-Process -FilePath $tempfolder'\saltminion.exe' -ArgumentList '/S' -WorkingDirectory 'c:\' -Wait
Start-Process -FilePath $tempfolder'\saltminion.exe' -ArgumentList "/S", /install-dir="C:\salt" -Wait

New-Item -ItemType SymbolicLink -Path "C:\salt\conf" -Target "C:\ProgramData\Salt Project\Salt\conf"
New-Item -ItemType SymbolicLink -Path "C:\salt\var" -Target "C:\ProgramData\Salt Project\Salt\var"

sleep 5
if (-not (Get-Service 'salt-minion'  -ErrorAction SilentlyContinue)) {
    Write-log -level warn "Did not find salt-minion service , sleeping 30 seonds and retrying."
    sleep 30
    if (-not (Get-Service 'salt-minion'  -ErrorAction SilentlyContinue)) {
        Write-log -level warn "FAILED - Did not find salt-minion service."
        Write-log -level warn "removing c:\salt because salt installed failed"
        Remove-Item -Path c:\test123 -Force -Recurse
        Write-log -level warn "FAILED - Salt Minion Failed to Install, please investigate, exiting script."
        exit 1
    }
}
#if (![System.IO.File]::Exists("c:\salt\bin\python.exe")) {
#    Write-log -level warn "removing c:\salt because salt installed failed"
#    rd /s /q c:\salt
#    Write-log -level warn "FAILED - Salt Minion Failed to Install, please investigate, exiting script."
#    exit 1
#}
     
if ($LOCALREPO) {
        Write-log -level warn $("LOCALREPO is True, Performing Post configuration tasks")
        Write-log -level warn $("Copying down files for localrepo test")
    ForEach($sw in $REPOFILES.Keys){
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } 
        $webclient = New-Object system.net.webclient
        Write-log -level warn $("Downloading $file to "+ $REPOFILES[$sw].dest.ToString()+$file)
        foreach($file in $REPOFILES[$sw].files){
            #echo "https://"+$NEXUSREPO + $REPOFILES[$sw].source_folder.ToString()+$file
            If(!(test-path $($REPOFILES[$sw].dest.ToString()))) { 
                Write-log -level warn "Creating folder $($REPOFILES[$sw].dest.ToString())"
                New-Item -ItemType directory -Path $($REPOFILES[$sw].dest.ToString())  | Out-Null
                }
            Write-log -level warn $("Downloading "+ "https://" + $NEXUSREPO + $REPOFILES[$sw].source_folder.ToString()+$file +" to "+ $REPOFILES[$sw].dest.ToString() + $file )
            $webclient.DownloadFile($("https://"+$NEXUSREPO + $REPOFILES[$sw].source_folder.ToString()+$file), $($REPOFILES[$sw].dest.ToString()+$file)) 
            }
        }
    }   

if ($NOREPO) {
        Write-log -level warn $("NOREPO Set Rue, Adding host entry to c:\windows\system32\drivers\etc\hosts for slitrepo.it.slb.com to simulate failure")
        Add-Content c:\windows\system32\drivers\etc\hosts "127.0.0.1 localhost slitrepo.it.slb.com"
    }

if ($SALTMASTER -eq "masterless") {
    Write-log -level warn "SALMASTER is set to masterless, Downloading localized salt root $LOCALSALT to temp folder $tempfolder"
    #oldzip "https://$NEXUSREPO/repository/raw-slit/salt/standalone/salt.zip"
    $webclient.DownloadFile($LOCALSALT, "$tempfolder\salt.zip") 
    mkdir C:\salt\srv\salt
    Write-log -level warn "UnZipping salt root to c:\salt\srv\salt"
    Expand-Archive -LiteralPath "$tempfolder\salt.zip" "c:\salt\srv\salt"
    Write-log -level warn "Salt saltutil.sync_all running"
    start-process -wait c:\salt\salt-call saltutil.sync_all
    Write-log -level warn "running salt-call pkg.refresh_db"
    start-process -wait c:\salt\salt-call pkg.refresh_db
    Write-log -level warn "Salt applying standardconf.masterless configuration, Details after the run will be in log C:\Users\Public\Documents\salt-postdeploy.log"
    Write-log -level warn "Warnings and Errors will show up in log C:\Users\Public\Documents\salt-postdeploy-error.log and C:\salt\var\log\salt\minion"
    Write-log -level warn "Progress can be veiwed at C:\salt\var\log\salt\states\postdeploy.log"
    Write-log -level warn "This process can take from 5 to 55 minutes, depending on packages installed, like UFT or the Backup Client"
    stop-service "salt-minion"
    $runobj = start-process -PassThru -FilePath "c:\salt\bin\python.exe" -ArgumentList "-E","-s","c:\salt\bin\Scripts\salt-call","state.apply","standardconf.masterless ""pillar={""standardconfcalled"": True}`" " -RedirectStandardOutput C:\Users\Public\Documents\salt-postdeploy.log -RedirectStandardError C:\Users\Public\Documents\salt-postdeploy-error.log
    Write-log -level warn "running salt-call state.apply standardconf.masterless  at $(Get-Date -Format "HH:mm:ss" ) PID is $($runobj.id) with a timeout of $masterlesstimeout"
    wait-process -id $runobj.id -timeout $masterlesstimeout
    #start-process -wait -FilePath "c:\salt\bin\python.exe" -ArgumentList "-E","-s","c:\salt\bin\Scripts\salt-call","state.apply","standardconf.masterless ""pillar={""standardconfcalled"": True}`" " -RedirectStandardOutput C:\Users\Public\Documents\salt-postdeploy.log -RedirectStandardError C:\Users\Public\Documents\salt-postdeploy-error.log
    #start-process -wait c:\salt\salt-call "state.apply standardconf.masterless ""pillar={""standardconfcalled"": True}"" " -RedirectStandardOutput C:\Users\Public\Documents\salt-postdeploy.log -RedirectStandardError C:\Users\Public\Documents\salt-postdeploy-error.log
    if ( -not $runobj.HasExited ){
        Write-log -level warn "Masterless Deployment failed. at $(Get-Date -Format "HH:mm:ss" )"
        Write-log -level warn "masterlesstimeout of $masterlesstimeout seconds expired."
        Write-log -level warn "Process $($runobj.id) did not finish, It may still be running on the background."
        Write-log -level warn "-------------------------------------------"
        Write-log -level warn "Exiting addminion minion bootsrap script"
        Write-log -level warn "-------------------------------------------"
        exit 2
    }
    else {
        Write-log -level warn "Masterless Deployment completed at $(Get-Date -Format "HH:mm:ss" )"
    }
}

if ($SALTMASTER -ne "masterless" -and $autoaccept ) {
    Write-log -level warn "Autoaccept set to True, Will check to see if old keys need to be deleted off master $mastername"
    $minionlist=''
    if ( $mastername -ne "unknown" ){
        $ErrorActionPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } 
        $minionlist=(new-object System.Net.WebClient).DownloadString("https://"+$NEXUSREPO+"/repository/raw-salt-queue/minionlist/"+$mastername+"_minions.txt")
        $ErrorActionPreference = 'Continue'
        #minionlist=$(curl --insecure 'https://'$NEXUSREPO'/repository/raw-salt-queue/minionlist/'$mastername'_minions.txt')
    }
    #Write-log -level warn "Checking minion list on $mastername to see if minion needs to be deleted"
    $minionarr=$minionlist.split(',')
    if ($minionarr -contains $MINIONNAME) {
        Write-log -level warn "we found minion $MINIONNAME on the master, we are calling delete for the existing key"
        $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes('saltqueueupload:K9bfHcn9pBn34D'))
        $Headers = @{Authorization = "Basic $encodedCreds"}
        $ultext="name: $MINIONNAME`r`ndate: $(date)`r`naction: Delete Key`r`nOS:Windows"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } 
        Invoke-RestMethod -Headers $Headers -Uri "https://$NEXUSREPO/repository/raw-salt-queue/deleteminion/$MINIONNAME" -Method Put -Body $ultext  -ContentType "text/plain"
        Write-log -level warn  "Created file /raw-salt-queue/deleteminion/$NEWHOST , now waiting for delete to finish, will wait 2 minutes"
        For ($i=0; $i -le 100; $i++) {
            $object=''
            $ErrorActionPreference = 'SilentlyContinue'
            $object=(new-object System.Net.WebClient).DownloadString("https://$NEXUSREPO/repository/raw-salt-queue/deleteminion/$MINIONNAME") 
            $ErrorActionPreference = 'Continue'
            # when the minion is deleted it removes the machine object from the folder
            if ( -not $object){ break }
            Start-Sleep -Seconds 1.5
        }
        if ( -not $object){
            Write-log -level warn  "Deltetion completed for minion $MINIONNAME on master $mastername"
        }
        else {
            Write-log -level warn  "Deletion failed for minion $MINIONNAME on master $mastername, we can still see marker file https://$NEXUSREPO/repository/raw-salt-queue/deleteminion/$NEWHOST , talk to salt amdins"
        }
    
    }
    Write-log -level warn "Autoaccept set to True, Uploading success marker to nexus location /raw-temp/salt-temp/addminion/"
    #This will upload a marker file to the Repo server that will join server key to Salt 
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes('saltqueueupload:K9bfHcn9pBn34D'))
    $Headers = @{Authorization = "Basic $encodedCreds"}
    $ultext="Automated Salt deployment`r`nDate:$(Get-Date)`r`nName:$MINIONNAME`r`nOS:Windows"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } 
    Invoke-RestMethod -Headers $Headers -Uri "https://$NEXUSREPO/repository/raw-salt-queue/addminion/$MINIONNAME" -Method Put -Body $ultext  -ContentType "text/plain"
}

if ( $dryrun ) {
    Write-log -level warn "Dryrun is True, stopping salt-minion"
    Stop-Service -Name "salt-minion"
}

Write-log -level warn "-------------------------------------------"
Write-log -level warn "Installation of SaltMinion was successful!"
Write-log -level warn "-------------------------------------------"
exit 0