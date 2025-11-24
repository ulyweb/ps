# powershell:Force-Close All Applications:cleanup_processes.ps1
<#
.SYNOPSIS
    Force-closes all running processes that are not essential Windows system components.

.DESCRIPTION
    This script is designed to ensure a clean slate for the next user session.
    It retrieves all active processes and terminates those that are not on a specified
    "safe list" of critical system processes (like svchost, explorer, etc.).
    It uses Stop-Process with the -Force parameter to ensure termination.

.NOTES
    To run this script automatically without interaction, it should be scheduled
    using the Windows Task Scheduler, with the 'highest privileges' option enabled.
#>

# --- Configuration ---
# 1. Define the safe list of critical processes that should NOT be terminated.
#    These are essential for Windows to continue running (e.g., Taskbar, System Services).
#    Customize this list if you have other critical processes that must stay open.
$SafeProcessList = @(
    "system", "smss", "csrss", "wininit", "services", "lsass",
    "winlogon", "explorer", "dwm", "runtimebroker", "svchost",
    "taskhostw", "sihost", "conhost", "cmd", "powershell",
    "powershell_ise", "mrt.exe", "msmpeng", "firewallapi", "wmpnetwk",
    "taskmgr", "ctfmon", "audiodg", "fontdrvhost", "spoolsv",
    "hpqthb" # Including a common HP component, just in case
)

# --- Main Logic ---

Write-Host "Starting nightly process cleanup..."
$TotalProcesses = 0
$ClosedProcesses = 0

# Get all running processes
$AllProcesses = Get-Process -ErrorAction SilentlyContinue

foreach ($Process in $AllProcesses) {
    $TotalProcesses++

    # Check if the process name is NOT in the safe list
    if ($Process.ProcessName -notin $SafeProcessList) {
        try {
            # Attempt to stop the process, forcing termination if necessary
            Stop-Process -Id $Process.Id -Force -ErrorAction Stop

            Write-Host "    [CLOSED] $($Process.ProcessName) (ID: $($Process.Id))" -ForegroundColor Green
            $ClosedProcesses++

        } catch {
            Write-Host "    [FAILED] Could not close $($Process.ProcessName). Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "--- Cleanup Complete ---" -ForegroundColor Yellow
Write-Host "Total processes scanned: $TotalProcesses" -ForegroundColor Cyan
Write-Host "Processes force-closed: $ClosedProcesses" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Yellow

# Exit the script
exit 0
