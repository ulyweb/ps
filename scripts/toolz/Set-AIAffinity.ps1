# Set-AIAffinity.ps1
# Description: Persistently sets the process priority and CPU affinity for the M365 Copilot process (AI.exe)
#              to lower priority cores, mitigating system-wide input lag caused by resource contention.

# Define the process name (case-insensitive search for the AI executable)
$ProcessName = "AI"

# Define the target CPU Affinity Mask.
# System has 14 logical cores (0-13). We target the last four cores (10, 11, 12, 13).
# Mask = (2^10) + (2^11) + (2^12) + (2^13) = 1024 + 2048 + 4096 + 8192 = 15360
$TargetMask = 15360

# Maximum wait time (to prevent the script from running indefinitely if Copilot is truly disabled)
$MaxWaitTimeSeconds = 30
$WaitCount = 0

Write-Host "Starting persistent throttling for $ProcessName.exe..."

# Wait loop: The process may not start immediately upon login
do {
    $Process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($Process) {
        Write-Host "$ProcessName.exe found. Applying settings."
        break
    }
    Start-Sleep -Seconds 2
    $WaitCount += 2
} while ($WaitCount -lt $MaxWaitTimeSeconds)

# If the process was found, apply the settings
if ($Process) {
    # 1. Set Priority to Below Normal (more effective than affinity alone)
    $Process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
    Write-Host "Priority set to BelowNormal."

    # 2. Set Affinity to the specified low cores
    $Process.ProcessorAffinity = $TargetMask
    Write-Host "Affinity set to cores 10, 11, 12, 13 (Mask: $TargetMask)."
} else {
    Write-Warning "Could not find $ProcessName.exe within the time limit. Exiting."
}
