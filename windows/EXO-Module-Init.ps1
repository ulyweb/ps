<#
.SYNOPSIS
    Installs, verifies, and updates required PowerShell administrative modules.

.DESCRIPTION
    This script initializes the environment by checking, installing, and updating 
    five key modules: PowerShellGet, MSOnline, PSWindowsUpdate, ExchangeOnlineManagement, 
    and ActiveDirectory. It uses the safe 'CurrentUser' scope for compatibility across 
    Windows and Linux (Codespaces) environments. ActiveDirectory is handled as a 
    Windows feature installation, not a PSGallery module.
#>
function Install-AndVerifyModule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ModuleName
    )

    Write-Host "➡️ Processing module '$ModuleName'..." -ForegroundColor Yellow
    
    # Use CurrentUser scope for installation to avoid permission issues in Codespaces environments
    $installScope = "CurrentUser"
    
    # Determine if we should attempt installation via PSGallery
    $isWindows = ($PSVersionTable.PSVersion.Platform -eq "Windows")

    try {
        # --- Special Handling for ActiveDirectory (Windows Feature) ---
        if ($ModuleName -eq 'ActiveDirectory') {
            if ($isWindows) {
                Write-Host "  - ActiveDirectory is a Windows feature. Checking status..." -ForegroundColor Yellow
                
                # Check if the required capability is installed (ActiveDirectory DS-LDS Tools)
                $adCapability = Get-WindowsCapability -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 -Online -ErrorAction SilentlyContinue

                if ($adCapability -and $adCapability.State -eq 'Installed') {
                    Write-Host "✅ Module '$ModuleName' is installed as an OS feature." -ForegroundColor Green
                } else {
                    Write-Host "  - Installing ActiveDirectory tools via Add-WindowsCapability..." -ForegroundColor Cyan
                    # Install the specific Active Directory RSAT component
                    Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 -ErrorAction Stop
                    Write-Host "✅ Module '$ModuleName' installed successfully as an OS feature." -ForegroundColor Green
                }
            } else {
                Write-Host "ℹ️ Module '$ModuleName' is not installable on this Linux/Codespaces platform." -ForegroundColor DarkYellow
            }
            return # Exit function for ActiveDirectory
        }

        # --- Standard PSGallery Modules (ExchangeOnlineManagement, etc.) ---
        
        if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
            Write-Host "  - Module '$ModuleName' is NOT installed. Installing now..." -ForegroundColor Red
            
            Install-Module -Name $ModuleName -Force -Scope $installScope -Confirm:$false -AllowClobber -ErrorAction Stop
            
            $installed = Get-InstalledModule -Name $ModuleName -ErrorAction Stop
            Write-Host "✅ Module '$ModuleName' installed successfully (Version: $($installed.Version))." -ForegroundColor Green
        } else {
            # Module is installed, now check for updates
            $installed = Get-InstalledModule -Name $ModuleName -ErrorAction Stop
            Write-Host "✅ Module '$ModuleName' is currently installed (Version: $($installed.Version))." -ForegroundColor Green

            $latest = Find-Module -Name $ModuleName -ErrorAction Stop

            if ($latest.Version -gt $installed.Version) {
                Write-Host "  - A newer version ($($latest.Version)) is available. Updating now..." -ForegroundColor Cyan
                Update-Module -Name $ModuleName -Force -Scope $installScope -Confirm:$false -ErrorAction Stop
                
                $updated = Get-InstalledModule -Name $ModuleName -ErrorAction Stop
                Write-Host "✅ Module '$ModuleName' updated to the latest version (Version: $($updated.Version))." -ForegroundColor Green
            } else {
                Write-Host "✅ Module '$ModuleName' is already up-to-date." -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "❌ Warning: Could not process module '$ModuleName'. Reason: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host "----------------------------------------------------"
}

# --------------------------------------------------------------------
# EXECUTION BLOCK: Run the function for all required modules
# --------------------------------------------------------------------

Install-AndVerifyModule -ModuleName 'PowerShellGet'
Install-AndVerifyModule -ModuleName 'MSOnline'
Install-AndVerifyModule -ModuleName 'PSWindowsUpdate'
Install-AndVerifyModule -ModuleName 'ExchangeOnlineManagement'
Install-AndVerifyModule -ModuleName 'ActiveDirectory'

# Inform the user of the ActiveDirectory limitation on Linux
if ($PSVersionTable.PSVersion.Platform -ne "Windows") {
    Write-Host "ℹ️ Remember: The 'ActiveDirectory' module commands are NOT functional in this Linux/Codespaces environment." -ForegroundColor Cyan
}
