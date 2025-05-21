<#
.SYNOPSIS
    Retrieves distribution group memberships for a user from Active Directory and Exchange Online.

.DESCRIPTION
    This script prompts for a user's email address. It checks for necessary PowerShell modules
    (ActiveDirectory and ExchangeOnlineManagement), attempts to install ExchangeOnlineManagement
    if missing. It then displays the names and descriptions of the distribution groups
    (both on-premises Active Directory and Exchange Online) that the user is a member of.
    The results are also exported to a CSV file in C:\Reports, with a filename formatted
    as UserDLMembership_YYYYMMDD_HHMMSS_emailaddress.csv.

.NOTES
    Author: uly 
    Version: 1.2
    - Added prerequisite module checking and installation attempt for ExchangeOnlineManagement.
    - Provides guidance if the Active Directory module is missing.
    - Added functionality to display results on screen and export to a dynamically named CSV file.
    - Automatically creates C:\Reports directory if it doesn't exist.
    - Requires PowerShell to be run with sufficient privileges to install modules and create directories if not present.
#>

# --- Script Parameters ---
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the email address of the user.")]
    [string]$UserEmailAddress
)

# --- Configuration ---
$ProgressPreference = 'SilentlyContinue' # Suppress progress bars for cleaner output during main operations
$ReportsPath = "C:\Reports"

# --- Prerequisite Checks and Setup ---
function Ensure-ModulesAvailable {
    $ErrorActionPreference = 'Stop' # Stop on errors within this function for clearer feedback
    $modulesInstalledAndImported = $true # Assume true initially

    # 1. Check for Active Directory Module
    Write-Host "🔎 Checking for Active Directory module..." -ForegroundColor Yellow
    if (Get-Module -ListAvailable -Name ActiveDirectory) {
        Write-Host "✅ Active Directory module is available." -ForegroundColor Green
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
            Write-Host "👍 Active Directory module imported successfully." -ForegroundColor Green
        } catch {
            Write-Error "❌ Failed to import Active Directory module: $($_.Exception.Message)"
            Write-Warning "Please ensure the Active Directory module is installed and functional."
            $modulesInstalledAndImported = $false
        }
    } else {
        Write-Warning "⚠️ Active Directory module not found."
        Write-Host "This module is part of Remote Server Administration Tools (RSAT)."
        Write-Host "To install it on Windows 10/11 (ensure you're running as Administrator):"
        Write-Host "  1. Open PowerShell as Administrator."
        Write-Host "  2. Run: Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
        Write-Host "  Alternatively, for older Windows versions or through GUI:"
        Write-Host "  Go to Settings > Apps > Optional features > Add a feature, search for 'RSAT: Active Directory Domain Services'."
        Write-Host "Script execution may fail for Active Directory queries without this module."
        $modulesInstalledAndImported = $false
    }

    # 2. Check for Exchange Online Management Module
    Write-Host "`n🔎 Checking for ExchangeOnlineManagement module..." -ForegroundColor Yellow
    if (Get-Module -ListAvailable -Name ExchangeOnlineManagement) {
        Write-Host "✅ ExchangeOnlineManagement module is available." -ForegroundColor Green
    } else {
        Write-Warning "⚠️ ExchangeOnlineManagement module not found. Attempting to install..."
        try {
            Write-Host "⏳ Installing ExchangeOnlineManagement module (requires internet and admin rights if installing for AllUsers)..." -ForegroundColor Cyan
            # Ensure PowerShellGet is up-to-date and try installing from PSGallery
            Install-Module PowerShellGet -Force -SkipPublisherCheck -Confirm:$false -ErrorAction SilentlyContinue
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AcceptLicense -AllowClobber -ErrorAction Stop
            Write-Host "✅ ExchangeOnlineManagement module installed successfully for the current user." -ForegroundColor Green
        } catch {
            Write-Error "❌ Failed to install ExchangeOnlineManagement module: $($_.Exception.Message)"
            Write-Warning "Please try installing it manually using: Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force"
            $modulesInstalledAndImported = $false
        }
    }

    # Try importing ExchangeOnlineManagement if it was found or installed
    if ($modulesInstalledAndImported -and (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        try {
            Import-Module ExchangeOnlineManagement -ErrorAction Stop
            Write-Host "👍 ExchangeOnlineManagement module imported successfully." -ForegroundColor Green
        } catch {
            Write-Error "❌ Failed to import ExchangeOnlineManagement module: $($_.Exception.Message)"
            Write-Warning "Please ensure the ExchangeOnlineManagement module is installed correctly."
            $modulesInstalledAndImported = $false
        }
    } elseif (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        # If it wasn't available and install failed, make sure flag is false
        $modulesInstalledAndImported = $false
    }


    $ErrorActionPreference = 'Continue' # Restore default error action preference
    return $modulesInstalledAndImported
}

# --- Functions for Group Retrieval ---

function Get-ADUserDistributionGroupMembership {
    param (
        [string]$EmailAddress
    )
    if (-not (Get-Module -Name ActiveDirectory)) {
        Write-Warning "Skipping Active Directory checks as the module is not loaded or available."
        return @()
    }

    try {
        Write-Host "🔍 Searching for user '$EmailAddress' in Active Directory..." -ForegroundColor Cyan
        $adUser = Get-ADUser -Filter "EmailAddress -eq '$EmailAddress'" -Properties MemberOf, DisplayName -ErrorAction SilentlyContinue

        if (-not $adUser) {
            Write-Warning "User with email '$EmailAddress' not found in Active Directory."
            return @()
        }

        Write-Host "✅ User '$($adUser.DisplayName)' found in Active Directory." -ForegroundColor Green
        Write-Host "🔎 Retrieving Active Directory group memberships..." -ForegroundColor Cyan

        $adGroups = @()
        foreach ($groupDN in $adUser.MemberOf) {
            try {
                $group = Get-ADGroup -Identity $groupDN -Properties Description, GroupCategory, DisplayName -ErrorAction Stop
                if ($group.GroupCategory -eq 'Distribution') {
                    $adGroups += [PSCustomObject]@{
                        UserEmail   = $EmailAddress # Added for CSV context
                        GroupName   = $group.DisplayName
                        Description = $group.Description
                        Source      = "Active Directory"
                        GroupType   = "Distribution"
                    }
                }
            }
            catch {
                Write-Warning "Could not retrieve details for AD group: $groupDN. Error: $($_.Exception.Message)"
            }
        }
        Write-Host "✅ Found $($adGroups.Count) Active Directory distribution group(s)." -ForegroundColor Green
        return $adGroups
    }
    catch {
        Write-Error "Error querying Active Directory: $($_.Exception.Message)"
        return @()
    }
}

function Get-ExOUserDistributionGroupMembership {
    param (
        [string]$EmailAddress
    )
    if (-not (Get-Module -Name ExchangeOnlineManagement)) {
        Write-Warning "Skipping Exchange Online checks as the module is not loaded or available."
        return @()
    }

    $exoSessionActive = $false
    $ownSessionStarted = $false # Flag to track if this function started the session
    try {
        Write-Host "🔄 Checking Exchange Online connection..." -ForegroundColor Cyan
        $currentEXOSession = Get-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri *outlook.office365.com* -ErrorAction SilentlyContinue
        if ($currentEXOSession -and ($currentEXOSession.State -eq 'Opened')) {
            Write-Host "🔗 Reusing existing Exchange Online session." -ForegroundColor Green
            $exoSessionActive = $true
        } else {
            Write-Host "🔗 Attempting to connect to Exchange Online..." -ForegroundColor Cyan
            Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
            $exoSessionActive = $true
            $ownSessionStarted = $true # This function started the session
        }

        Write-Host "🔍 Searching for user '$EmailAddress' in Exchange Online..." -ForegroundColor Cyan
        $exoUser = Get-Recipient -Identity $EmailAddress -ErrorAction SilentlyContinue

        if (-not $exoUser) {
            Write-Warning "User with email '$EmailAddress' not found in Exchange Online (as a mail-enabled object)."
            return @()
        }

        Write-Host "✅ User '$($exoUser.DisplayName)' found in Exchange Online." -ForegroundColor Green
        Write-Host "🔎 Retrieving Exchange Online distribution group memberships..." -ForegroundColor Cyan

        $userPrincipalName = $exoUser.UserPrincipalName
        $memberOfGroups = Get-Recipient -Identity $userPrincipalName | Select-Object -ExpandProperty MemberOfGroupByDN
        
        $formattedExoGroups = @()
        if ($memberOfGroups) {
            foreach ($groupDN in $memberOfGroups) {
                try {
                    $group = Get-DistributionGroup -Identity $groupDN -ErrorAction Stop
                    if ($group.RecipientTypeDetails -eq "MailUniversalDistributionGroup") {
                         $formattedExoGroups += [PSCustomObject]@{
                            UserEmail   = $EmailAddress # Added for CSV context
                            GroupName   = $group.DisplayName
                            Description = $group.Notes
                            Source      = "Exchange Online"
                            GroupType   = "Distribution"
                        }
                    }
                }
                catch {
                    Write-Warning "Could not retrieve details for Exchange Online group DN: $groupDN. Error: $($_.Exception.Message)"
                }
            }
        }

        Write-Host "✅ Found $($formattedExoGroups.Count) Exchange Online distribution group(s)." -ForegroundColor Green
        return $formattedExoGroups
    }
    catch {
        Write-Error "Error querying Exchange Online: $($_.Exception.Message)"
        return @()
    }
    # Disconnect only if this function instance initiated the connection
    # A global disconnect will still run at the end of the script
    # This is to avoid disconnecting a session that was active before this function ran IF this function didn't create it.
    # However, for simplicity of the overall script, a single disconnect at the end is usually preferred.
    # if ($ownSessionStarted -and (Get-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri *outlook.office365.com* -ErrorAction SilentlyContinue)) {
    #     Write-Host "🚪 Disconnecting from Exchange Online session started by this function..." -ForegroundColor Cyan
    #     Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    # }
}

# --- Main Script Logic ---

Write-Host "🚀 Starting script to find user distribution group memberships..." -ForegroundColor Yellow
Write-Host "------------------------------------------------------------"

# Step 1: Ensure necessary modules are available and attempt to load them.
if (-not (Ensure-ModulesAvailable)) {
    Write-Warning "One or more required PowerShell modules are missing or could not be loaded. Results may be incomplete."
    # Allow script to continue, functions will handle missing modules individually.
}
Write-Host "------------------------------------------------------------"


# Step 2: Validate Email Address Format (Simple Check)
if ($UserEmailAddress -notmatch "^\S+@\S+\.\S+$") {
    Write-Error "❌ Invalid email address format provided: '$UserEmailAddress'. Please enter a valid email address."
    exit 1
}

$allGroups = @()

# Step 3: Get On-Premises Active Directory Groups
Write-Host "`n--- Querying Active Directory ---" -ForegroundColor Magenta
$adUserGroups = Get-ADUserDistributionGroupMembership -EmailAddress $UserEmailAddress
if ($adUserGroups) {
    $allGroups += $adUserGroups
}

# Step 4: Get Exchange Online Groups
Write-Host "`n--- Querying Exchange Online ---" -ForegroundColor Magenta
$exoUserGroups = Get-ExOUserDistributionGroupMembership -EmailAddress $UserEmailAddress
if ($exoUserGroups) {
    $allGroups += $exoUserGroups
}

# Step 5: Display Results and Export to CSV
if ($allGroups.Count -gt 0) {
    Write-Host "`n--- User Distribution Group Memberships for '$UserEmailAddress' ---" -ForegroundColor Green
    # Display on screen
    $allGroups | Sort-Object -Property Source, GroupName | Format-Table -AutoSize -Wrap

    # Prepare for CSV export
    Write-Host "`n--- Exporting results to CSV ---" -ForegroundColor Cyan

    # Check and create C:\Reports directory
    if (-not (Test-Path -Path $ReportsPath)) {
        Write-Host "📂 Reports directory '$ReportsPath' not found. Creating it..." -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Force -Path $ReportsPath -ErrorAction Stop | Out-Null
            Write-Host "✅ Reports directory '$ReportsPath' created successfully." -ForegroundColor Green
        } catch {
            Write-Error "❌ Failed to create reports directory '$ReportsPath': $($_.Exception.Message)"
            Write-Warning "CSV export will be skipped."
            # Optionally exit or set a flag to skip export
        }
    } else {
        Write-Host "📂 Reports directory '$ReportsPath' already exists." -ForegroundColor Green
    }

    # Generate dynamic filename if directory exists or was created
    if (Test-Path -Path $ReportsPath) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        # Sanitize email for filename: replace @ with _at_ and . with _
        $safeEmailPart = $UserEmailAddress -replace "@", "_at_" -replace "\.", "_"
        $csvFileName = "UserDLMembership_${timestamp}_${safeEmailPart}.csv"
        $fullCsvPath = Join-Path -Path $ReportsPath -ChildPath $csvFileName

        try {
            Write-Host "💾 Saving report to: $fullCsvPath" -ForegroundColor Cyan
            $allGroups | Select-Object UserEmail, GroupName, Description, Source, GroupType | Export-Csv -Path $fullCsvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
            Write-Host "✅ Report successfully exported to $fullCsvPath" -ForegroundColor Green
        } catch {
            Write-Error "❌ Failed to export CSV report: $($_.Exception.Message)"
        }
    }
}
else {
    Write-Host "`nℹ️ User '$UserEmailAddress' is not a member of any retrieved distribution groups from Active Directory or Exchange Online, or required modules were not available." -ForegroundColor Yellow
}

# Step 6: Disconnect from Exchange Online (if a session is active)
# This attempts to disconnect any active EXO PSSession.
if ((Get-Module -Name ExchangeOnlineManagement -ErrorAction SilentlyContinue) -and (Get-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri *outlook.office365.com* -ErrorAction SilentlyContinue)) {
    Write-Host "`n🚪 Attempting to disconnect any active Exchange Online session..." -ForegroundColor Cyan
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "✅ Exchange Online disconnection attempt complete." -ForegroundColor Green
}


Write-Host "`n🎉 Script finished." -ForegroundColor Yellow
$ProgressPreference = 'Continue' # Restore progress preference
