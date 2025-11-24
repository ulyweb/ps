> [!NOTE]
> # Powershell

> > ### Windows Utility - **Runs PowerShell as Admin from Run (Win+R)** | [https://github.com/christitustech/winutil]
````
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"irm "https://christitus.com/win" | iex"' -Verb RunAs"
````

> > **Runs PowerShell as Admin**
````
irm "https://christitus.com/win" | iex
````

> > > #### FileBrowser Installer Script then execute it!
```
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/get_fb.ps1 | iex\"' -Verb RunAs"
```

> > > #### or you can run it from powershell command
````
irm https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/get_fb.ps1 | iex
````

> #### QR Code generator
```
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/qrcodemenu.ps1 | iex\"' -Verb RunAs"
```
> #### Remotely Control
```
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/RemotePC.ps1 | iex\"' -Verb RunAs"
```

> #### Remotely Control 1
```
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/RemotePC1.ps1 | iex\"' -Verb RunAs"
```

> #### Winget for Windows 10
```
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/francisuadm/chrome/main/ps/Installer_Winget1.ps1 | iex\"' -Verb RunAs"
```
> #### Display User Folders Remotely0
```
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/RemovePCUserFolder.ps1 | iex\"' -Verb RunAs"
```

> #### Display User Folders Remotely
```
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/RemotePCUserFolder.ps1 | iex\"' -Verb RunAs"
```

> #### Run PowerShell command another user account.
```
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"powershell"' -Verb RunAs"
```

> #### Run PowerShell command runas.
```
runas /noprofile /user:$env:USERDOMAIN"\a-"$env:USERNAME powershell
```
> > ####
```
iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/RemovePCUserFolder.ps1 | iex
```

> > #### My Dailytask for disabling login.
```
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/dailytask.ps1 | iex\"' -Verb RunAs"
```
> > #### This will capture a Wi-Fi report.
```
netsh wlan show wlanreport
```


>> #### Here are the commands for PSWindowsUpdate with PowerShell: the manual way!

````
# Install the Windows Update module
Install-Module -Name PSWindowsUpdate -Force

# Import the Windows Update module
Import-Module PSWindowsUpdate

# Check for updates
Get-WindowsUpdate -AcceptAll -Install -AutoReboot

# Restart the system if updates require a reboot
Restart-Computer -Force
````

````
iwr -Uri https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/UpgradeWindows10toWindows11-23H2.ps1 -outfile c:\it_folder\UpgradeWindows10toWindows11-23H2.ps1
````


> [!IMPORTANT]
> Powershell script that automates network reset:  
>> Open PowerShell as an Administrator. 
>>> Copy and paste the script into the PowerShell window. 
>>>> Run the script. 


````
# Reset network settings and reinstall network drivers
Try {
    netsh winsock reset
    netsh int ip reset
    ipconfig /flushdns
    ipconfig /release
    ipconfig /renew

    Write-Output "Network settings reset and drivers reinstalled."
    
    Write-Output "Press any key to reboot the system..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    Restart-Computer
} Catch {
    Write-Output "An error occurred: $_"
}

netsh wlan show wlanreport

check eventviewer log

````

> [!IMPORTANT]
> Let's reset the network settings using PowerShell:
> Open PowerShell as an Administrator.
> Copy and paste the script into the PowerShell window.
> Run the script.
> Give it a go and let me know how it works for you.

> [!Note]
> $${\color{red}To \space run \space it, \space automatically \space use \space the \space command \space below:}$$


````diff
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/ResetNetworkSettings.ps1 | iex\"' -Verb RunAs"
````

> [!IMPORTANT]
> Steps how to use Powershell ISE on MacOS :
> Connect to VDI via Citrix Workspace remotely on the browser :
> Once you're connected :
>

> [!Note]
> Powershell script that automates network reset:  
>> Open PowerShell as an Administrator. 
>>> Change directory to

````
cd .\WindowsPowerShell\v1.0\
````

Now run the command below to open Powershell ISE as your regular account:

````
Start-Process .\PowerShell_ISE.exe -Verb RunAsUser
````

Open the Powershell ISE is open copy these commands:

````
Clear-Host

# Function to check if a module is installed
function Check-Module {
    param (
        [string]$ModuleName
    )
    try {
        Get-Module -Name $ModuleName -ListAvailable -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Check if the ExchangeOnlineManagement module is installed
$ModuleName = "ExchangeOnlineManagement"
$ModuleInstalled = Check-Module -ModuleName $ModuleName

if (-not $ModuleInstalled) {
    # Step 1: Install the ExchangeOnlineManagement module
    Write-Output "Installing ExchangeOnlineManagement module..."
    Install-Module -Name $ModuleName -Force
} else {
    Write-Output "ExchangeOnlineManagement module is already installed."
}

# Import the ExchangeOnlineManagement module
Import-Module $ModuleName

# Ensure the execution policy is set to RemoteSigned
$CurrentPolicy = Get-ExecutionPolicy
if ($CurrentPolicy -ne "RemoteSigned") {
    Write-Output "Setting execution policy to RemoteSigned..."
    Set-ExecutionPolicy RemoteSigned -Force
} else {
    Write-Output "Execution policy is already set to RemoteSigned."
}

# Step 2: Connect to Exchange Online
Connect-ExchangeOnline

## Disconnect from Exchange Online
# Disconnect-ExchangeOnline -Confirm:$false
````


### Installing Windows Fax and Scan on Windows 11 using PowerShell
````
Get-WindowsCapability -Online | Where-Object {$_.Name -like "*Print*" }
````
Here's how you can do it using PowerShell:

Open PowerShell as Administrator:

Press Windows + X, then select Windows Terminal (Admin) or PowerShell (Admin).
Run the following command to enable the feature:

Use the following PowerShell command to install the "Windows Fax and Scan" feature:
````
dism /online /add-capability /capabilityname:Print.Fax.Scan~~~~0.0.1.0
````
This command uses DISM (Deployment Imaging Service and Management Tool) to add the feature.

Wait for the installation to complete: The command will install Windows Fax and Scan, and you should see a message indicating whether the operation was successful or not.

Check for the feature: After installation is complete, you should be able to access "Windows Fax and Scan" by searching for it in the Start menu.


### Display current usage of userprofile
````
Invoke-Command -ComputerName "RemoteComputerName" -ScriptBlock {
$username = Read-Host "Enter the username for the profile you want to check"

#   $username = "SpecificUsername"
    $userProfilePath = "C:\Users\$username"
    $profileSize = (Get-ChildItem $userProfilePath -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB
    [PSCustomObject]@{
        UserName = $username
        ProfileSizeGB = [math]::Round($profileSize, 2)
    }
}
````
### Get-NetworkAdapter current IP/MAC
````
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/Get-NetworkAdapterStatus.ps1 | iex\"' -Verb RunAs"
````
### Or manual copy it to local drive a c:\it_folder
````
Invoke-WebRequest -Uri https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/Get-NetworkAdapterStatus.ps1 -outfile c:\it_folder\getnet.ps1
````


### If you get an error run the command below:
````
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\getnet.ps1
````
#### Alternative: Temporarily Bypass Execution Policy
````
powershell -ExecutionPolicy Bypass -File .\getnet.ps1
````

### Displaying Disk space via powershell
````
Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object @{Name="Size(GB)";Expression={$_.Size/1GB -as [int]}}, @{Name="FreeSpace(GB)";Expression={$_.FreeSpace/1GB -as [int]}}
````

> [!IMPORTANT]
> ## Admintools Script runs four programs from **single-line run command**:
> > Active Directory, SCCM Tools, Powershell ISE and Powershell
> > 
✅ **Runs with A-Administrator Privileges**  
✅ **Sets Execution Policy to Bypass**  
✅ **Executes the Admintools Script**  
````
RunAs /noprofile /user:%USERDOMAIN%\a-%USERNAME% "powershell \"Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"irm "https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/Admintools.ps1" | iex"'"
````

# Admintools Script run it under Powershell Terminal

````
irm "https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/Admintools.ps1" | iex
````
> [!IMPORTANT]
> ✅  ***Run **(`Win + R`)** Powershell regular Privileges*** 
````
RunAs /noprofile /user:%USERDOMAIN%\%USERNAME% "powershell \"Start-Process powershell \""
````
> [!IMPORTANT]
> ✅ ***Run **(`Win + R`)** Powershell with A-Administrator Privileges***  
````
RunAs /noprofile /user:%USERDOMAIN%\a-%USERNAME% "powershell \"Start-Process powershell \" -Verb RunAs"
````


#### PowerShell function to renew your IP address and flush the DNS cache, allowing you to execute everything with a single command:

````
function Refresh-NetworkConfig {
    [CmdletBinding()]
    param ()

    Write-Host "Releasing IP address..." -ForegroundColor Yellow
    ipconfig /release

    Write-Host "Renewing IP address..." -ForegroundColor Yellow
    ipconfig /renew

    Write-Host "Flushing DNS cache..." -ForegroundColor Yellow
    Clear-DnsClientCache

    Write-Host "Network configuration refreshed successfully!" -ForegroundColor Green
}
````

#### Here's command from RUN Window

````
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/Refresh-NetworkConfig.ps1 | iex\"' -Verb RunAs"
````

#### Testing Wi-Fi connectivities
````
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/Wi-Fi_Monitors.ps1 | iex\"' -Verb RunAs"
````

#### Other way to display Wi-Fi Reports

````
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/wlanreport.ps1 | iex\"' -Verb RunAs"
````

> > **Runs PowerShell as Admin - update-localadminmembership**
````
irm "https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/Update-localadminmembership.ps1" | iex
````


>[!TIP]
>Start Powershell Admin
````
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"irm "https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/start-adminps.ps1" | iex"' -Verb RunAs"
````


>[!TIP]
>Downloads and runs a user activity report script with admin rights. Keeps the window open to show results after it runs.
````
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"irm https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/report/User1.ps1 | iex\"' -Verb RunAs"
````

>[!TIP]
>Downloads and runs.

````
powershell irm https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/run-startup-script.bat | cmd
````


>[!TIP]
>This identifies and display which application actively running

### RunAs Automatically
````
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/windows/ActiveApplications.ps1 | iex\"' -Verb RunAs"
````

### Manual run
````
$UserApplications = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowHandle -ne 0 -and $_.ProcessName -notin $CriticalExclusionList
}
$UserApplications

````

>[!TIP]
>This will force close all actively applications
````
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/windows/CloseAllActiveApplication.ps1"' -Verb RunAs"
````
