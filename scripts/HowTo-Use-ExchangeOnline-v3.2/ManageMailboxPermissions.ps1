<#
.SYNOPSIS
Provides a menu-driven interface to manage Exchange Online mailbox permissions (Full Access and Send As).

.DESCRIPTION
This script allows administrators to easily view, add, or remove Full Access and Send As permissions
for specified mailboxes and users within their Microsoft 365 tenant.
It includes basic error handling and confirmation prompts for removal actions.

.NOTES
Author: uly
Date:   2025-03-26
Requires: ExchangeOnlineManagement module, appropriate admin permissions.

.EXAMPLE
.\ManageMailboxPermissions.ps1
Runs the script and displays the main menu.

#>

#Requires -Modules ExchangeOnlineManagement

# --- Configuration ---
# Set to $true if you want the script to attempt connection automatically if not connected.
$AutoConnect = $true
# Set to $true to filter out common system/default permissions for cleaner viewing.
$FilterDefaultPermissions = $true

# --- Functions ---

Function Show-MainMenu {
    Clear-Host
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "   Mailbox Permission Manager" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host " Tenant: $(try { (Get-OrganizationConfig).Name } catch { 'Not Connected' })" -ForegroundColor Yellow
    Write-Host
    Write-Host " 1. View Mailbox Permissions"
    Write-Host " 2. Add Full Access Permission"
    Write-Host " 3. Remove Full Access Permission"
    Write-Host " 4. Add Send As Permission"
    Write-Host " 5. Remove Send As Permission"
    Write-Host " 6. Connect to Exchange Online"
    Write-Host " Q. Quit"
    Write-Host
}

Function Get-MailboxIdentityInput ([string]$PromptMessage) {
    while ($true) {
        $Identity = Read-Host -Prompt $PromptMessage
        if (-not [string]::IsNullOrWhiteSpace($Identity)) {
            return $Identity
        }
        Write-Warning "Mailbox identity cannot be empty. Please try again."
    }
}

Function Get-UserIdentityInput ([string]$PromptMessage) {
    while ($true) {
        $Identity = Read-Host -Prompt $PromptMessage
        if (-not [string]::IsNullOrWhiteSpace($Identity)) {
            return $Identity
        }
        Write-Warning "User identity cannot be empty. Please try again."
    }
}

Function Test-ExchangeConnection {
    # Check if a session command like Get-Mailbox exists
    $isConnected = Get-Command Get-Mailbox -ErrorAction SilentlyContinue
    if ($isConnected) {
        return $true
    } else {
        Write-Warning "Not connected to Exchange Online."
        return $false
    }
}

Function Connect-ToExchange {
    Write-Host "Attempting to connect to Exchange Online..." -ForegroundColor Yellow
    try {
        # Disconnect any existing session first to avoid conflicts
        Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' } | Remove-PSSession -Confirm:$false -ErrorAction SilentlyContinue
        Connect-ExchangeOnline -ShowBanner:$false
        Write-Host "Successfully connected." -ForegroundColor Green
        # Pause briefly to show the connection message
        Start-Sleep -Seconds 1
    } catch {
        Write-Error "Failed to connect to Exchange Online. Please check credentials and permissions. Error: $($_.Exception.Message)"
        Read-Host "Press Enter to return to the menu..."
    }
}

Function View-MailboxPermissions {
    $MailboxIdentity = Get-MailboxIdentityInput "Enter the Mailbox email address or alias to view permissions for"

    Write-Host "`n--- Checking Full Access Permissions for '$MailboxIdentity' ---" -ForegroundColor Yellow
    try {
        $FullAccessPerms = Get-MailboxPermission -Identity $MailboxIdentity -ErrorAction Stop | Where-Object { $_.AccessRights -like '*FullAccess*' }

        if ($FilterDefaultPermissions) {
            # Filter out common system/default entries
            $FullAccessPerms = $FullAccessPerms | Where-Object { $_.User -notlike 'NT AUTHORITY\*' -and $_.IsInherited -eq $false }
        }

        if ($FullAccessPerms) {
            $FullAccessPerms | Format-Table User, AccessRights -AutoSize
        } else {
            Write-Host "No explicit Full Access permissions found (or only default/system permissions)." -ForegroundColor Green
        }
    } catch {
        Write-Error "Error retrieving Full Access permissions for '$MailboxIdentity': $($_.Exception.Message)"
    }

    Write-Host "`n--- Checking Send As Permissions for '$MailboxIdentity' ---" -ForegroundColor Yellow
    try {
        $SendAsPerms = Get-RecipientPermission -Identity $MailboxIdentity -ErrorAction Stop | Where-Object { $_.Trustee -ne $null } # Ensure Trustee exists

         if ($FilterDefaultPermissions) {
             # Filter out common system/default entries
             $SendAsPerms = $SendAsPerms | Where-Object { $_.Trustee -notlike 'NT AUTHORITY\*' -and $_.IsInherited -eq $false }
         }

        if ($SendAsPerms) {
            $SendAsPerms | Format-Table Trustee, AccessRights -AutoSize
        } else {
            Write-Host "No explicit Send As permissions found (or only default/system permissions)." -ForegroundColor Green
        }
    } catch {
        Write-Error "Error retrieving Send As permissions for '$MailboxIdentity': $($_.Exception.Message)"
    }

    Write-Host
    Read-Host "Press Enter to return to the menu..."
}

Function Add-MailboxFullAccess {
    $MailboxIdentity = Get-MailboxIdentityInput "Enter the Mailbox email address or alias"
    $UserIdentity = Get-UserIdentityInput "Enter the User email address or alias to grant Full Access TO"

    Write-Host "`nAttempting to grant Full Access on '$MailboxIdentity' to '$UserIdentity'..." -ForegroundColor Yellow
    try {
        # Check if permission already exists to provide a better message
        $existingPerm = Get-MailboxPermission -Identity $MailboxIdentity -User $UserIdentity -ErrorAction SilentlyContinue
        if ($existingPerm -and ($existingPerm.AccessRights -contains 'FullAccess')) {
             Write-Warning "'$UserIdentity' already has Full Access permission on '$MailboxIdentity'."
        } else {
            Add-MailboxPermission -Identity $MailboxIdentity -User $UserIdentity -AccessRights FullAccess -InheritanceType All -AutoMapping $true -ErrorAction Stop
            # -AutoMapping $true is common, set to $false if you don't want it added to Outlook automatically
            Write-Host "Successfully granted Full Access." -ForegroundColor Green
        }
    } catch {
        Write-Error "Error adding Full Access permission: $($_.Exception.Message)"
    }
    Read-Host "Press Enter to return to the menu..."
}

Function Remove-MailboxFullAccess {
    $MailboxIdentity = Get-MailboxIdentityInput "Enter the Mailbox email address or alias"
    $UserIdentity = Get-UserIdentityInput "Enter the User email address or alias to remove Full Access FROM"

    # Confirmation Prompt
    $confirmation = Read-Host "Are you sure you want to remove Full Access for '$UserIdentity' on '$MailboxIdentity'? (Y/N)"
    if ($confirmation -ne 'Y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        Read-Host "Press Enter to return to the menu..."
        return
    }

    Write-Host "`nAttempting to remove Full Access on '$MailboxIdentity' from '$UserIdentity'..." -ForegroundColor Yellow
    try {
         # Check if permission exists before trying to remove
        $existingPerm = Get-MailboxPermission -Identity $MailboxIdentity -User $UserIdentity -ErrorAction SilentlyContinue
        if ($existingPerm -and ($existingPerm.AccessRights -contains 'FullAccess')) {
             Remove-MailboxPermission -Identity $MailboxIdentity -User $UserIdentity -AccessRights FullAccess -InheritanceType All -Confirm:$false -ErrorAction Stop
             Write-Host "Successfully removed Full Access." -ForegroundColor Green
        } else {
             Write-Warning "Full Access permission for '$UserIdentity' on '$MailboxIdentity' not found."
        }
    } catch {
        Write-Error "Error removing Full Access permission: $($_.Exception.Message)"
    }
    Read-Host "Press Enter to return to the menu..."
}

Function Add-MailboxSendAs {
    $MailboxIdentity = Get-MailboxIdentityInput "Enter the Mailbox email address or alias (the mailbox TO send AS)"
    $UserIdentity = Get-UserIdentityInput "Enter the User/Group email address or alias to grant Send As TO"

    Write-Host "`nAttempting to grant Send As on '$MailboxIdentity' to '$UserIdentity'..." -ForegroundColor Yellow
    try {
        # Check if permission already exists
         $existingPerm = Get-RecipientPermission -Identity $MailboxIdentity -Trustee $UserIdentity -ErrorAction SilentlyContinue
         if ($existingPerm -and ($existingPerm.AccessRights -contains 'SendAs')) {
             Write-Warning "'$UserIdentity' already has Send As permission on '$MailboxIdentity'."
         } else {
            Add-RecipientPermission -Identity $MailboxIdentity -Trustee $UserIdentity -AccessRights SendAs -Confirm:$false -ErrorAction Stop
            Write-Host "Successfully granted Send As permission. Note: It may take some time to propagate." -ForegroundColor Green
         }
    } catch {
        # Specific check for common error when Trustee doesn't exist
        if ($_.Exception.Message -like "*The specified trustee '$UserIdentity' isn't a mailbox, mail user, or security principal*") {
             Write-Error "Error: The user/group '$UserIdentity' specified as the grantee could not be found or is not the correct type."
        }
        elseif ($_.Exception.Message -like "*The specified recipient '$MailboxIdentity' could not be found*"){
             Write-Error "Error: The mailbox '$MailboxIdentity' could not be found."
        }
        else {
            Write-Error "Error adding Send As permission: $($_.Exception.Message)"
        }
    }
    Read-Host "Press Enter to return to the menu..."
}

Function Remove-MailboxSendAs {
    $MailboxIdentity = Get-MailboxIdentityInput "Enter the Mailbox email address or alias (the mailbox FROM which Send As is granted)"
    $UserIdentity = Get-UserIdentityInput "Enter the User/Group email address or alias to remove Send As FROM"

    # Confirmation Prompt
    $confirmation = Read-Host "Are you sure you want to remove Send As for '$UserIdentity' on '$MailboxIdentity'? (Y/N)"
    if ($confirmation -ne 'Y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        Read-Host "Press Enter to return to the menu..."
        return
    }

    Write-Host "`nAttempting to remove Send As on '$MailboxIdentity' from '$UserIdentity'..." -ForegroundColor Yellow
    try {
        # Check if permission exists before trying to remove
        $existingPerm = Get-RecipientPermission -Identity $MailboxIdentity -Trustee $UserIdentity -ErrorAction SilentlyContinue
        if ($existingPerm -and ($existingPerm.AccessRights -contains 'SendAs')) {
            Remove-RecipientPermission -Identity $MailboxIdentity -Trustee $UserIdentity -AccessRights SendAs -Confirm:$false -ErrorAction Stop
            Write-Host "Successfully removed Send As permission. Note: It may take some time for removal to fully propagate." -ForegroundColor Green
        } else {
            Write-Warning "Send As permission for '$UserIdentity' on '$MailboxIdentity' not found."
        }
    } catch {
         # Specific check for common errors
        if ($_.Exception.Message -like "*The specified trustee '$UserIdentity' isn't a mailbox, mail user, or security principal*") {
             Write-Error "Error: The user/group '$UserIdentity' specified as the grantee could not be found or is not the correct type."
        }
        elseif ($_.Exception.Message -like "*The specified recipient '$MailboxIdentity' could not be found*"){
             Write-Error "Error: The mailbox '$MailboxIdentity' could not be found."
        }
         elseif ($_.Exception.Message -like "*isn't assigned to trustee*"){ # Another way the "not found" error presents
             Write-Warning "Send As permission for '$UserIdentity' on '$MailboxIdentity' not found."
         }
        else {
            Write-Error "Error removing Send As permission: $($_.Exception.Message)"
        }
    }
    Read-Host "Press Enter to return to the menu..."
}

# --- Main Script Body ---

# Initial Connection Check / Attempt
if (-not (Test-ExchangeConnection)) {
    if ($AutoConnect) {
        Connect-ToExchange
    } else {
        Write-Warning "You are not connected to Exchange Online. Please use option 6 to connect first."
        Read-Host "Press Enter to continue..."
    }
}

# Main Menu Loop
do {
    Show-MainMenu
    $choice = Read-Host "Enter your choice"

    # Ensure connected before performing actions (except Connect or Quit)
    if ($choice -notin '6', 'Q' -and -not (Test-ExchangeConnection)) {
         Write-Warning "Not connected to Exchange Online. Please connect first using option 6."
         Read-Host "Press Enter to return to the menu..."
         continue # Skip to the next loop iteration
    }

    switch ($choice) {
        '1' { View-MailboxPermissions }
        '2' { Add-MailboxFullAccess }
        '3' { Remove-MailboxFullAccess }
        '4' { Add-MailboxSendAs }
        '5' { Remove-MailboxSendAs }
        '6' { Connect-ToExchange }
        'Q' { Write-Host "Exiting script."; break }
        default {
            Write-Warning "Invalid choice. Please try again."
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne 'Q')

# Optional: Disconnect session on exit
# Write-Host "Disconnecting from Exchange Online..."
# Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' } | Remove-PSSession -Confirm:$false -ErrorAction SilentlyContinue
