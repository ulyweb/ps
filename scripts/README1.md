How to find your Windows 10 product key
The success of any of these methods is largely dependent on how your PC was activated. If you activated Windows 10 by upgrading from a valid Windows 7 or 8 installation or with the computer’s recent purchase, you are likely to find the product key with most of these methods. However, if your PC was activated as part of an organization’s licensing agreement, finding a product key may be more problematic.

DOWNLOAD this checklist for securing Windows 10 systems from TechRepublic Premium

1. Command prompt
The most direct method for finding your Windows 10 product key is from the command line.

Type cmd into the Windows 10 desktop search box.
Then, right-click the command line result.
Select run as administrator from the context menu.
Type this command at the prompt:
```wmic path softwareLicensingService get OA3xOriginalProductKey```

#
2. PowerShell
   
If you are using Windows 10 PowerShell, the process is similar:

Right-click the Start Menu button.
Select Windows PowerShell (Admin) from the context menu.
Type this command at the prompt to reveal the product key (Figure B).
```powershell "(Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey"```
