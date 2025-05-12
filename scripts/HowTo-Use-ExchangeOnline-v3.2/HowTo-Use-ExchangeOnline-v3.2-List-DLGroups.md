# Using ExchangeOnlineManagement Version 3.2.0 in PowerShell ISE to List Distribution Groups

By following these steps, you will ensure you are only using version **3.2.0** of the ExchangeOnlineManagement module in PowerShell ISE and can successfully list your distribution groups.

---

## Summary Table

| Step                      | Command                                                                 |
|---------------------------|-------------------------------------------------------------------------|
| Check installed versions  | `Get-InstalledModule ExchangeOnlineManagement`                          |
| Remove old versions       | `Uninstall-Module -Name ExchangeOnlineManagement -AllVersions`          |
| Install v3.2.0            | `Install-Module -Name ExchangeOnlineManagement -RequiredVersion 3.2.0`  |
| Import v3.2.0 in ISE      | `Import-Module ExchangeOnlineManagement -RequiredVersion 3.2.0`         |
| Connect to Exchange       | `Connect-ExchangeOnline`                                                |
| List DL groups            | `Get-DistributionGroup -Identity "nameHERE!"`                           |

---

## Step-by-Step Commands
````
Clear Screen
Clear-Host

Verify and Use Only Version 3.2 of ExchangeOnlineManagement
Get-InstalledModule ExchangeOnlineManagement | Format-List Name,Version,InstalledLocation

Uninstall Other Versions (if necessary)
Uninstall-Module -Name ExchangeOnlineManagement -AllVersions

Install Version 3.2.0 Specifically
Install-Module -Name ExchangeOnlineManagement -RequiredVersion 3.2.0

Import the Module in ISE
Import-Module ExchangeOnlineManagement -RequiredVersion 3.2.0

Connect to Exchange Online
Connect-ExchangeOnline

List a Distribution Group (replace 'nameHERE!' with your group's name)
Get-DistributionGroup -Identity "nameHERE!"
````
