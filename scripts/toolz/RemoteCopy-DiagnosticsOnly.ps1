# SCRIPT: RemoteCopy-DiagnosticsOnly.ps1
# PURPOSE: Connects to a remote machine, copies ALL .dmp files from C:\Windows\Minidump, 
#          and cleans up the session.

# --- USER CONFIGURATION (Required) ---
$ComputerName = Read-Host 'ComputerName (e.g., UserPC01 or IP)'
if ([string]::IsNullOrWhiteSpace($ComputerName)) {
    throw 'ComputerName is required.'
}

# --- LOCAL PATHS ---
# Create a unique folder based on the remote computer name for organization
$LocalDestination = "C:\IT_Folder\Minidump-temp\$ComputerName" 

# --- 1. SESSION CREATION ---
try {
    Write-Host ("Creating session to {0}..." -f $ComputerName) -ForegroundColor Yellow
    # Create the session object
    $session = New-PSSession -ComputerName $ComputerName -ErrorAction Stop
}
catch {
    Write-Error "Failed to create session to $ComputerName. Check permissions and WinRM status."
    return
}

# --- 2. REMOTE DIAGNOSTICS: COPY DUMP FILES ---
try {
    # 2a. Define the remote Minidump path
    $RemoteDumpPath = "C:\Windows\Minidump\"
    
    # 2b. Find all dump files on the remote machine
    # Note: We use Invoke-Command to ensure we are searching the remote filesystem.
    $RemoteFiles = Invoke-Command -Session $session -ScriptBlock {
        Get-ChildItem -Path $using:RemoteDumpPath -Filter *.dmp -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    }

    if ($RemoteFiles -and $RemoteFiles.Count -gt 0) {
        # 2c. Ensure local destination exists
        if (-not (Test-Path $LocalDestination)) {
            New-Item -Path $LocalDestination -ItemType Directory -Force | Out-Null
        }
        
        Write-Host "Copying $($RemoteFiles.Count) dump file(s) from $ComputerName to $LocalDestination..." -ForegroundColor Green
        
        # 2d. Copy all files from the remote location to the local destination
        # We loop through the files to use Copy-Item with the -FromSession parameter
        foreach ($File in $RemoteFiles) {
            Copy-Item -Path $File -Destination $LocalDestination -FromSession $session -Force
        }
        
        Write-Host "Dump files successfully copied to $LocalDestination."
    } else {
        Write-Host "No dump files found in $RemoteDumpPath on $ComputerName."
    }
}
catch {
    Write-Error "Error copying dump files: $($_.Exception.Message)"
}


# --- 3. CLEANUP ---
Write-Host "Cleaning up session..."
Remove-PSSession -Session $session
Write-Host "Diagnostics complete."
