Force both Ethernet and Wi-Fi interfaces to be up simultaneously in Windows 10 or 11. Here's how you can achieve this:

1. Open the Control Panel and navigate to "Network and Internet" > "Network and Sharing Center" > "Change adapter settings"[6].

2. Right-click on both your Ethernet and Wi-Fi adapters and select "Enable" for each if they are not already enabled[6].

3. To ensure both interfaces remain active, you need to modify a Group Policy setting:

   a. Press Windows key + R, type "gpedit.msc", and press Enter to open the Local Group Policy Editor.
   b. Navigate to: Computer Configuration > Administrative Templates > Network > Windows Connection Manager.
   c. Double-click on "Minimize the number of simultaneous connections to the Internet or a Windows Domain".
   d. Select "Enabled" and set the "Minimize Policy Options" to "0 = Allow all simultaneous connections"[1].

4. Click "Apply" and "OK" to save the changes.

5. Restart your computer for the changes to take effect.

After following these steps, both your Ethernet and Wi-Fi interfaces should remain active simultaneously. You can verify this by checking the Network Connections window or by using the command prompt and typing "ipconfig /all" to see the status of all network adapters[2].

Keep in mind that while both interfaces can be active, Windows will typically prioritize one connection over the other for internet traffic. If you want to control which interface is used for specific tasks, you may need to adjust the interface metrics or set up specific routes[3][4].

