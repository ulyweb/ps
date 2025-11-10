
# ✅ Run (Win + R) Powershell with A-Administrator Privileges

````
RunAs /noprofile /user:%USERDOMAIN%\a-%USERNAME% "powershell \"Start-Process powershell \" -Verb RunAs"
````
