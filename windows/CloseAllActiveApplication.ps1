# powershell:Force-Close All Applications:cleanup_Processes.ps1
<#
.SYNOPSIS
    Safely force-closes all running user-level applications that have a main window.

.DESCRIPTION
    This revised script safely targets and terminates only user-facing applications.
    It identifies these applications by checking for a non-zero MainWindowHandle,
    which indicates a visible window or active user program. This prevents
    crashes caused by terminating critical system services.

.NOTES
    To run this script automatically without interaction, it should be scheduled
    using the Windows Task Scheduler, with the 'highest privileges' option enabled.
#>

# Check if running as Administrator
$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal $CurrentUser
$IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "This script must be run as an Administrator. Restarting with elevated privileges..."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- Configuration (Exclusions) ---
# 1. Define processes that should NEVER be terminated, even if they have a main window.
#    Explorer is the Windows Desktop Shell/Taskbar. TaskMgr is the Task Manager.
$CriticalExclusionList = @(
    "explorer",
    "dwm",
    "taskmgr",
    "powershell",
    "powershell_ise"
    # "cmd"
)

# --- Main Logic ---

Write-Host "Starting nightly application cleanup (Safe Mode)..."
$TotalClosed = 0
$TotalScanned = 0

# 1. Get all running processes.
# 2. Filter for processes that have a main window handle (i.e., a user-facing application).
# 3. Exclude the critical processes defined above.
$UserApplicationsToClose = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowHandle -ne 0 -and $_.ProcessName -notin $CriticalExclusionList
}

foreach ($Process in $UserApplicationsToClose) {
    $TotalScanned++
    try {
        # Attempt to stop the process, forcing termination if necessary
        Stop-Process -Id $Process.Id -Force -ErrorAction Stop

        Write-Host "    [CLOSED] $($Process.ProcessName) (ID: $($Process.Id))" -ForegroundColor Green
        $TotalClosed++

    } catch {
        Write-Host "    [FAILED] Could not close $($Process.ProcessName). Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "--- Cleanup Complete ---" -ForegroundColor Yellow
Write-Host "Total user applications scanned and closed: $TotalClosed" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Yellow

# Exit the script
exit 0
