To force the Ethernet connection while Wi-Fi is connected, you can use the following PowerShell commands:

1. First, enable the Ethernet adapter:

```powershell
Enable-NetAdapter -Name "Ethernet" -Confirm:$false
```

2. Then, set the Ethernet interface as the preferred connection:

```powershell
Set-NetIPInterface -InterfaceAlias "Ethernet" -InterfaceMetric 1
```

3. Finally, to ensure the Ethernet connection is established, you can restart the network adapter:

```powershell
Restart-NetAdapter -Name "Ethernet"
```

These commands will force the Ethernet connection to be active and prioritized over the Wi-Fi connection. However, please note that this may disrupt the current network connection temporarily.

If you need to verify the connection status after executing these commands, you can use:

```powershell
Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
```

This will show you which network adapters are currently active and connected.

