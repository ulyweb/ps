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
>> _**Copy and Paste the command below to your Run command.**_
>> >> _**It will now prompt you for the computername.**_
>> >> _**Enter then type in .**_

````
Enter-PSSession -computername
````

> [!NOTE]
> # ✅ Once the new Powershell windows open
>> _**Copy and Paste the command below to your Run command.**_
>> >> _**It will now prompt you for the computername.**_
>> >> _**Enter then type in .**_
