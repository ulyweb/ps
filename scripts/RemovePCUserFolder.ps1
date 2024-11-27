
Clear-Host
# Display a message requiring admin access on PowerShell ISE
Write-Host " Require Admin access on Powershell  "  -ForegroundColor White
# Display a message to prompt for the remote computer's IP and MAC address
Write-Host " It will display the remote computer Hostname and IP Address:  "  -ForegroundColor White
Write-Host " and the USERS folder directories: "  -ForegroundColor White
Write-Host "[ Please enter the ComputerName of the machine: ] " -NoNewline -ForegroundColor Green
$computerName = Read-Host
Write-Host


if (Test-Connection -ComputerName $computerName -Count 1 -Quiet) {
    # If the machine is online, get its IP address
    $ipAddress = [System.Net.Dns]::GetHostAddresses($computerName) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -ExpandProperty IPAddressToString

    # Display the hostname and IP address
    Write-Host "Hostname: " -ForegroundColor White -NoNewline
    Write-Host "$computerName" -ForegroundColor Green
    Write-Host "IP Address: " -ForegroundColor White -NoNewline
    Write-Host "$ipAddress" -ForegroundColor Green

    # Get the current date and time
    $currentDateTime = Get-Date

    # Display the current date and time
    Write-Host "Date and Time: " -ForegroundColor White -NoNewline
    Write-Host "$currentDateTime" -ForegroundColor Green

    # List the user's folder using WMI
    $userFolders = Get-WmiObject -ComputerName $computerName -Query "SELECT Name, CreationDate FROM CIM_Directory WHERE Drive='C:' AND Path='\\Users\\'"

    Write-Host "User Folders: " -ForegroundColor White
    foreach ($folder in $userFolders) {
        $creationDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($folder.CreationDate)
        Write-Host "$($folder.Name) - Created on: $creationDate" -ForegroundColor Green
    }
} else {
    Write-Host "The computer $computerName is not reachable." -ForegroundColor Red
}


# Keep the window open
Write-Host "Press any key to exit..."
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
