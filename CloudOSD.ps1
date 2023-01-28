#================================================
#   OSDCloud Task Sequence
#   Windows 11 22H2 Enterprise us Volume
#   No Autopilot
#   No Office Deployment Tool
#================================================
$Title = "Windows OSD phase"
$host.UI.RawUI.WindowTitle = $Title
Write-Host -ForegroundColor Green "Starting OSDCloud ZTI"

#================================================
#   Change the ErrorActionPreference
#   to 'SilentlyContinue' Or 'Continue'
#================================================
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = "SilentlyContinue"
#$ErrorActionPreference = 'Continue'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
If (([Windows.Forms.SystemInformation]::PowerStatus).PowerLineStatus -ne "Online") {
    Write-Host -ForegroundColor Red "Please insert AC Power, installation might fail if on battery"
    Start-Sleep -Seconds 60
}

Start-Sleep -Seconds 5

#================================================
#   [OS] Start-OSDCloud with Params
#================================================
Start-OSDCloud -ZTI -OSVersion 'Windows 11' -OSBuild 22H2 -OSEdition Enterprise -OSLanguage en-us -OSLicense Volume

#================================================
#   [OS] Check for WinPE WiFi and export profiles
#================================================ 
$XmlDirectory = "C:\Windows\Setup\Scripts"
$wifilist = $(netsh.exe wlan show profiles)
Install-Module -Name VcRedist -Force | Out-Null
if ($null -ne $wifilist -and $wifilist -like 'Profiles on interface Wi-Fi*') {
    $ListOfSSID = ($wifilist | Select-string -pattern "\w*All User Profile.*: (.*)" -allmatches).Matches | ForEach-Object {$_.Groups[1].Value}
    $NumberOfWifi = $ListOfSSID.count
    foreach ($SSID in $ListOfSSID){
        try {
            Write-Host -ForegroundColor green "Exporting WiFi SSID:$SSID"
            $XML = $(netsh.exe wlan export profile name=`"$SSID`" key=clear folder=`"$XmlDirectory`")
            }
            catch [System.Exception] {
                Write-Host -ForegroundColor Red "Failed export of Wifi on system"
                Write-Host -ForegroundColor Red "The error is: $XML"
            }
        }
    }
    Else {
        Write-Host -ForegroundColor Yellow $wifilist
    }

#================================================
#  WinPE PostOS
#  oobe.cmd
#================================================
Write-Host -ForegroundColor Green "Creating Scripts for OOBE phase"
$OOBEcmdTasks = @'
@echo off
# Import WiFi XML's if they exist
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\wifi.ps1
# Download and Install PowerShell 7
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\ps.ps1
# Download and Install .Net Framework 7
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\net.ps1
# VcRedist Download and install supported versions
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\VcRedist.ps1
# Check IF VM and install things
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\VM.ps1
# Check IF HP and install things en change the HP Recovery
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\bios.ps1
# Below a PS 7 session for debug and testing in system context, # when not needed 
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\oobe.ps1
exit 
'@
$OOBEcmdTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\oobe.cmd' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  ps.ps1
#================================================
$OOBEpsTasks = @'
$Title = "OOBE PowerShell 7 Download and install"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
write-host "PowerShell 7 Download and install" -ForegroundColor Green
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-PowerShell.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
Install-Module -Name PowerShellGet -Force | Out-Null
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
'@
$OOBEpsTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\ps.ps1' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  VcRedist.ps1
#================================================
$OOBEpsTasks = @'
$Title = "OOBE VcRedist Download and install supported versions"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
write-host "VcRedist Download and install supported versions" -ForegroundColor Green
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-VcRedist.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
Install-Module -Name PowerShellGet -Force | Out-Null
Install-Module -Name VcRedist -Force | Out-Null
iex "& { $(irm https://vcredist.com/install.ps1) }" | Out-Null
'@
$OOBEpsTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\VcRedist.ps1' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  wifi.ps1
#================================================
$OOBEnetTasks = @'
$Title = "OOBE Add WiFi SSID's to the system if exist"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
write-host "Searching for saved WifI networks" -ForegroundColor Green
$XmlDirectory = "C:\Windows\Setup\Scripts"
$XMLExist = Get-ChildItem -Path $XmlDirectory -Filter '*.xml' -File
If (![String]::IsNullOrEmpty($XMLExist)) {
    Start-Service -Name "WlanSvc"
    Get-ChildItem $XmlDirectory | Where-Object {$_.extension -eq ".xml"} | ForEach-Object {
        write-host "Importing WifI network: $_.name" -ForegroundColor Green
        netsh wlan add profile filename=($XmlDirectory+"\"+$_.name)
    }
    Else {
    write-host "No WiFi profiles found to import" -ForegroundColor Yellow
    }
}
Start-Sleep -Seconds 10
'@
$OOBEnetTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\wifi.ps1' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  net.ps1
#================================================
$OOBEnetTasks = @'
$Title = "OOBE .Net Framework 7 Download and install"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
write-host ".Net Framework 7 Download and install" -ForegroundColor Green
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Framework.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
Install-Module -Name PowerShellGet -Force | Out-Null
iex "& { $(irm https://dot.net/v1/dotnet-install.ps1) } -Channel STS -Runtime windowsdesktop"
'@
$OOBEnetTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\net.ps1' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  vm.ps1
#================================================
$OOBEpsTasks = @'
$Title = "Check if machine is a VM"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-VM.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
If ((Get-CimInstance -ClassName Win32_computersystem).model -like "VMware*") {
    write-host "Checking latest VMware tools" -ForegroundColor Green
    $vmwareTools = "https://packages.vmware.com/tools/esx/latest/windows/x64/index.html"
    $pattern = "[0-9]+\.[0-9]+\.[0-9]+\-[0-9]+\-x86_64"
    
    #get the raw page content
    $pageContent=(Invoke-WebRequest -UseBasicParsing -Uri $vmwareTools).content
    
    #change one big string into many strings, then find only the line with the version number
    $interestingLine = ($pageContent.split("`n") | Select-string -Pattern $pattern).tostring().trim()
 
    #remove the whitespace and split on the assignment operator, then split on the double quote and select the correct item
    $filename = (($interestingLine.Replace(" ","").Split("=") | Select-string -Pattern $pattern).ToString().Trim().Split("`""))[1]
 
    $url = "https://packages.vmware.com/tools/esx/latest/windows/x64/$($filename)"
    write-host "Downloading and installing $url"
    Invoke-WebRequest -Uri $url -OutFile "C:\Windows\Temp\$filename"
    $params = "/S /v /qn REBOOT=R ADDLOCAL=ALL"
    Start-Process -Wait -NoNewWindow -FilePath "C:\Windows\Temp\$filename" -ArgumentList $params
}
'@
$OOBEpsTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\vm.ps1' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  Bios.ps1
#================================================
$OOBEnetTasks = @'
$Title = "Check Bios settings"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-bios.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
If ((Get-CimInstance -ClassName Win32_BIOS).Manufacturer -eq "HP") {
    $SPEndorsementKeyPP = "{"timestamp":"\/Date(1674900749911)\/","purpose":"hp:provision:endorsementkey","Data":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,48,130,3,195,48,130,2,171,160,3,2,1,2,2,20,36,160,29,116,255,64,43,11,232,132,190,58,209,122,72,211,197,134,164,22,48,13,6,9,42,134,72,134,247,13,1,1,11,5,0,48,113,49,11,48,9,6,3,85,4,6,19,2,78,76,49,11,48,9,6,3,85,4,8,12,2,78,72,49,20,48,18,6,3,85,4,7,12,11,78,101,116,104,101,114,108,97,110,100,115,49,28,48,26,6,3,85,4,10,12,19,68,101,32,78,101,100,101,108,97,110,100,115,99,104,101,66,97,110,107,49,12,48,10,6,3,85,4,11,12,3,68,73,84,49,19,48,17,6,3,85,4,3,12,10,119,119,119,46,100,110,98,46,110,108,48,30,23,13,50,51,48,49,50,56,48,56,52,50,52,48,90,23,13,51,51,48,49,50,53,48,56,52,50,52,48,90,48,113,49,11,48,9,6,3,85,4,6,19,2,78,76,49,11,48,9,6,3,85,4,8,12,2,78,72,49,20,48,18,6,3,85,4,7,12,11,78,101,116,104,101,114,108,97,110,100,115,49,28,48,26,6,3,85,4,10,12,19,68,101,32,78,101,100,101,108,97,110,100,115,99,104,101,66,97,110,107,49,12,48,10,6,3,85,4,11,12,3,68,73,84,49,19,48,17,6,3,85,4,3,12,10,119,119,119,46,100,110,98,46,110,108,48,130,1,34,48,13,6,9,42,134,72,134,247,13,1,1,1,5,0,3,130,1,15,0,48,130,1,10,2,130,1,1,0,206,0,155,83,191,119,126,120,116,170,252,170,162,39,175,83,176,141,98,75,65,191,192,137,153,201,97,57,167,142,135,120,208,25,14,6,127,67,169,199,122,240,172,152,251,7,57,13,214,187,43,150,216,150,17,148,214,87,136,95,107,133,123,216,192,170,15,7,66,147,245,180,20,215,163,196,238,242,44,214,7,133,10,217,216,156,84,202,112,43,113,211,102,248,123,224,93,186,95,44,103,3,1,116,39,182,78,53,66,245,119,199,238,190,130,169,134,99,239,232,75,156,45,47,205,254,92,51,120,127,229,48,240,165,122,237,250,86,42,27,76,70,141,188,173,218,131,114,101,101,175,36,197,95,42,175,94,15,10,248,238,8,53,144,6,170,38,133,11,228,90,229,236,94,92,85,69,86,241,100,170,199,192,129,105,176,242,75,223,177,64,124,107,153,239,85,183,99,58,219,75,219,238,64,3,237,17,162,232,170,224,114,4,196,29,161,130,7,81,176,21,113,10,44,231,81,156,237,219,121,164,243,12,55,24,228,223,81,173,85,1,190,143,146,132,178,87,98,30,83,60,204,12,201,157,141,2,3,1,0,1,163,83,48,81,48,29,6,3,85,29,14,4,22,4,20,250,129,84,123,111,176,175,24,241,200,171,204,75,221,186,93,178,162,134,83,48,31,6,3,85,29,35,4,24,48,22,128,20,250,129,84,123,111,176,175,24,241,200,171,204,75,221,186,93,178,162,134,83,48,15,6,3,85,29,19,1,1,255,4,5,48,3,1,1,255,48,13,6,9,42,134,72,134,247,13,1,1,11,5,0,3,130,1,1,0,126,120,236,170,102,234,147,168,152,19,96,140,14,201,217,162,27,84,174,187,111,236,253,240,224,250,219,45,139,10,177,130,201,184,94,238,31,106,56,206,6,42,11,52,82,185,248,223,244,90,253,116,53,3,22,164,2,210,92,172,241,88,90,154,30,150,174,10,223,25,178,238,78,169,181,34,221,34,59,135,235,168,98,209,253,20,143,242,228,110,244,129,204,106,43,27,32,202,133,46,47,239,77,113,232,211,60,98,50,244,113,180,104,5,216,203,253,28,221,76,32,220,186,242,98,17,33,75,49,96,85,172,9,222,75,250,88,220,95,225,155,125,61,25,251,238,211,223,160,19,250,245,230,185,72,63,106,230,1,90,205,199,43,146,51,83,14,12,110,124,148,134,77,110,81,145,233,231,186,39,73,146,255,151,189,247,171,0,174,63,147,207,63,149,207,207,100,201,3,209,199,254,75,33,101,204,200,255,92,70,113,110,252,165,125,82,57,114,5,226,56,210,198,241,221,27,25,175,243,37,2,217,22,66,49,77,163,94,65,199,218,35,208,126,2,166,73,235,32,154,53,106,1,81,50,78],"Meta1":null,"Meta2":null,"Meta3":null,"Meta4":null}"
    $SPSigningKeyPP = "{"timestamp":"\/Date(1674900750133)\/","purpose":"hp:provision:signingkey","Data":[149,80,254,168,248,162,20,0,47,212,233,245,188,68,120,230,52,139,248,201,243,226,62,28,146,219,227,45,106,215,114,31,23,204,231,186,1,97,130,130,50,123,122,41,52,148,237,101,245,75,5,101,81,189,93,47,214,156,150,139,218,1,105,116,128,228,120,85,22,146,198,237,238,90,192,68,52,10,191,120,248,216,118,71,30,106,71,180,125,24,178,7,36,130,225,61,34,99,250,78,122,5,72,245,203,11,0,121,234,185,92,139,181,96,93,221,54,91,186,150,163,100,173,192,36,123,84,210,47,210,159,4,67,136,233,238,192,247,117,3,17,76,16,254,80,44,76,80,121,39,188,193,248,124,182,33,186,97,214,76,108,3,209,205,207,152,83,126,96,105,186,213,44,207,101,83,137,200,151,249,165,191,254,42,235,159,251,80,161,133,160,104,53,7,233,117,34,136,185,110,58,183,143,214,98,46,149,75,181,196,231,169,17,10,91,178,171,248,114,70,160,77,207,60,128,158,64,34,151,193,182,240,217,222,93,95,93,51,149,228,155,219,203,77,246,42,71,14,141,214,58,72,215,65,57,22,13,245,212,99,127,161,188,108,190,38,51,2,240,51,99,176,189,163,215,146,173,46,107,133,54,9,112,155,97,133,154,58,162,69,20,43,19,69,252,222,40,125,76,122,238,35,22,198,199,137,104,68,51,36,230,129,0,116,145,29,97,25,165,163,15,25,52,64,233,4,230,245,3,144,43,31,70,20,172,127,212,179,238,245,241,24,1,21,52,65,129,35,216,240,36,8,12,142,248,159,14,180,215,200,115,249,108,209,197,206,17,169,130,131,142,36,48,77,105,197,179,153,252,1,79,141,145,134,79,243,149,101,211,223,235,38,133,194,28,191,91,113,100,146,168,70,132,228,247,55,245,200,114,148,194,211,104,144,129,56,202,41,102,196,14,164,71,169,187,244,79,3,250,78,241,148,79,65,31,248,74,137,11,142,71,6,209,156,16,144,130,232,141,84,209,42,91,40,62,1,221,230,176,114,61,239,44,8,84,160,137,9,95,199,211,157,129,189,71,59,47,1,146,157,74,165,7,155,222,19,97,129,201,73,94,97,86,221,176,100,207,74,19,159,184,155,36,231,247,44,126,79,155,34,142,43,2,84,57,178],"Meta1":null,"Meta2":null,"Meta3":null,"Meta4":null}"
    $AgentPayload = "{"timestamp":"\/Date(1674900773165)\/","purpose":"hp:surerecover:provision:recovery_image","Data":[66,30,141,115,117,153,248,136,207,52,70,81,15,254,218,138,62,38,9,64,56,187,95,192,214,75,237,234,154,127,85,243,37,96,49,220,161,122,220,41,206,189,125,45,216,23,113,6,240,6,97,67,73,218,113,167,231,175,189,141,242,209,146,135,138,178,116,203,205,183,113,130,133,252,210,47,122,178,187,33,166,234,172,42,36,224,73,44,237,6,221,138,35,153,4,50,197,204,188,51,92,35,78,207,33,1,103,160,255,122,125,27,157,141,50,182,8,228,154,213,63,60,82,42,127,4,46,98,12,60,174,124,22,254,168,149,82,47,135,17,248,50,6,107,243,217,3,147,188,76,93,61,114,183,165,199,152,217,67,153,213,69,131,130,55,154,35,123,198,120,232,131,76,210,74,155,210,18,205,67,208,10,190,208,138,173,211,10,41,90,171,225,92,43,209,121,134,35,164,237,219,125,81,193,222,180,224,84,237,6,169,225,250,63,3,54,180,212,161,72,77,18,195,29,192,9,96,152,36,244,126,225,169,16,159,69,124,17,198,67,55,114,195,47,90,218,226,179,50,74,5,171,221,43,246,4,36,245,212,99,1,0,139,149,128,98,164,239,109,68,253,226,197,228,58,215,69,72,236,150,216,97,211,126,50,247,19,15,123,130,197,201,44,183,168,205,70,29,61,180,79,108,49,103,33,69,105,166,5,93,66,215,114,85,5,26,129,61,164,153,164,12,196,32,207,137,102,173,118,18,146,211,143,16,75,105,200,34,79,231,196,211,205,102,212,129,247,125,217,59,188,40,166,163,28,140,190,172,165,161,150,219,160,140,235,2,46,193,110,78,188,240,107,65,223,157,1,25,57,145,218,154,54,79,247,132,212,139,215,118,5,155,186,39,187,207,255,185,93,213,69,108,214,98,8,253,77,171,211,241,222,108,35,22,56,105,48,29,24,202,3,99,36,245,177,1,44,3,45,117,22,4,138,212,47,230,158,15,124,185,54,168,87,100,12,147,60,102,32,113,197,18,126,4,5,186,208,203,205,44,205,42,111,1,170,203,16,213,160,88,147,242,32,60,71,108,151,27,138,106,155,215,166,237,131,238,145,44,40,175,217,170,240,179,93,29,225,49,135,32,101,98,113,83,233,81,60,189,207,76,26,45,241,37,209,142,211,194,0,0,104,116,116,112,115,58,47,47,115,116,97,119,115,100,101,112,108,111,121,48,48,49,46,98,108,111,98,46,99,111,114,101,46,119,105,110,100,111,119,115,46,110,101,116,47,111,115,100],"Meta1":null,"Meta2":null,"Meta3":null,"Meta4":null}"
    Write-Host -ForegroundColor Green "Install HPCMSL Module"
    Install-Module -Name HPCMSL -Force -AcceptLicens | Out-Null
    write-host "HP Bios settings check recovery settings" -ForegroundColor Green
    If ((Get-HPSecurePlatformState).State -eq "Provisioned") {
        If ((Get-HPSureRecoverState -All).Agent -eq "@{Url=http://ftp.hp.com/pub/pcbios/CPR; Username=; ProvisioningVersion=0}") {
            write-host "HP Send payload to BIOS" -ForegroundColor Green
            Set-HPSecurePlatformPayload -Payload $SPEndorsementKeyPP
            Set-HPSecurePlatformPayload -Payload $SPSigningKeyPP
            Set-HPSecurePlatformPayload -Payload $AgentPayload  
        }
    }
}
Start-Sleep -Seconds 10
Get-HPSureRecoverState -All
Start-Sleep -Seconds 120
'@
$OOBEnetTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\bios.ps1' -Encoding ascii -Force

#================================================
#   WinPE PostOS
#   oobe.ps1
#================================================
$OOBEPS1Tasks = @'
$Title = "OOBE installation/update phase"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-OOBE.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
write-host "Powershell Version: "$PSVersionTable.PSVersion -ForegroundColor Green

# Change the ErrorActionPreference to 'SilentlyContinue'
#$ErrorActionPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

# Set Environment
Write-Host "Set Environment" -ForegroundColor Green
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
#Define Icons
    $CheckIcon = @{
        Object          = [Char]8730
        ForegroundColor = 'Green'
        NoNewLine       = $true
    }

# Register Powershell Modules and install tools
Write-Host "Register PSGallery" -ForegroundColor Green
Register-PSRepository -Default | Out-Null
Write-Host "Install PackageManagement Module" -ForegroundColor Green
Install-Module -Name PackageManagement -Force | Out-Null
Write-Host "Install PowerShellGet Module" -ForegroundColor Green
Install-Module -Name PowerShellGet -Force | Out-Null
Write-Host -ForegroundColor Green "Install OSD Module"
Install-Module OSD -Force | Out-Null
Write-Host -ForegroundColor Green "Install PSWindowsUpdate Module"
Install-Module PSWindowsUpdate -Force | Out-Null
Start-Sleep -Seconds 5

Clear-Host
# Remove apps from system
Write-Host -ForegroundColor Green "Remove Builtin Apps"
# Create array to hold list of apps to remove 
$appname = @( 
"Microsoft.BingNews"
"Microsoft.BingWeather"
"Microsoft.GamingApp"
"Microsoft.GetHelp"
"Microsoft.Getstarted"
"Microsoft.MicrosoftOfficeHub"
"Microsoft.MicrosoftSolitaireCollection"
"Microsoft.People"
"Microsoft.PowerAutomateDesktop"
"Microsoft.Todos"
"Microsoft.WindowsAlarm"
"Microsoft.windowscommunicationsapps"
"Microsoft.WindowsFeedbackHub"
"Microsoft.WindowsMaps"
"Microsoft.Xbox.TCUI"
"Microsoft.XboxGameOverlay"
"Microsoft.XboxGamingOverlay"
"Microsoft.XboxIdentityProvider"
"Microsoft.XboxSpeechToTextOverlay"
"Microsoft.YourPhone"
"Microsoft.ZuneMusic"
"Microsoft.ZuneVideo"
"MicrosoftTeams"
) 
ForEach($app in $appname){
    try  {
          # Get Package Name
          $AppProvisioningPackageName = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $app } | Select-Object -ExpandProperty PackageName -First 1
          If (![String]::IsNullOrEmpty($AppProvisioningPackageName)) {
            Write-Host "$($AppProvisioningPackageName) found. Attempting removal ... " -NoNewline
          }
          
          # Attempt removeal if Appx is installed
          If (![String]::IsNullOrEmpty($AppProvisioningPackageName)) {
            Write-Host "removing ... " -NoNewline
            $RemoveAppx = Remove-AppxProvisionedPackage -PackageName $AppProvisioningPackageName -Online -AllUsers
          } 
                   
          #Re-check existence
          $AppProvisioningPackageNameReCheck = Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $App }
          If ([string]::IsNullOrEmpty($AppProvisioningPackageNameReCheck) -and ($RemoveAppx.Online -eq $true)) {
                   Write-Host @CheckIcon
                   Write-Host " (Removed)"
            }
        }
           catch [System.Exception] {
               Write-Host " (Failed or $App not on system)"
           }
}
Start-Sleep -Seconds 10

Clear-Host 
Write-Host -ForegroundColor Green "Install .Net Framework 3.x"
$Result = Get-MyWindowsCapability -Match 'NetFX' -Detail
foreach ($Item in $Result) {
    if ($Item.State -eq 'Installed') {
        Write-Host -ForegroundColor DarkGray "$($Item.DisplayName)"
    }
    else {
        Write-Host -ForegroundColor Green "$($Item.DisplayName)"
        $Item | Add-WindowsCapability -Online -ErrorAction Ignore | Out-Null
    }
}
Start-Sleep -Seconds 10

Clear-Host
#Install Driver updates
Write-Host -ForegroundColor Green "Install Drivers from Windows Update"
$UpdateDrivers = $true
if ($UpdateDrivers) {
    Add-WUServiceManager -MicrosoftUpdate -Confirm:$false | Out-Null
    Install-WindowsUpdate -UpdateType Driver -AcceptAll -IgnoreReboot | Out-File "c:\windows\temp\$(get-date -f yyyy-MM-dd)-DriversUpdate.log" -force
}

Clear-Host
#Install Software updates
Write-Host -ForegroundColor Green "Install Windows Updates"
$UpdateWindows = $true
if ($UpdateWindows) {
    Add-WUServiceManager -MicrosoftUpdate -Confirm:$false | Out-Null
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot | Out-File "c:\windows\temp\$(get-date -f yyyy-MM-dd)-WindowsUpdate.log" -force
}
Start-Sleep -Seconds 10

Clear-Host
Write-Host -ForegroundColor Green "OOBE update phase ready, Restarting in 30 seconds!"

Start-Sleep -Seconds 30
Remove-Item C:\Drivers -Force -Recurse | Out-Null
Remove-Item C:\Intel -Force -Recurse | Out-Null
Remove-Item C:\OSDCloud -Force -Recurse | Out-Null
Remove-Item C:\Windows\Setup\Scripts\*.* -Force | Out-Null
Restart-Computer -Force
'@
$OOBEPS1Tasks | Out-File -FilePath 'C:\Windows\Setup\Scripts\oobe.ps1' -Encoding ascii -Force

#================================================
#   [OOBE] Disable Shift F10
#================================================
$Tagpath = "C:\Windows\Setup\Scripts\DisableCMDRequest.TAG"
If(!(test-path $Tagpath))
    {
      New-Item -ItemType file -Force -Path $Tagpath | Out-Null
      Write-Host -ForegroundColor green "OOBE Shift F10 disabled!"
}
#================================================
#   PostOS
#   Restart-Computer
#================================================
Write-Host -ForegroundColor Green "Restarting in 10 seconds!"
Start-Sleep -Seconds 10
wpeutil reboot
