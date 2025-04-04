<#
.SYNOPSIS
    Checks and updates local Administrators group membership, displaying current members.
.DESCRIPTION
    Verifies if the current user is a local admin. If not, adds them and logs the action.
    Requires elevated privileges.
.EXAMPLE
    Update-LocalAdminMembership
#>
function Update-LocalAdminMembership {
    [CmdletBinding()]
    param()

    # Get current user (format: DOMAIN\USER or COMPUTER\USER)
    # $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name #this line will get the current username with a-
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name -replace "^.*?-", "" #but one will remove a-
    # Get current members of the Administrators group
    try {
        $adminMembers = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop | 
                        Select-Object Name, PrincipalSource
        Write-Host "`n[Current Administrators Group Members]`n" -ForegroundColor Cyan
        $adminMembers | Format-Table -AutoSize

        # Check if current user is already a member
        $isMember = $adminMembers.Name -contains $currentUser

        if ($isMember) {
            Write-Host "[INFO] $currentUser is already a member." -ForegroundColor Green
            return $true
        }
        else {
            Write-Warning "$currentUser is NOT a member. Attempting to add..."
            Add-LocalGroupMember -Group "Administrators" -Member $currentUser -ErrorAction Stop
            Write-Host "[SUCCESS] Added $currentUser to Administrators group." -ForegroundColor Cyan
            return $true
        }
    }
    catch {
        Write-Error "[FAILED] Action aborted. Error: $_"
        return $false
    }
}

# Execute the function (run as Administrator)
Update-LocalAdminMembership
