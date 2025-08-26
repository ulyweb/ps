Here are the commands to create the necessary firewall rules for Syncthing. You'll need to run PowerShell as an administrator to execute these commands.

### **Creating Firewall Rules for Syncthing**

These commands use the `New-NetFirewallRule` cmdlet to create a new inbound rule. We'll create separate rules for each protocol and port to ensure everything is covered.

1.  **Open PowerShell as an administrator.**
    Search for "PowerShell" in the Start menu, right-click, and select **Run as administrator**.

2.  **Create the rule for the Syncthing sync protocol (TCP on port 22000).**
    This is for direct connections between devices.

    ```powershell
    New-NetFirewallRule -DisplayName "Syncthing (Sync Protocol TCP)" -Direction Inbound -Profile Any -Action Allow -Protocol TCP -LocalPort 22000
    ```

      * `-DisplayName`: A descriptive name for the rule. You can change this to whatever you like.
      * `-Direction Inbound`: Specifies that this rule applies to incoming connections.
      * `-Profile Any`: This is important. It means the rule will apply to all network profiles (Domain, Public, and Private), ensuring Syncthing works on any network you connect to.
      * `-Action Allow`: Sets the rule to allow traffic.
      * `-Protocol TCP`: Specifies the Transmission Control Protocol.
      * `-LocalPort 22000`: The specific port the rule will listen on.

3.  **Create the rule for the Syncthing sync protocol (UDP on port 22000).**
    This is for QUIC-based sync traffic.

    ```powershell
    New-NetFirewallRule -DisplayName "Syncthing (Sync Protocol UDP)" -Direction Inbound -Profile Any -Action Allow -Protocol UDP -LocalPort 22000
    ```

4.  **Create the rule for local discovery (UDP on port 21027).**
    This allows Syncthing to automatically find other devices on your local network.

    ```powershell
    New-NetFirewallRule -DisplayName "Syncthing (Local Discovery)" -Direction Inbound -Profile Any -Action Allow -Protocol UDP -LocalPort 21027
    ```

5.  **Create the rule for the Syncthing Web GUI (TCP on port 8384).**
    This is only necessary if you want to access the Syncthing web interface from another device on your network (e.g., from your phone or another computer). If you only access it locally via `http://127.0.0.1:8384`, this rule is not needed.

    ```powerseria
    New-NetFirewallRule -DisplayName "Syncthing (Web GUI)" -Direction Inbound -Profile Any -Action Allow -Protocol TCP -LocalPort 8384
    ```

### **After Running the Commands**

Once you've run these commands, you should be able to re-run the verification command from our previous conversation to see the new rules.

For example, to check the rule for TCP port 22000:

```powershell
Get-NetFirewallRule -Direction Inbound | Where-Object { $_.LocalPort -eq "22000" -and $_.Action -eq "Allow" }
```

You should see output detailing the "Syncthing (Sync Protocol TCP)" rule you just created.

There's no need to reboot your computer after creating these rules; they take effect immediately. The key takeaway is that these commands provide a robust, reliable way to ensure your firewall is configured correctly for Syncthing's operation.
