function Get-InstalledSoftware {
    # Prompt the user for input
    $searchString = Read-Host "Please enter the string to search for in DisplayName"

    # Retrieve and filter registry values based on user input
    Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
        Where-Object { $_.DisplayName -like "*$searchString*" } |
        Select-Object DisplayName, DisplayVersion
}

# Example usage
Get-InstalledSoftware
