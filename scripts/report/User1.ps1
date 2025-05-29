# CLS
Clear-host
#runas /noprofile powershell
powershell

# Setup IT_Folder folder if doesn't exist
$IT_folder = "C:\IT_Folder"
if (-not (Test-Path $IT_folder)) {
    New-Item -Path $IT_folder -ItemType Directory | Out-Null
}

iwr -Uri https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/report/UserActivity.ps1 -outfile "c:\it_folder\UserActivity.ps1"

# Define the path to the executable
$exePath = "c:\IT_folder\UserActivity.ps1"

$adminUser = "$env:USERDOMAIN\a-$env:USERNAME"  # admin username

# Run the process as the specified admin user
Start-Process -FilePath "powershell" -ArgumentList "/c runas `"$exePath`"" -NoNewWindow

pause
