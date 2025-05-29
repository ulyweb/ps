# Clear the host screen
Clear-Host

# Define the working folder
$IT_folder = "C:\IT_Folder"

# Create folder if it doesn't exist
if (-not (Test-Path -Path $IT_folder)) {
    New-Item -Path $IT_folder -ItemType Directory -Force | Out-Null
}

# Define script URL and local path
$scriptUrl = "https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/report/UserActivity.ps1"
$localScriptPath = Join-Path $IT_folder "UserActivity.ps1"

# Download the UserActivity.ps1 script
Invoke-WebRequest -Uri $scriptUrl -OutFile $localScriptPath -UseBasicParsing

# Run the downloaded script with admin privileges
Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$localScriptPath`"" -Verb RunAs
