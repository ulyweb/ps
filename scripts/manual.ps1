#### This is the manual way to generate the Wlanreport and getting via Filebrowser.
### from run command:


C:\WINDOWS\system32\runas.exe /profile /env /user:%userdomain%\a-%username% powershell


Enter-pssession

it will prompt you to enter the computername:


Once you're logged in then type in:

netsh wlan show wlanreport

wait until it generate the reports:

Once its generated copy it to c:\IT_folder

Copy-Item -Path "C:\ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html" -Destination "C:\IT_folder\wlan-report-latest.html"

iwr -useb https://raw.githubusercontent.com/francisuadm/ps/main/scripts/get_fb.ps1 | iex
