#================================================
#   OSDCloud Task Sequence
#   Windows 11 22H2 Enterprise us Volume
#   No Autopilot
#   No Office Deployment Tool
#================================================
$Title = "Windows OSD phase"
$host.UI.RawUI.WindowTitle = $Title

Write-Host -ForegroundColor Green "Starting OSDCloud ZTI"
Start-Sleep -Seconds 5

#================================================
#   Change the ErrorActionPreference
#   to 'SilentlyContinue'
#================================================
$ErrorActionPreference = 'SilentlyContinue'

#================================================
#   [OS] Start-OSDCloud with Params
#================================================
Start-OSDCloud -ZTI -OSVersion 'Windows 11' -OSBuild 22H2 -OSEdition Enterprise -OSLanguage en-us -OSLicense Volume

#================================================
#  WinPE PostOS
#  oobe.cmd
#================================================
Write-Host -ForegroundColor Green "Creating Scripts for OOBE phase"
$OOBEcmdTasks = @'
@echo off
# Download and Install PowerShell 7
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\ps.ps1
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\net.ps1
# Below a PS 7 session for testing in system context, # when not needed 
#start /wait pwsh.exe -NoL -ExecutionPolicy Bypass
start /wait pwsh.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\oobe.ps1
exit 
'@
$OOBEcmdTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\oobe.cmd' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  ps.ps1
#================================================
$OOBEcmdTasks = @'
$Title = "OOBE PowerShell 7 Download and install"
$host.UI.RawUI.WindowTitle = $Title
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
$OOBEcmdTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\ps.ps1' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  net.ps1
#================================================
$OOBEcmdTasks = @'
$Title = "OOBE .Net Framework 7 Download and install"
$host.UI.RawUI.WindowTitle = $Title
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
$OOBEcmdTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\net.ps1' -Encoding ascii -Force

#================================================
#   WinPE PostOS
#   oobe.ps1
#================================================
$OOBEPS1Tasks = @'
$Title = "OOBE installation/update phase"
$host.UI.RawUI.WindowTitle = $Title
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-OOBE.log"
$null = Start-Transcript -Path (Join-Path "C:\Windows\Temp" $Transcript ) -ErrorAction Ignore
write-host "Powershell Version: "$PSVersionTable.PSVersion -ForegroundColor Green

# Change the ErrorActionPreference to 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

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
"Microsoft.BingNews",
"Microsoft.BingWeather",
"Microsoft.GamingApp",
"Microsoft.GetHelp",
"Microsoft.Getstarted",
"Microsoft.MicrosoftOfficeHub",
"Microsoft.MicrosoftSolitaireCollection",
"Microsoft.People"
"Microsoft.PowerAutomateDesktop",
"Microsoft.Todos",
"Microsoft.WindowsAlarm",
"microsoft.windowscommunicationsapps",
"Microsoft.WindowsFeedbackHub",
"Microsoft.WindowsMaps",
"Microsoft.Xbox.TCUI"
"Microsoft.XboxGameOverlay",
"Microsoft.XboxGamingOverlay",
"Microsoft.XboxIdentityProvider",
"Microsoft.XboxSpeechToTextOverlay",
"Microsoft.YourPhone",
"Microsoft.ZuneMusic",
"Microsoft.ZuneVideo",
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
Remove-Item C:\Drivers -Force -Recurse
Remove-Item C:\Intel -Force -Recurse
Remove-Item C:\OSDCloud -Force -Recurse
Remove-Item C:\Windows\Setup\Scripts\*.* -Force
Restart-Computer -Force
'@
$OOBEPS1Tasks | Out-File -FilePath 'C:\Windows\Setup\Scripts\oobe.ps1' -Encoding ascii -Force

#================================================
#   PostOS
#   Restart-Computer
#================================================
Write-Host -ForegroundColor Green "Restarting in 10 seconds!"
Start-Sleep -Seconds 10
wpeutil reboot
