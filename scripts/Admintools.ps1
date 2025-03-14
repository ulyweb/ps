# AdminTools.ps1

# Function to run commands as administrator
function Run-AsAdmin {
    param([scriptblock]$ScriptBlock)
    
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command & { $ScriptBlock }" -Verb RunAs -WindowStyle Hidden
}

# Open SCCM first (runs normally without admin)
Start-Process -FilePath "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\Microsoft.ConfigurationManagement.exe" -WindowStyle Normal

# Script block for admin tasks (each running separately)
$adminScriptBlock = {
    # Open PowerShell ISE in a separate window
    Start-Process powershell_ise -WindowStyle Normal

    # Open an elevated PowerShell window separately
    Start-Process powershell -Verb RunAs -WindowStyle Normal

    # Open Active Directory Users and Computers (last)
    Start-Process dsa.msc -WindowStyle Normal
}

# Run admin tasks as administrator in separate processes
try {
    Run-AsAdmin -ScriptBlock $adminScriptBlock
} catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
}

# Allow PowerShell to be used again immediately
Start-Sleep -Seconds 1  # Small delay to prevent overlap
Write-Host "All tools have been launched successfully!" -ForegroundColor Green
