> [!NOTE]
> # Powershell

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
runas /noprofile /user:%userdomain%\a-%username% powershell
```
> > ####
```
iwr -useb https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/RemovePCUserFolder.ps1 | iex
```

> > #### My Dailytask for disabling login.
```
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/francisuadm/ps/refs/heads/main/scripts/dailytask.ps1 | iex\"' -Verb RunAs"
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
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"iwr -useb https://raw.githubusercontent.com/francisuadm/ps/refs/heads/main/scripts/ResetNetworkSettings.ps1 | iex\"' -Verb RunAs"
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

````

