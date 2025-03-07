To force uninstall and reinstall SCCM (System Center Configuration Manager) on a Windows 10 machine, follow these steps:

---

### **Step 1: Force Uninstall SCCM**
You can use either PowerShell or Command Prompt to completely remove SCCM.

#### **Option 1: PowerShell Script for Forceful Removal**
1. Open PowerShell as an administrator.
2. Use the following script to stop SCCM services and delete related files and registry entries:

```powershell
# Stop SCCM services
Get-Service -Name CcmExec -ErrorAction SilentlyContinue | Stop-Service -Force -Verbose
Get-Service -Name ccmsetup -ErrorAction SilentlyContinue | Stop-Service -Force -Verbose

# Delete SCCM client folders
$null = takeown /F "$($Env:WinDir)\CCM" /R /A /D Y 2>&1
Remove-Item -Path "$($Env:WinDir)\CCM" -Force -Recurse -Confirm:$false -Verbose -ErrorAction SilentlyContinue

$null = takeown /F "$($Env:WinDir)\CCMSetup" /R /A /D Y 2>&1
Remove-Item -Path "$($Env:WinDir)\CCMSetup" -Force -Recurse -Confirm:$false -Verbose -ErrorAction SilentlyContinue

# Remove SCCM certificates and GUID file
Remove-Item -Path "$($Env:WinDir)\smscfg.ini" -Force -Confirm:$false -Verbose -ErrorAction SilentlyContinue
Remove-Item -Path 'HKLM:\Software\Microsoft\SystemCertificates\SMS\Certificates\*' -Force -Confirm:$false -Verbose -ErrorAction SilentlyContinue

Write-Host "All traces of SCCM have been removed"
```

#### **Option 2: Manual Uninstallation via Command Prompt**
1. Open Command Prompt as an administrator.
2. Navigate to the SCCM setup directory:
   ```cmd
   cd C:\Windows\CCMSetup
   ```
3. Run the uninstallation command:
   ```cmd
   ccmsetup.exe /uninstall
   ```
4. Wait for the process to complete and restart your computer[2][4].

---

### **Step 2: Reinstall SCCM**
After removing all traces of SCCM, you can reinstall it.

1. Open Command Prompt as an administrator.
2. Navigate to the location of the `ccmsetup.exe` file (usually provided by your IT team or SCCM server).
3. Run the installation command:
   ```cmd
   ccmsetup.exe SMSSITECODE=
   ```
   Replace `` with the appropriate site code (e.g., `P01`)[2][5].
4. Monitor the installation logs located at:
   ```cmd
   C:\Windows\CCMSetup\CCMSetup.log
   ```
5. After installation, verify that the client is functioning by checking its status in the Configuration Manager under Control Panel[2][7].

---

### **Troubleshooting Tips**
- If you encounter issues during uninstallation, ensure all related services (e.g., `CcmExec`) are stopped before proceeding[1][4].
- For bulk installations or remote systems, consider using PowerShell scripts or deployment tools like Active Directory startup scripts[5].

This process ensures a clean removal and fresh installation of SCCM on your system.

