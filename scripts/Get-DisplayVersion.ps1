function Get-InstalledSoftware {
    # Loop until valid input is provided
    do {
        # Prompt the user for input
        $searchString = Read-Host "Please enter a valid string to search for in Display Name (e.g., 'Microsoft')"

        # Check if the input is not empty and contains only valid characters
        if ([string]::IsNullOrWhiteSpace($searchString)) {
            Write-Host "Input cannot be empty or whitespace. Please try again." -ForegroundColor Red
        } elseif ($searchString -match "[^a-zA-Z0-9\s]") {
            Write-Host "Input contains invalid characters. Only letters, numbers, and spaces are allowed. Please try again." -ForegroundColor Red
        } else {
            $isValid = $true
        }
    } while (-not $isValid)

    # Retrieve and filter registry values based on validated user input
    Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
        Where-Object { $_.DisplayName -like "*$searchString*" } |
        Select-Object DisplayName, DisplayVersion
}

# usage
Get-InstalledSoftware


