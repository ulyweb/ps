# Ensure running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as Administrator" -ForegroundColor Red
    exit
}

# 1. Bypass Windows 11 hardware requirements (if needed)
$BypassTPMKey = "HKLM:\SYSTEM\Setup\MoSetup"
if (!(Test-Path $BypassTPMKey)) {
    New-Item -Path $BypassTPMKey -Force | Out-Null
}
Set-ItemProperty -Path $BypassTPMKey -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -Type DWord

# 2. Enable Windows Update for feature upgrades
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name "AllowOSUpgrade" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing" -Name "LocalSourcePath" -Value "" -Type String -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing" -Name "UseWindowsUpdate" -Value 1 -Type DWord -Force

# 3. Restart Windows Update Service
Write-Host "Restarting Windows Update Service..." -ForegroundColor Yellow
Restart-Service -Name wuauserv -Force
Start-Service -Name wuauserv

# 4. Trigger Windows Update to upgrade to Windows 11
Write-Host "Checking for Windows 11 upgrade..." -ForegroundColor Green
$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()
$searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")

foreach ($update in $searchResult.Updates) {
    if ($update.Title -match "Windows 11") {
        Write-Host "Found Windows 11 Update: $($update.Title)" -ForegroundColor Green
        $updateInstaller = New-Object -ComObject Microsoft.Update.UpdateInstaller
        $updateInstaller.Updates = $update
        $updateInstaller.Install()
        break
    }
}

# 5. Confirm Upgrade
Write-Host "Windows Update initiated. Restart may be required." -ForegroundColor Cyan
