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





To reinstall SCCM (System Center Configuration Manager) via PowerShell, follow these steps:

---

### **Step 1: Uninstall SCCM Client**
Use the following PowerShell command to uninstall the SCCM client:

```powershell
Start-Process -FilePath "C:\Windows\CCMSetup\CCMSetup.exe" -ArgumentList "/uninstall" -Wait -NoNewWindow
```

This will initiate the uninstallation process. Monitor the log file located at `C:\Windows\CCMSetup\CCMSetup.log` to ensure the uninstallation completes successfully[7].

---

### **Step 2: Reinstall SCCM Client**
After uninstalling, use this PowerShell command to reinstall the SCCM client:

```powershell
Start-Process -FilePath "C:\Windows\CCMSetup\CCMSetup.exe" -ArgumentList "SMSSITECODE=" -Wait -NoNewWindow
```

Replace `` with your SCCM site code (e.g., `P01`). This command will install the SCCM client and connect it to the specified site[7].

---

### **Step 3: Verify Installation**
Once installed, check the log file again at `C:\Windows\CCMSetup\CCMSetup.log` to verify successful installation. You can also confirm functionality by accessing the Configuration Manager in the Control Panel[7].

---

### **Optional: Automate with a Script**
If you need a complete script for automation, you can combine both steps into a single PowerShell script:

```powershell
# Uninstall SCCM Client
Start-Process -FilePath "C:\Windows\CCMSetup\CCMSetup.exe" -ArgumentList "/uninstall" -Wait -NoNewWindow

# Wait for uninstallation to complete
Start-Sleep -Seconds 60

# Reinstall SCCM Client
Start-Process -FilePath "C:\Windows\CCMSetup\CCMSetup.exe" -ArgumentList "SMSSITECODE=" -Wait -NoNewWindow

Write-Host "SCCM Client reinstalled successfully."
```

Replace `` with your actual site code.



To kill the process ccmsetup.exe *32 and related executables via PowerShell, you can use the following script:

```powershell
# Kill ccmsetup.exe *32 process
Get-Process -Name "ccmsetup" -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -like "*32"} | Stop-Process -Force -Verbose

# Kill all related SCCM processes
$sccmProcesses = @("ccmexec", "ccmsetup", "ccmrepair", "ccmeval")
foreach ($process in $sccmProcesses) {
    Get-Process -Name $process -ErrorAction SilentlyContinue | Stop-Process -Force -Verbose
}
```

This script does two things:

1. It specifically targets the ccmsetup.exe *32 process using Get-Process and filters for the 32-bit version, then terminates it using Stop-Process[1][3].

2. It then kills all related SCCM processes by iterating through a list of common SCCM-related process names and terminating them[2].

The `-Force` parameter ensures that the processes are terminated even if they're not responding, and `-Verbose` provides detailed output about the operation[7].

If you want to verify that the processes have been terminated, you can use the following command after running the script:

```powershell
Get-Process -Name "ccmsetup", "ccmexec", "ccmrepair", "ccmeval" -ErrorAction SilentlyContinue
```

If no results are returned, it means all specified processes have been successfully terminated[3][7].

Remember that forcefully terminating these processes may interfere with ongoing SCCM operations. It's recommended to use this script only when necessary, such as when troubleshooting SCCM issues or preparing for a clean reinstallation[2].


