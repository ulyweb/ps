##  **portable SCCM Remote Control (CmRcViewer) package** and also included **scripts/commands to enable RDP** on remote machines.

***

## 1) Download: Portable CM Remote Control bundle

**Grab the ZIP** and drop in Microsoft’s binaries from any machine that has the MECM/SCCM console installed:

**Download:** [CMRemoteTools‑Portable.zip](placeholder-0)

### What’s inside

    CMRemoteTools-Portable/
    ├─ bin/
    │  ├─ 00000409/
    │  │  └─ (PLACEHOLDER for CmRcViewerRes.dll)
    │  └─ (PLACEHOLDER for CmRcViewer.exe, RdpCoreSccm.dll)
    ├─ Start-PortableCmRcViewer.ps1
    ├─ Install-CMRC-Portable.ps1
    ├─ Uninstall-CMRC-Portable.ps1
    └─ Enable-RDP-Remote.ps1

> **Copy these three Microsoft files** from a console box into `.\bin\` (keeping the resource DLL in the `00000409` folder):
>
> *   `CmRcViewer.exe`
> *   `RdpCoreSccm.dll`
> *   `00000409\CmRcViewerRes.dll`  
>     Typical source path:  
>     `C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\i386\` [\[us-prod.as...rosoft.com\]](https://us-prod.asyncgw.teams.microsoft.com/v1/objects/0-cus-d2-b32d7da8b7a7ab837e7d3e33bb0e5551/views/original/CMRemoteTools-Portable.zip), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/answers/questions/821541/install-remote-control-viewer-separate-from-cm-con)

### How to launch it

*   Quick launch (portable):
    ```powershell
    .\Start-PortableCmRcViewer.ps1 -ComputerName <TargetPC> [-SiteServer <SiteServerFQDN>]
    ```
    `CmRcViewer.exe` supports:  
    `CmRcViewer.exe <Address> <\\SiteServerName>` (site server is optional; used for audit/status messages). [\[ccmexec.com\]](https://ccmexec.com/2019/05/install-cm-remote-tools-standalone-using-powershell/)

*   Optional install (copies to Program Files + Start Menu shortcut):
    ```powershell
    # Run from the unzipped folder after placing the 3 binaries in .\bin
    .\Install-CMRC-Portable.ps1 -AddStartMenuShortcut
    ```

> **Note:** CM Remote Control uses its own protocol/port (default **TCP 2701**), not RDP. So it can work even if your network blocks RDP/3389. (That’s why this is a good workaround in locked-down environments.) [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/intune/configmgr/core/clients/manage/remote-control/remotely-administer-a-windows-client-computer)

***

## 2) One‑liners to enable RDP (local machine)

**Registry:** enable RDP

```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" ^
  /v fDenyTSConnections /t REG_DWORD /d 0 /f
```

This flips `fDenyTSConnections` to **0** (allow RDP). [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/intune/configmgr/core/clients/manage/remote-control/configuring-remote-control)

**(Optional) Require NLA:**

```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" ^
  /v UserAuthentication /t REG_DWORD /d 1 /f
```

Setting `UserAuthentication=1` enforces **Network Level Authentication (NLA)**. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-terminalservices-localsessionmanager-fdenytsconnections)

**Firewall:** open built-in Remote Desktop rules

```cmd
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
```

Enables the Windows Firewall **Remote Desktop** rule group. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-terminalservices-rdp-winstationextensions-userauthentication), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/netsh-advfirewall)

***

## 3) Remotely enable RDP on another computer

> **Prereqs:** Admin rights on the target, and a path for remote execution:
>
> *   **PowerShell Remoting** (WinRM 5985/5986), or
> *   **Remote Registry** service for `reg.exe` remote edits, or
> *   A tool like **PsExec** (if allowed in your environment).

### A) Using PowerShell Remoting (recommended)

```powershell
# Enable RDP + NLA + Firewall on one or more targets
Invoke-Command -ComputerName PC01,PC02 -ScriptBlock {
  # Allow RDP
  New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Force | Out-Null
  Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' `
    -Name fDenyTSConnections -Type DWord -Value 0   # enable
  # Require NLA (optional)
  New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Force | Out-Null
  Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
    -Name UserAuthentication -Type DWord -Value 1   # NLA
  # Firewall rules
  Enable-NetFirewallRule -DisplayGroup "Remote Desktop" | Out-Null
}
```

(Registry keys/values and firewall group usage per Microsoft Learn.) [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/intune/configmgr/core/clients/manage/remote-control/configuring-remote-control), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-terminalservices-localsessionmanager-fdenytsconnections), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-terminalservices-rdp-winstationextensions-userauthentication), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/netsh-advfirewall)

### B) Using `reg.exe` against the remote registry

> Ensure the **Remote Registry** service is running on the target. Then:

```cmd
:: Enable RDP remotely
reg add \\PC01\HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server ^
  /v fDenyTSConnections /t REG_DWORD /d 0 /f

:: (Optional) Require NLA remotely
reg add \\PC01\HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp ^
  /v UserAuthentication /t REG_DWORD /d 1 /f
```

These toggle the same Microsoft-documented values on the remote machine. (Open the firewall on the target via a remote shell, WinRM, or your software deployment tool.) [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/intune/configmgr/core/clients/manage/remote-control/configuring-remote-control), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-terminalservices-localsessionmanager-fdenytsconnections)

**Open firewall rules on the target (remotely):**

*   Via PowerShell remoting (see A), or
*   Run on the target using your software distribution tool:
    ```cmd
    netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
    ```
     [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-terminalservices-rdp-winstationextensions-userauthentication), [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/netsh-advfirewall)

> **Tip:** If you need to script this often, the bundle includes **`Enable-RDP-Remote.ps1`** which takes:
>
> ```powershell
> .\Enable-RDP-Remote.ps1 -ComputerName PC01,PC02 -RequireNLA `
>   -AddUser "DOMAIN\Helpdesk"   # optional: add to Remote Desktop Users group
> ```

***

## 4) Deployment notes (for your team)

*   **Auditing/Status messages:** If you want CM Remote Control **status messages** to flow to your site when using the standalone viewer, include the **site server** parameter when launching (e.g., `CmRcViewer.exe <PC> <\\SiteServerName>`). That is the documented CLI, and it’s the simplest way to ensure audit messages reach the site. [\[ccmexec.com\]](https://ccmexec.com/2019/05/install-cm-remote-tools-standalone-using-powershell/)
*   **Only three files are required** for the viewer to run standalone (keep the language DLL in its `00000409` subfolder). [\[us-prod.as...rosoft.com\]](https://us-prod.asyncgw.teams.microsoft.com/v1/objects/0-cus-d2-b32d7da8b7a7ab837e7d3e33bb0e5551/views/original/CMRemoteTools-Portable.zip)
*   **RDP won’t bypass corporate blocks**: even if you enable RDP via registry, connections will still fail if the network blocks **TCP 3389**. Use **SCCM Remote Control** (port **2701**) instead when RDP is blocked. [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/intune/configmgr/core/clients/manage/remote-control/remotely-administer-a-windows-client-computer)

***

If you want, I can **tailor the scripts** for your environment (e.g., pre-fill a site server, add multilingual resources, or wrap as an **Intune Win32** app / **SCCM Application**). Do you want me to set the **default Site Server** and add a **Start Menu** launch shortcut for your desktop techs?
