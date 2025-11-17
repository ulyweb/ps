Here's a **fast and admin-friendly way** to install the following tools on your **Windows 11 workstation** using **PowerShell** and **Winget**:

***

## ✅ 1. **Active Directory Tools (RSAT)**

These are part of Windows 11 as **Features on Demand**, so you install them via PowerShell:

```powershell
# Run as Administrator
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

To install **all RSAT tools**:

```powershell
Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online
```

You can verify installation with:

```powershell
Get-WindowsCapability -Name RSAT* -Online | Where-Object State -eq 'Installed'
```

 [\[powershellfaqs.com\]](https://powershellfaqs.com/install-rsat-in-windows-11-using-powershell/)

***

## ✅ 2. **Exchange Online PowerShell Module**

Install via PowerShell (requires internet and admin rights):

```powershell
# Set execution policy
Set-ExecutionPolicy RemoteSigned -Force

# Install PowerShellGet (if needed)
Install-Module PowerShellGet -Force -AllowClobber

# Install Exchange Online Management module
Install-Module -Name ExchangeOnlineManagement -Force
```

To connect:

```powershell
Connect-ExchangeOnline -UserPrincipalName youradmin@domain.com
```

 [\[lazyadmin.nl\]](https://lazyadmin.nl/powershell/install-exchange-online-powershell-module/)

***

## ✅ 3. **Windows Sandbox**

Enable via PowerShell (only available on **Windows 11 Pro/Enterprise**):

```powershell
Enable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -All -Online
```

After reboot, launch it from Start Menu: **Windows Sandbox**    [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-install)

***

## 🧰 Optional: Winget Install Script



Here’s a **single, copy‑paste PowerShell script** that:

*   Ensures **Winget** (App Installer) is present (installs it silently if missing)
*   Installs **RSAT: Active Directory** tools
*   Installs the **Exchange Online PowerShell** module
*   Enables **Windows Sandbox**
*   Is **idempotent** (safe to re-run), with clear status messages and exit codes

> 💡 Run this in an **elevated PowerShell** (Run as Administrator).

***

## 🔧 One‑Shot Setup Script

```powershell
# =====================================================================
# Windows 11 Admin Workstation Bootstrap
# - Ensures Winget (App Installer) is installed
# - Installs RSAT Active Directory tools
# - Installs Exchange Online Management PowerShell module (EXO V3)
# - Enables Windows Sandbox
# Author: Ulyweb' helper
# =====================================================================

# ----- Helper: Require elevation -----
function Require-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent() `
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "Please run this script in an elevated PowerShell session (Run as Administrator)."
        exit 1
    }
}
Require-Admin

# ----- Helper: Simple status output -----
function Info($msg){ Write-Host "[INFO ] $msg" -ForegroundColor Cyan }
function Done($msg){ Write-Host "[DONE ] $msg" -ForegroundColor Green }
function Warn($msg){ Write-Host "[WARN ] $msg" -ForegroundColor Yellow }
function Fail($msg){ Write-Host "[FAIL ] $msg" -ForegroundColor Red }

# ----- Section 1: Ensure Winget (App Installer) is present -----
function Ensure-Winget {
    Info "Checking for Winget (App Installer)..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Done "Winget is already installed: $($winget.Source)"
        return
    }

    Warn "Winget not found. Attempting silent install of Microsoft App Installer..."

    # Download latest Microsoft.DesktopAppInstaller msixbundle from GitHub API
    # (Approach commonly used to script App Installer install)
    # NOTE: Requires internet and script execution policy permissive enough to add appx packages.
    try {
        $progressPreference = 'SilentlyContinue'  # make download quiet in non-interactive shells
        $api = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
        $release = Invoke-WebRequest -Uri $api -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
        $assetUrl = $release.assets `
            | Where-Object { $_.browser_download_url -match '\.msixbundle$' } `
            | Select-Object -First 1 -ExpandProperty browser_download_url

        if (-not $assetUrl) { throw "Couldn't locate App Installer .msixbundle URL." }

        $temp = Join-Path $env:TEMP "AppInstaller_Setup.msixbundle"
        Info "Downloading App Installer from: $assetUrl"
        Invoke-WebRequest -Uri $assetUrl -OutFile $temp -UseBasicParsing

        Info "Installing App Installer (this may prompt to add dependencies automatically)..."
        Add-AppxPackage -Path $temp

        Remove-Item $temp -Force -ErrorAction SilentlyContinue

        # Re-check
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) { Done "Winget installed successfully." }
        else { throw "Winget still not available after install." }
    }
    catch {
        Fail "Winget install failed: $($_.Exception.Message)"
        Warn "If your org restricts MSIX/App Installer, consider enabling App Installer via Microsoft Store or software distribution."
        exit 2
    }
}
Ensure-Winget

# ----- Section 2: RSAT - Active Directory Tools -----
function Install-RSAT-AD {
    Info "Installing RSAT: Active Directory (AD DS/AD LDS) tools..."
    try {
        $capName = 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'
        $cap = Get-WindowsCapability -Online -Name $capName -ErrorAction Stop
        if ($cap.State -eq 'Installed') {
            Done "RSAT AD tools already installed."
            return
        }
        Add-WindowsCapability -Online -Name $capName -ErrorAction Stop | Out-Null
        # Verify
        $cap = Get-WindowsCapability -Online -Name $capName
        if ($cap.State -eq 'Installed') { Done "RSAT AD tools installed." }
        else { throw "RSAT AD tools not reported as Installed (state: $($cap.State))." }
    }
    catch {
        Fail "RSAT AD tools install failed: $($_.Exception.Message)"
        exit 3
    }
}
Install-RSAT-AD

# ----- Section 3: Exchange Online Management Module (EXO V3) -----
function Install-EXO-Module {
    Info "Installing/Updating Exchange Online PowerShell module (ExchangeOnlineManagement)..."
    try {
        # Ensure execution policy is compatible for current process
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force

        # Ensure PowerShellGet is up to date (helps with REST-backed EXO V3)
        $psget = Get-Module PowerShellGet -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $psget -or $psget.Version -lt [Version]'2.2.5') {
            Info "Installing/Updating PowerShellGet..."
            Install-Module PowerShellGet -Force -AllowClobber
        }

        # Install or update EXO module
        if (Get-Module -ListAvailable ExchangeOnlineManagement) {
            Info "ExchangeOnlineManagement found; updating to latest..."
            Update-Module ExchangeOnlineManagement -ErrorAction SilentlyContinue
        } else {
            Install-Module -Name ExchangeOnlineManagement -Scope AllUsers -Force
        }

        # Basic verification
        $exo = Get-Module -ListAvailable ExchangeOnlineManagement | Sort-Object Version -Descending | Select-Object -First 1
        if ($exo) { Done "ExchangeOnlineManagement installed (v$($exo.Version))." }
        else { throw "Module not found after install." }
    }
    catch {
        Fail "Exchange Online module install/update failed: $($_.Exception.Message)"
        Warn "You can manually try: Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser"
        exit 4
    }
}
Install-EXO-Module

# ----- Section 4: Windows Sandbox -----
function Enable-WindowsSandbox {
    Info "Enabling Windows Sandbox feature..."
    try {
        # Note: Only supported on Windows 11 Pro/Enterprise; requires virtualization enabled in BIOS/UEFI.
        $featureName = 'Containers-DisposableClientVM'
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $featureName).State
        if ($state -eq 'Enabled') {
            Done "Windows Sandbox already enabled."
            return
        }
        Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart | Out-Null
        Done "Windows Sandbox enabled. A restart is recommended."
        $script:SandboxEnabledNow = $true
    }
    catch {
        Fail "Windows Sandbox enablement failed: $($_.Exception.Message)"
        Warn "Confirm you're on Windows 11 Pro/Enterprise and virtualization is enabled in firmware."
        exit 5
    }
}
Enable-WindowsSandbox

# ----- Final hints -----
Write-Host ""
Done "All requested components processed."
if ($script:SandboxEnabledNow) {
    Warn "Please reboot to complete Windows Sandbox feature installation."
}
Write-Host ""
Info "Next steps:"
Write-Host " - RSAT AD tools: launch 'Active Directory Users and Computers' or import the AD module via: Import-Module ActiveDirectory"
Write-Host " - Exchange Online: Connect using: Connect-ExchangeOnline -UserPrincipalName you@domain.com"
Write-Host " - Windows Sandbox: Start menu -> Windows Sandbox"
```

***

## Why this works (sources)

*   **RSAT on Windows 11** is delivered as **Features on Demand** and installed with `Add-WindowsCapability`; AD DS/AD LDS tools name is `Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0`. [\[threathunt...aybook.com\]](https://threathunterplaybook.com/hunts/windows/190407-RegModEnableRDPConnections/notebook.html), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/answers/questions/821541/install-remote-control-viewer-separate-from-cm-con)
*   **Exchange Online PowerShell (EXO V3)** is installed via `Install-Module ExchangeOnlineManagement` and connects with `Connect-ExchangeOnline` (modern auth/MFA supported). [\[superuser.com\]](https://superuser.com/questions/904353/enable-remote-desktop-in-windows-firewall-from-command-line), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/answers/questions/1320703/command-to-enable-remote-desktop-using-cmd)
*   **Windows Sandbox** is enabled by turning on the optional feature **`Containers-DisposableClientVM`** with PowerShell. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/intune/configmgr/core/clients/manage/remote-control/configuring-remote-control), [\[community....eworks.com\]](https://community.spiceworks.com/t/how-to-remotely-enable-remote-desktop-terminal-services-or-rdp-via-registry-in-windows/1005991)
*   **Winget** is distributed via **Microsoft App Installer**; a common scripted approach downloads the latest `.msixbundle` from the official **winget-cli** GitHub releases and installs with `Add-AppxPackage`. (Your environment may manage this via Store or policy.) [\[stackoverflow.com\]](https://stackoverflow.com/questions/64780110/enabling-rdp-by-changing-registry-setting-only-works-if-rdp-has-been-enabled-sev)

***



