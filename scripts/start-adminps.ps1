function ElevatedAdminSession {
    <#
    .SYNOPSIS
        Starts an elevated PowerShell session using an alternate admin account.

    .DESCRIPTION
        Constructs a username of the form "DOMAIN\a-username", prompts for credentials,
        then launches a new elevated PowerShell session under that account using PowerShell 7+.

    .NOTES
        Requires PowerShell 7.5.1+ and admin privileges.
    #>

    Clear-Host

    # Construct admin-style username
    $adminUser = "$($env:USERDOMAIN)\a-$($env:USERNAME)"

    # Prompt for credentials
    try {
        $secureCred = Get-Credential -UserName $adminUser -Message "Enter credentials for $adminUser"
    } catch {
        Write-Warning "Credential prompt was canceled or failed."
        return
    }

    # Launch a new elevated PowerShell session under provided credentials
    try {
        Start-Process powershell -Credential $secureCred -ArgumentList '-NoProfile -Command &{ Start-Process powershell -Verb RunAs }'
    } catch {
        Write-Error "Failed to start elevated session: $_"
    }
}

ElevatedAdminSession
