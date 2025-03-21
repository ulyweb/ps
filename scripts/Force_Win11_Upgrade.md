### **PowerShell Script: Force Windows 11 Upgrade**
```powershell
# Ensure execution policy is unrestricted
Set-ExecutionPolicy Unrestricted -Scope Process -Force

# Function to clean registry and configure Windows Update policies
function Configure-RegistryForUpgrade {
    Write-Host "Configuring Registry for Windows Upgrade..." -ForegroundColor Yellow

    $regKeysToDelete = @(
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies",
        "HKCU\Software\Microsoft\WindowsSelfHost",
        "HKCU\Software\Policies",
        "HKLM\Software\Microsoft\Policies",
        "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies",
        "HKLM\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate",
        "HKLM\Software\Microsoft\WindowsSelfHost",
        "HKLM\Software\Policies",
        "HKLM\Software\WOW6432Node\Microsoft\Policies",
        "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies",
        "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate"
    )

    # Delete registry keys
    foreach ($key in $regKeysToDelete) {
        Write-Host "Deleting $key ..." -ForegroundColor Cyan
        Start-Process -FilePath "reg.exe" -ArgumentList "delete `"$key`" /f" -NoNewWindow -Wait
    }

    # Add necessary registry keys
    Write-Host "Adding Windows Update policies..." -ForegroundColor Green
    Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f /v TargetReleaseVersion /t REG_DWORD /d 1' -NoNewWindow -Wait
    Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f /v ProductVersion /t REG_SZ /d "Windows 10"' -NoNewWindow -Wait
    Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f /v TargetReleaseVersionInfo /t REG_SZ /d 22H2' -NoNewWindow -Wait
}

# Function to force Windows 11 Upgrade
function Force-Windows11Upgrade {
    Write-Host "Forcing Windows 11 Upgrade..." -ForegroundColor Yellow

    # Bypass CPU and TPM checks
    $BypassTPMKey = "HKLM:\SYSTEM\Setup\MoSetup"
    if (!(Test-Path $BypassTPMKey)) {
        New-Item -Path $BypassTPMKey -Force | Out-Null
    }
    Set-ItemProperty -Path $BypassTPMKey -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -Type DWord

    # Enable Windows Update for feature upgrades
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name "AllowOSUpgrade" -Value 1 -Type DWord
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing" -Name "LocalSourcePath" -Value "" -Type String -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing" -Name "UseWindowsUpdate" -Value 1 -Type DWord -Force

    # Restart Windows Update Service
    Write-Host "Restarting Windows Update Service..." -ForegroundColor Yellow
    Restart-Service -Name wuauserv -Force
    Start-Service -Name wuauserv

    # Trigger Windows Update to check for Windows 11 upgrade
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

    Write-Host "Windows Update initiated. Restart may be required." -ForegroundColor Cyan
}

# Run functions in order
Configure-RegistryForUpgrade
Force-Windows11Upgrade
```

---

### **How It Works**
1. **Execution Policy**: Ensures the script can run unrestricted.
2. **Registry Cleanup (`Configure-RegistryForUpgrade`)**:  
   - Deletes registry keys that may **block** Windows 11 upgrades.
   - Sets Windows Update policies for **feature upgrades**.
3. **Windows 11 Upgrade Trigger (`Force-Windows11Upgrade`)**:  
   - Bypasses CPU/TPM restrictions.
   - Restarts Windows Update and forces an upgrade.

---

### **How to Use**
1. **Save the script** as `Force_Win11_Upgrade.ps1`.
2. **Run PowerShell as Administrator**.
3. **Execute the script**:
   ```powershell
   PowerShell -ExecutionPolicy Unrestricted -File C:\Path\To\Force_Win11_Upgrade.ps1
   ```
4. **Wait for Windows Update to process the upgrade.**
5. **Restart your system if needed.**


