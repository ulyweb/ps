Write-Host "Starting script..."
Write-Host "Checking network connection profile..."
Get-NetConnectionProfile

Write-Host "Starting continuous ping to Google..."
Start-Process powershell -ArgumentList "-NoExit -Command Test-Connection -ComputerName google.com -Count 9999"

Write-Host "Checking Wi-Fi signal strength..."
(netsh wlan show interfaces) -Match '^\s+Signal' -Replace '^\s+Signal\s+:\s+',''

Write-Host "Starting continuous Wi-Fi signal strength monitoring..."
Start-Process powershell -ArgumentList "-NoExit -Command while (`$true) { `$signal = (netsh wlan show interfaces) -Match '^\s+Signal' -Replace '^\s+Signal\s+:\s+',''; Write-Output `"Signal Strength: `$signal%`"; Start-Sleep -Seconds 3 }"

Write-Host "Script completed. Press any key to exit."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
