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
start /wait msiexec.exe /i C:\Windows\Temp\PowerShell-7.3.1-win-x64.msi /qb-! /norestart REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1
# Starting OOBE installation/update phase
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\oobe.ps1
# Cleanup
del c:\Windows\Setup\scripts\*.*
exit 
'@
$OOBEcmdTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\oobe.cmd' -Encoding ascii -Force

#================================================
#  WinPE PostOS
#  ps.ps1
#================================================
$OOBEcmdTasks = @'
$Title = "OOBE PowerShell 7 Download"
$host.UI.RawUI.WindowTitle = $Title
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"
Install-Module -Name PowerShellGet | Out-Null
Invoke-WebRequest https://github.com/PowerShell/PowerShell/releases/download/v7.3.1/PowerShell-7.3.1-win-x64.msi -o C:\Windows\Temp\PowerShell-7.3.1-win-x64.msi
'@
$OOBEcmdTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\ps.ps1' -Encoding ascii -Force

#================================================
#   WinPE PostOS
#   oobe.ps1
#================================================
$OOBEPS1Tasks = @'
$Title = "OOBE installation/update phase"
$host.UI.RawUI.WindowTitle = $Title
write-host "Powershell Version: "$PSVersionTable.PSVersion

# Change the ErrorActionPreference to 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
#$ErrorActionPreference = 'SilentlyContinue'

# Set Environment
Write-Host "Set Environment" -ForegroundColor Green
$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath+";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path+";C:\Program Files\WindowsPowerShell\Scripts"

# Register Powershell Modules and install tools
Write-Host "Register PSGallery" -ForegroundColor Green
Register-PSRepository -Name PSGallery -SourceLocation https://www.powershellgallery.com/api/v2/ -PublishLocation https://www.powershellgallery.com/api/v2/package/ -ScriptSourceLocation https://www.powershellgallery.com/api/v2/items/psscript/ -ScriptPublishLocation https://www.powershellgallery.com/api/v2/package/ -InstallationPolicy Trusted -PackageManagementProvider NuGet
Write-Host "Install PackageManagement Module" -ForegroundColor Green
Install-Module -Name PackageManagement | Out-Null
$Error.Clear()
Write-Host "Install PowerShellGet Module" -ForegroundColor Green
Install-Module -Name PowerShellGet | Out-Null
Write-Host -ForegroundColor Green "Install OSD Module"
Install-Module OSD -Force | Out-Null
$Error.Clear()
Write-Host -ForegroundColor Green "Install PSWindowsUpdate Module"
Install-Module PSWindowsUpdate -Force | Out-Null
Write-Host -ForegroundColor Green "Install WinGet Tools"
Install-Module WingetTools -Force
Write-Host -ForegroundColor Green "Install WinGet Module"
Install-WinGet

Write-Host -ForegroundColor Green "Remove Builtin Apps"
# Create array to hold list of apps to remove 
$appname = @( 
"*Microsoft.WindowsAlarms*"
"*microsoft.windowscommunicationsapps*"
"*Microsoft.WindowsFeedbackHub*"
"*Microsoft.ZuneMusic*"
"*Microsoft.ZuneVideo*"
"*Microsoft.WindowsMaps*"
"*Microsoft.Messaging*"
"*Microsoft.MicrosoftSolitaireCollection*"
"*Microsoft.MicrosoftOfficeHub*"
"*Microsoft.Office.OneNote*"
"*Microsoft.WindowsSoundRecorder*"
"*Microsoft.OneConnect*"
"*Microsoft.Microsoft3DViewer*"
"*Microsoft.BingWeather*"
"*Microsoft.Xbox.TCUI*"
"*Microsoft.XboxApp*"
"*Microsoft.XboxGameOverlay*"
"*Microsoft.XboxGamingOverlay*"
"*Microsoft.XboxIdentityProvider*"
"*Microsoft.XboxSpeechToTextOverlay*"
"*Microsoft.XboxGameCallableUI*"
"*Microsoft.Print3D*"
"*Microsoft.LanguageExperiencePacken-gb*"
"*Microsoft.SkypeApp*"
"*Clipchamp.Clipchamp*"
"*Microsoft.GamingApp*"
"*Microsoft.BingNews*"
"*MicrosoftCorporationII.QuickAssist*"
"*Microsoft.YourPhone*"
"*MicrosoftTeams*"
) 
 # Remove apps from system
 ForEach($app in $appname){ Get-AppxPackage -Name $app | Remove-AppxPackage -Allusers -ErrorAction SilentlyContinue 
         Write-Host -ForegroundColor DarkCyan "$app"
 }
 
Write-Host -ForegroundColor Green "Install .Net Framework 3.x"
$Result = Get-MyWindowsCapability -Match 'NetFX' -Detail
foreach ($Item in $Result) {
    if ($Item.State -eq 'Installed') {
        Write-Host -ForegroundColor DarkGray "$($Item.DisplayName)"
    }
    else {
        Write-Host -ForegroundColor DarkCyan "$($Item.DisplayName)"
        $Item | Add-WindowsCapability -Online -ErrorAction Ignore | Out-Null
    }
}

Write-Host -ForegroundColor Green "Microsoft .NET Windows Desktop Runtime 7"
winget Install Microsoft.DotNet.DesktopRuntime.7

Write-Host -ForegroundColor Green "Install Software Updates"
Invoke-WGUpgrade -all

#Install Driver updates
Write-Host -ForegroundColor Green "Install Drivers from Windows Update"
$UpdateDrivers = $true
if ($UpdateDrivers) {
    Install-WindowsUpdate -UpdateType Driver -AcceptAll -IgnoreReboot | Out-File "c:\windows\temp\$(get-date -f yyyy-MM-dd)-DriversUpdate.log" -force
}

#Install Software updates
Write-Host -ForegroundColor Green "Install Windows Updates"
$UpdateWindows = $true
if ($UpdateWindows) {
    Add-WUServiceManager -MicrosoftUpdate -Confirm:$false | Out-Null
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot | Out-File "c:\windows\temp\$(get-date -f yyyy-MM-dd)-WindowsUpdate.log" -force
}

#Install Winget Software Updates
Write-Host -ForegroundColor Green "Install Application Updates"
invoke-wgupgrade -All -IncludeUnknown

#Check AssetTag
Write-Host -ForegroundColor Green "Checking AssetTag"
$AssetTag = (Get-WmiObject -Class Win32_SystemEnclosure | Select-Object SMBiosAssetTag).SMBiosAssetTag
If ($null -eq $AssetTag){ 
        Write-Host -ForegroundColor Green "Machine AssetTag is not set, Computer name not changed"
    }
    Else{
        If ($AssetTag -eq "No Asset Tag"){
            Write-Host -ForegroundColor Green "Virtual machine, No AssetTag available"
        }
        Else{
            $MachineName = "DNB$AssetTag"
            Write-Host -ForegroundColor Green "Machine name = $MachineName"
            Rename-Computer -NewName $MachineName | Out-Null
            }
        }

Write-Host -ForegroundColor Green "OOBE update phase ready, Restarting in 30 seconds!"
Start-Sleep -Seconds 30
Remove-Item C:\Drivers -Force -Recurse
Remove-Item C:\Intel -Force -Recurse
Remove-Item C:\OSDCloud -Force -Recurse
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
