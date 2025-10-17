# Install-AIAffinityTask.ps1
# Description: Installs the Set-AIAffinity.ps1 script and creates a Scheduled Task to run it
#              automatically upon user logon. REQUIRES ADMIN RIGHTS TO RUN.
#
# PREREQUISITE: Ensure Set-AIAffinity.ps1 is already saved in C:\IT_Scripts

# --- Configuration ---
$TaskName = "IT_Set_AIE_Affinity"
$ScriptDir = "C:\IT_Scripts"
$ScriptFileName = "Set-AIAffinity.ps1"
$ScriptPath = Join-Path $ScriptDir $ScriptFileName

# --- 1. Define Scheduled Task Parameters ---

# The action runs the PowerShell script
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""

# The trigger is set to run whenever *any user* logs in
$Trigger = New-ScheduledTaskTrigger -AtLogOn

# Settings to ensure the task runs even if the initial log-on condition is missed
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances Parallel -ExecutionTimeLimit "PT10M"

# The Principal defines who the task runs as (Running under the user's context)
$Principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" # Interactive Users

# --- 2. Register the Scheduled Task ---
Write-Host "Registering Scheduled Task: $TaskName"

try {
    # Check if the task already exists and update it, otherwise register new.
    # We use -Force to ensure it updates if necessary.
    Register-ScheduledTask -TaskName $TaskName `
                           -Action $Action `
                           -Trigger $Trigger `
                           -Settings $Settings `
                           -Principal $Principal `
                           -Description "Sets CPU Affinity and Priority for M365 Copilot AI.exe to mitigate latency." `
                           -Force
                           
    Write-Host "Scheduled Task '$TaskName' created/updated successfully."
    Write-Host "Action: Run $ScriptFileName silently upon user logon."

}
catch {
    Write-Error "Failed to register Scheduled Task: $($_.Exception.Message)"
}
