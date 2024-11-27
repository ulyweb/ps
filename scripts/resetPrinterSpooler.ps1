# You can run this script as an administrator to resolve any spooling issues.
# 1.Stop the Print Spooler.
# 2.Clear all pending print jobs.
# 3.Restart the Print Spooler service.

# Stop the Print Spooler Service
Stop-Service -Name Spooler -Force

# Clear the Print Queue
Remove-Item -Path "C:\Windows\System32\spool\PRINTERS\*" -Recurse -Force

# Restart the Print Spooler Service
Start-Service -Name Spooler

Write-Host "Print Spooler queue cleared and service restarted."
