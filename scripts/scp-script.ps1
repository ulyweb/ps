<#
.SYNOPSIS
Copies MKV files matching a year pattern to a remote server using SCP.

.DESCRIPTION
This script presents a menu to the user to customize the SCP command.
It allows specifying the source directory, the year pattern for filtering files,
the remote user, the remote host, and the destination directory on the remote host.

.NOTES
Requires the 'scp' command to be available in your system's PATH.
Ensure you have the necessary permissions to access the source directory
and write to the destination directory on the remote server.
#>

# --- Configuration ---
$DefaultSource = "C:\yt"
$DefaultYearPattern = "*2025*"
$DefaultRemoteUser = "root"
$DefaultRemoteHost = "10.17.76.30"
$DefaultRemotePath = "/usb8tb/Shared/Public/Media/Movies/2025"

# --- Functions ---

function Get-Input {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,
        [string]$DefaultValue
    )
    Write-Host "$Prompt (Default: '$DefaultValue'): " -NoNewline
    $Input = Read-Host
    if ([string]::IsNullOrEmpty($Input)) {
        return $DefaultValue
    } else {
        return $Input
    }
}

# --- Main Script ---

Write-Host "--- SCP File Copy Script ---"

# Get Source Directory
$SourceDirectory = Get-Input -Prompt "Enter the source directory" -DefaultValue $DefaultSource
if (-not (Test-Path -Path $SourceDirectory -PathType Container)) {
    Write-Error "Error: Source directory '$SourceDirectory' does not exist."
    exit 1
}

# Get Year Pattern
$YearPattern = Get-Input -Prompt "Enter the year pattern for MKV files (e.g., *2023*, *20*)" -DefaultValue $DefaultYearPattern
$FileFilter = "$YearPattern*.mkv"

# Get Remote User
$RemoteUser = Get-Input -Prompt "Enter the remote username" -DefaultValue $DefaultRemoteUser

# Get Remote Host
$RemoteHost = Get-Input -Prompt "Enter the remote host IP address or hostname" -DefaultValue $DefaultRemoteHost

# Get Remote Destination Path
$RemotePath = Get-Input -Prompt "Enter the remote destination path" -DefaultValue $DefaultRemotePath

# Construct the SCP Command
$SourceFiles = Join-Path -Path $SourceDirectory -ChildPath $FileFilter
$Destination = "$RemoteUser@$RemoteHost:$RemotePath"
$ScpCommand = "scp '$SourceFiles' '$Destination'"

Write-Host "`n--- Ready to execute the following command: ---"
Write-Host $ScpCommand -ForegroundColor Yellow
Write-Host "`n--- Proceed with the copy? (y/N) ---" -NoNewline
$Confirmation = Read-Host

if ($Confirmation -ceq "y") {
    Write-Host "`n--- Initiating file copy... ---"
    try {
        Invoke-Expression $ScpCommand
        Write-Host "`n--- File copy completed successfully. ---" -ForegroundColor Green
    } catch {
        Write-Error "Error during SCP execution: $_"
        exit 1
    }
} else {
    Write-Host "`n--- File copy cancelled by user. ---"
}
