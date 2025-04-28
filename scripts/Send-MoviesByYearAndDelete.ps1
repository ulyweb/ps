function Send-MoviesByYearAndDelete {
    [CmdletBinding(SupportsShouldProcess=$true)] # Enables -WhatIf and -Confirm
    param(
        [Parameter(Mandatory=$false)] # Year is now optional, will prompt if missing
        [string]$Year, # e.g., "2024"

        [Parameter(Mandatory=$false)]
        [string]$BaseDestinationPath = 'root@10.17.76.30:/usb8tb/Shared/Public/Media/Movies/', # Fixed base path

        [Parameter(Mandatory=$false)]
        [string]$SourcePath = '.', # Default to current directory

        [Parameter(Mandatory=$false)]
        [switch]$DeleteSource # Switch to enable deletion
    )

    # --- Get Year if not provided via parameter ---
    if ([string]::IsNullOrWhiteSpace($Year)) {
        while ($true) { # Loop until valid input is received
            Write-Host "Destination base path: '$BaseDestinationPath'" -ForegroundColor Cyan
            $YearInput = Read-Host -Prompt "Please enter the 4-digit destination year folder (e.g., $(Get-Date -Format yyyy))"

            # Basic validation: Check if it's a 4-digit number
            if ($YearInput -match '^\d{4}$') {
                $Year = $YearInput
                Write-Host "Using year: $Year" -ForegroundColor Green
                break # Exit the loop
            } elseif ([string]::IsNullOrWhiteSpace($YearInput)) {
                Write-Warning "Input cancelled or empty. Aborting."
                return # Exit the function if user provides no input
            }
            else {
                Write-Warning "'$YearInput' is not a valid 4-digit year. Please try again."
            }
        }
    } else {
        # Validate year even if provided as parameter
        if ($Year -notmatch '^\d{4}$') {
            Write-Error "Invalid Year '$Year' provided via parameter. Please provide a 4-digit year."
            return # Exit if parameter is invalid
        }
         Write-Host "Using provided year: $Year" -ForegroundColor Green
    }

    # --- Construct Dynamic Pattern and Destination ---
    # Use the provided/prompted year for the file pattern
    $FilePattern = "*$Year*.m*" # Files containing the year, ending in .m* (like movie files)

    # Construct the full destination path by appending the year
    # Ensure base path ends with a slash, then add year and final slash for directory target
    $CleanBaseDestination = $BaseDestinationPath.TrimEnd('/') + "/"
    $FullDestination = $CleanBaseDestination + $Year + "/"

    Write-Verbose "Starting file transfer process..."
    Write-Verbose "Source Path: '$SourcePath'"
    Write-Verbose "Calculated File Pattern: '$FilePattern'"
    Write-Verbose "Base Destination: '$BaseDestinationPath'"
    Write-Verbose "Final Destination: '$FullDestination'"
    Write-Verbose "Delete Source Files: $($DeleteSource.IsPresent)"

    # --- Find Files ---
    Write-Verbose "Searching for files..."
    $filesToCopy = Get-ChildItem -Path $SourcePath -Filter $FilePattern -File -ErrorAction SilentlyContinue
    if (-not $filesToCopy) {
        Write-Warning "No files found matching '$FilePattern' in '$SourcePath'."
        return # Exit function if no files found
    }

    $fileCount = $filesToCopy.Count
    Write-Host "Found $fileCount file(s) matching '$FilePattern' to copy:" -ForegroundColor Cyan
    $filesToCopy.Name | ForEach-Object { Write-Host "- $_" }

    # --- Prepare file list for SCP ---
    $sourceFilePaths = $filesToCopy.FullName

    # --- Execute SCP ---
    Write-Verbose "Preparing to execute SCP command..."
    $scpExecutable = "scp.exe" # Ensure scp is in your PATH or provide full path

    # Construct arguments for scp using the calculated FullDestination
    $scpArgs = @()
    $scpArgs += $sourceFilePaths
    $scpArgs += $FullDestination # Use the dynamically constructed path

    Write-Host "Attempting to copy files via SCP to '$FullDestination'..." -ForegroundColor Yellow
    Write-Verbose "Executing: $scpExecutable $($scpArgs -join ' ')"

    # Execute the command
    try {
        & $scpExecutable @scpArgs

        # *** CRITICAL: Check exit code immediately ***
        $exitCode = $LASTEXITCODE
        Write-Verbose "SCP command finished with Exit Code: $exitCode"

        if ($exitCode -eq 0) {
            Write-Host "SCP command completed successfully." -ForegroundColor Green

            # --- Delete Source Files (if requested and successful) ---
            if ($DeleteSource.IsPresent) {
                Write-Host "Attempting to delete source files..." -ForegroundColor Yellow
                foreach ($file in $filesToCopy) {
                    $filePath = $file.FullName
                    Write-Verbose "Processing file for deletion: $filePath"
                    # Check if the action should be performed (-WhatIf support)
                    if ($PSCmdlet.ShouldProcess($filePath, "Delete File after successful SCP to $FullDestination")) {
                        try {
                            Remove-Item -Path $filePath -Force -ErrorAction Stop
                            Write-Host "Deleted: $filePath" -ForegroundColor Green
                        } catch {
                            Write-Error "Failed to delete '$filePath': $_"
                        }
                    } else {
                         Write-Warning "Skipped deletion of '$filePath' due to -WhatIf parameter."
                    }
                }
                 # Check -WhatIf for the overall action summary
                if ($PSCmdlet.ShouldProcess("Source Files matching '$FilePattern'", "Delete")) {
                    Write-Host "Source file deletion process completed." -ForegroundColor Green
                 }
            } else {
                Write-Host "DeleteSource parameter not specified. Source files were not deleted." -ForegroundColor Cyan
            }
        } else {
            Write-Error "SCP command failed with Exit Code: $exitCode. Source files will NOT be deleted."
        }
    } catch {
        Write-Error "An error occurred during the SCP execution or processing: $_"
        Write-Error "Source files will NOT be deleted due to the error."
    }

    Write-Verbose "Function finished."
}
#Sample Commands
#Send-MoviesByYearAndDelete -DeleteSource -Verbose
#
#You can still use -WhatIf for safe testing:
#Send-MoviesByYearAndDelete -DeleteSource -WhatIf -Verbose
