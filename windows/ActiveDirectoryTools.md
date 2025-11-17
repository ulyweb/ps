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


