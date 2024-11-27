# Clear the host display
Clear-Host

# Function to get credentials securely
function Get-Credentials {
    param (
        [string]$domain,
        [string]$username
    )
    $fullUsername = "$domain\$username"
    return Get-Credential -UserName $fullUsername -Message "Enter password for $fullUsername"
}

# Function to get remote computer information
function Get-RemoteComputerInfo {
    param (
        [string]$computerName
    )

    if (Test-Connection -ComputerName $computerName -Count 1 -Quiet) {
        try {
            # Get IP address
            $ipAddress = [System.Net.Dns]::GetHostAddresses($computerName) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -ExpandProperty IPAddressToString

            # Get MAC address
            $macAddress = Invoke-Command -ComputerName $computerName -ScriptBlock {
                Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE | Select-Object -ExpandProperty MACAddress
            }

            # Get BIOS version
            $biosVersion = Invoke-Command -ComputerName $computerName -ScriptBlock {
                Get-WmiObject -Class Win32_BIOS | Select-Object -ExpandProperty SMBIOSBIOSVersion
            }

            # Get Administrators group members
            $adminGroupMembers = Invoke-Command -ComputerName $computerName -ScriptBlock {
                Get-LocalGroupMember -Name 'Administrators' | Select-Object Name, ObjectClass, PrincipalSource
            }

            # Get Wireless INFO
            $WiFi = Invoke-Command -ComputerName $computerName -ScriptBlock {
                Get-NetAdapter -Physical
            }
            $WiFiINFO = $WiFi | Select Name, MacAddress, LinkSpeed, AdminStatus, DriverDescription

            return @{
                IPAddress = $ipAddress
                MACAddress = $macAddress
                BIOSVersion = $biosVersion
                AdminGroupMembers = $adminGroupMembers
                WiFiINFO = $WiFiINFO
            }
        } catch {
            Write-Host "An error occurred: $_" -ForegroundColor Red
            return $null
        }
    } else {
        Write-Host "System $computerName is currently offline." -ForegroundColor Red
        return $null
    }
}

# Function to display remote computer information
function Display-RemoteComputerInfo {
    param (
        [hashtable]$info,
        [string]$computerName
    )

    if ($info) {
        Write-Host "Hostname: " -ForegroundColor White -NoNewline
        Write-Host "$computerName" -ForegroundColor Green
        Write-Host "IP Address: " -ForegroundColor White -NoNewline
        Write-Host "$($info.IPAddress)" -ForegroundColor Green
        Write-Host "MAC Address: " -ForegroundColor White -NoNewline
        Write-Host "$($info.MACAddress)" -ForegroundColor Green
        Write-Host "Current BIOS Version: " -ForegroundColor White -NoNewline
        Write-Host "$($info.BIOSVersion)" -ForegroundColor Green
        Write-Host
        Write-Host "|------------------------------|" -ForegroundColor Cyan

        Write-Host "Administrators Group Members:" -ForegroundColor White
        $info.AdminGroupMembers | Format-Table

        Write-Host "Name         MacAddress               LinkSpeed     Status      DriverDescription" -ForegroundColor White
        foreach ($adapter in $info.WiFiINFO) {
            Write-Host ($adapter.Name + "        ") -NoNewline -ForegroundColor Cyan
            Write-Host ($adapter.MacAddress + "        ") -NoNewline -ForegroundColor Cyan
            Write-Host ($adapter.LinkSpeed + "        ") -NoNewline -ForegroundColor Green
            Write-Host ($adapter.AdminStatus + "        ") -NoNewline -ForegroundColor Blue
            Write-Host ($adapter.DriverDescription) -ForegroundColor Cyan
        }
    }
}

# Function to log computer name
function Log-ComputerName {
    param (
        [string]$computerName
    )

    $logFolderPath = "C:\log"
    if (-not (Test-Path -Path $logFolderPath)) {
        New-Item -ItemType Directory -Path $logFolderPath
    }

    $logFilePath = "$logFolderPath\remote_log.txt"
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $computerName"
    Add-Content -Path $logFilePath -Value $logEntry
}

# Main script execution
$domain = Read-Host "Enter domain"
$username = Read-Host "Enter username"
$credential = Get-Credentials -domain $domain -username $username

Write-Host "Require Admin access on PowerShell ISE" -ForegroundColor White
Write-Host "To display the remote computer IP and MAC Address:" -ForegroundColor White
Write-Host
Write-Host "[Please enter the ComputerName of the machine:]" -NoNewline -ForegroundColor Green
$computerName = Read-Host
Write-Host

$info = Get-RemoteComputerInfo -computerName $computerName
Display-RemoteComputerInfo -info $info -computerName $computerName
Log-ComputerName -computerName $computerName

# Create a new PowerShell session and enter it
$Session = New-PSSession -ComputerName $computerName -ErrorAction SilentlyContinue
Enter-PSSession -Session $Session -ErrorAction SilentlyContinue

# Keep the window open
Write-Host "Press any key to exit..."
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
