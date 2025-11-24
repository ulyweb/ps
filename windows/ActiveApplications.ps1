# Check if running as Administrator
$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal $CurrentUser
$IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "This script must be run as an Administrator. Restarting with elevated privileges..."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$UsersActiveApplications = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowHandle -ne 0 -and $_.ProcessName -notin $CriticalExclusionList
}

$UsersActiveApplications
# Allow PowerShell to be used again immediately
Start-Sleep -Seconds 1  # Small delay to prevent overlap
Write-Host "All tools have been launched successfully!" -ForegroundColor Green
Read-Host "Press Enter to exit"
