# This script first lists all startup application entries from the
# Windows Registry and then provides an option to remove them.
#
# WARNING: This script modifies registry values and should be used with caution.
# Always back up your registry before making changes.
# You must run PowerShell as an Administrator to affect the HKEY_LOCAL_MACHINE key.

# --- Paths to the registry keys for startup applications ---
$currentUserRunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$allUsersRunKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$allUsersWow64RunKey = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"

# --- Function to show all values from a specified key ---
function Show-StartupItems {
    param (
        [string]$Path,
        [string]$Description
    )

    Write-Host "--- $Description ---" -ForegroundColor Yellow

    # Check if the registry key exists before trying to access it
    if (Test-Path -Path $Path) {
        try {
            $items = Get-ItemProperty -Path $Path | Select-Object * | Where-Object { $_.PSObject.Properties.Name -ne '(default)' }
            
            if ($null -ne $items -and $items.Count -gt 0) {
                # Format and display the items
                $items | Format-List
            } else {
                Write-Host "No startup items found." -ForegroundColor Gray
            }
        } catch {
            Write-Error "An error occurred while reading from '$Path': $_"
        }
    } else {
        Write-Host "Registry key not found: $Path" -ForegroundColor Red
    }
    Write-Host "" # Add a blank line for readability
}

# --- Function to remove all values from a specified key ---
function Clear-RegistryKeyValues {
    param (
        [string]$Path
    )

    Write-Host "Clearing registry key: $Path"

    if (Test-Path -Path $Path) {
        try {
            $values = (Get-ItemProperty -Path $Path | Select-Object -ExpandProperty PSPropertySet)

            if ($null -ne $values -and $values.Count -gt 0) {
                foreach ($value in $values) {
                    Write-Host "  - Removing value: $value"
                    Remove-ItemProperty -Path $Path -Name $value -ErrorAction Stop -ErrorVariable scriptError
                }
                Write-Host "All values successfully removed from '$Path'."
            } else {
                Write-Host "No startup items found to remove from '$Path'."
            }
        } catch {
            Write-Error "An error occurred while processing '$Path': $_"
        }
    } else {
        Write-Host "Registry key not found: $Path"
    }
    Write-Host ""
}

# --- Main script logic ---

# 1. Checks if it is running with administrator privileges.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script must be run with Administrator privileges. Please re-run the script as an Administrator." -ForegroundColor Red
    break
}

# 2. Verifies the Execution Policy for both 'CurrentUser' and 'LocalMachine' scopes.
$currentPolicyUser = Get-ExecutionPolicy -Scope CurrentUser
$currentPolicyMachine = Get-ExecutionPolicy -Scope LocalMachine

if ($currentPolicyUser -ne "RemoteSigned") {
    Write-Host "Setting Execution Policy for 'CurrentUser' to 'RemoteSigned'..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force | Out-Null
    Write-Host "Execution Policy for 'CurrentUser' is now 'RemoteSigned'." -ForegroundColor Green
}

if ($currentPolicyMachine -ne "RemoteSigned") {
    Write-Host "Setting Execution Policy for 'LocalMachine' to 'RemoteSigned'..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force | Out-Null
    Write-Host "Execution Policy for 'LocalMachine' is now 'RemoteSigned'." -ForegroundColor Green
}

Write-Host "Checking for startup applications..." -ForegroundColor Green
Write-Host "The following applications are configured to start with Windows:" -ForegroundColor Green
Write-Host ""

# Show startup items for each location
Show-StartupItems -Path $currentUserRunKey -Description "Current User Startup Apps"
Show-StartupItems -Path $allUsersRunKey -Description "All Users Startup Apps"
Show-StartupItems -Path $allUsersWow64RunKey -Description "All Users Startup Apps (32-bit)"

# Prompt the user for a decision
$choice = Read-Host "Do you want to delete all of these startup items? (Type 'Y' for Yes, or 'N' for No to exit)"

if ($choice -eq 'y' -or $choice -eq 'Y') {
    Write-Host "Deleting startup items..." -ForegroundColor Yellow

    # --- Backup Logic ---
    $backupFolder = "C:\it_folder"
    if (-not (Test-Path $backupFolder)) {
        Write-Host "Creating backup folder: $backupFolder"
        New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $finalBackupPath = Join-Path -Path $backupFolder -ChildPath "startup-$timestamp-org.reg"
    $tempFile1 = Join-Path -Path $env:TEMP -ChildPath "temp-hkcu.reg"
    $tempFile2 = Join-Path -Path $env:TEMP -ChildPath "temp-hklm.reg"
    $tempFile3 = Join-Path -Path $env:TEMP -ChildPath "temp-hklm-wow64.reg"

    Write-Host "Creating registry backup at '$finalBackupPath'..." -ForegroundColor Yellow
    
    # Export each key to a temporary file
    reg.exe export "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" $tempFile1 /y
    reg.exe export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" $tempFile2 /y
    reg.exe export "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run" $tempFile3 /y

    # Concatenate temporary files into a single backup file
    Get-Content $tempFile1, $tempFile2, $tempFile3 | Set-Content $finalBackupPath

    # Clean up temporary files
    Remove-Item $tempFile1, $tempFile2, $tempFile3

    Write-Host "Backup created successfully." -ForegroundColor Green
    
    # --- Deletion Logic ---

    # Remove startup items for the current user
    Clear-RegistryKeyValues -Path $currentUserRunKey

    # Remove startup items for all users (requires Administrator privileges)
    Clear-RegistryKeyValues -Path $allUsersRunKey
    Clear-RegistryKeyValues -Path $allUsersWow64RunKey

    Write-Host "Script finished. Please restart your computer for changes to take full effect." -ForegroundColor Green
} else {
    Write-Host "Operation cancelled. No changes were made." -ForegroundColor Red
}
