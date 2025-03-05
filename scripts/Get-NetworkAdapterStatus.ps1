try {

function Get-NetworkAdapterStatus {
    $adapters = Get-NetAdapter | Where-Object { $_.PhysicalMediaType -match 'Wi-Fi|802.11|802.3|Ethernet' }
    
    foreach ($adapter in $adapters) {
        $status = if ($adapter.Status -eq 'Up') { "Active" } else { "Not Active" }
        $type = if ($adapter.PhysicalMediaType -eq '802.11') { "Wi-Fi" } else { "Ethernet" }
        $ipAddress = (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4).IPAddress
        
        [PSCustomObject]@{
            Name = $adapter.Name
            Type = $type
            Status = $status
            Description = $adapter.InterfaceDescription
            MACAddress = $adapter.MacAddress
            IPAddress = $ipAddress
        }
    }
}


function Display-NetworkStatus {
    $adapterStatus = Get-NetworkAdapterStatus
    
    Write-Host "Network Adapter Status:"
    Write-Host "------------------------"
    
    foreach ($adapter in $adapterStatus) {
        Write-Host "Name: $($adapter.Name)"
        Write-Host "Type: $($adapter.Type)"
        Write-Host "Status: $($adapter.Status)"
        Write-Host "Description: $($adapter.Description)"
        Write-Host "MAC Address: $($adapter.MACAddress)"
        Write-Host "IP Address: $($adapter.IPAddress)"
        Write-Host "------------------------"
    }
    
    $activeAdapters = $adapterStatus | Where-Object { $_.Status -eq 'Active' }
    if ($activeAdapters) {
        Write-Host "Currently Active Connection(s):"
        foreach ($active in $activeAdapters) {
            Write-Host "- $($active.Type) ($($active.Name))"
            Write-Host "  IP: $($active.IPAddress), MAC: $($active.MACAddress)"
        }     # Keep the window open
    
    } else {
        Write-Host "No active network connections found."
    }
}

# Call the function to display network status
Display-NetworkStatus
Read-Host "Press Enter to exit"

} catch {
# Allow PowerShell to be used again immediately
Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
Read-Host "Press Enter to exit"
}
