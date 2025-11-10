> [!NOTE]
> # ✅ 
Run (Win + R) Powershell with A-Administrator Privileges
> First step is to open Powershell windows
> 
>> _**Copy and Paste the command below to your Run command.**_

````
RunAs /noprofile /user:%USERDOMAIN%\a-%USERNAME% "powershell \"Start-Process powershell \" -Verb RunAs"
````


> [!NOTE]
> # ✅ Next step to Starts an Interactive Session to remote computer.
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
