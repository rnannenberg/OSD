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
Write-Host -ForegroundColor Green "Install Modules"
Install-Module -Name PowerShellGet > $null
Install-Module -Name PSADT -Force > $null
If ((Test-Battery -PassThru).IsUsingACPower -ne "True") {
    Write-Host -ForegroundColor Red "Please insert AC Power, installation might fail if on battery"
    Start-Sleep -Seconds 60
}
Start-Sleep -Seconds 5

#================================================
#   [OS] Start-OSDCloud with Params
#================================================
Start-OSDCloud -ZTI -OSVersion 'Windows 11' -OSBuild 22H2 -OSEdition Enterprise -OSLanguage en-us -OSLicense Volume

#================================================
#   [OS] Check WiFi and export profile
#================================================ 
$XmlDirectory = "C:\Windows\Setup\Scripts"
$wifilist = $(netsh.exe wlan show profiles)
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
# Check IF VM and install things
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\VM.ps1
# Below a PS 7 session for debug and testing in system context, # when not needed 
#start /wait pwsh.exe -NoL -ExecutionPolicy Bypass
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
Install-Module -Name PowerShellGet | Out-Null
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
'@
$OOBEpsTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\ps.ps1' -Encoding ascii -Force

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
Install-Module -Name PowerShellGet | Out-Null
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
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-PowerShell.log"
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
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
If ((Get-CimInstance -ClassName Win32_BIOS).Manufacturer -eq "HP") {
    $Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-HPRevovery.log"
    $null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
    Write-Host -ForegroundColor Green "Install HPCMSL Module"
    Install-Module -Name HPCMSL -Force -AcceptLicens
    Start-Sleep -Seconds 10
    write-host "HP Bios settings check revovery settings" -ForegroundColor Green
    If ((Get-HPSecurePlatformState).State -eq "Provisioned") {
    
    }
}
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
Write-Host -ForegroundColor Green "Install HPCMSL Module"
Install-Module -Name HPCMSL -Force -AcceptLicens | Out-Null
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
