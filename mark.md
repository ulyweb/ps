> [!NOTE]
> ## ✅ First step is to open Powershell windows as Admin Privileges
>> __By using Run Window, press (Win + R)__
>>> _**Copy and Paste the command below to your Run command.**_


````
RunAs /noprofile /user:%USERDOMAIN%\a-%USERNAME% "powershell \"Start-Process powershell \" -Verb RunAs"
````


> [!NOTE]
> ## ✅ Once Powershell windows is open
> ### Next step is to start an Interactive Session.
>> _**Copy and Paste the command below to your Run command then enter.**_
>> >> _**It will now prompt you for the computername.**_

````
Enter-PSSession
````

> [!NOTE]
> ## ✅ After you enter the computername of the remote machine
> ### Wait until it connect an create your profile
> ### If the machine is active or in the network it should connect.
> ### If not it will fail and give you error.
> ### Once it connects
>> _**Copy and Paste the command below to your Run command.**_


````
Get-ChildItem -Path "C:\Users" | Sort CreationTime -Descending | FT Name, CreationTime
````
