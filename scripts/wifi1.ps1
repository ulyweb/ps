$interval = 2 # Check interval in seconds
$pingTarget = "google.com"

# Initialize packet loss counters
$totalPings = 0
$failedPings = 0

# Ensure log directory exists
$logDirectory = "C:\Temp"
if (!(Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force
}

# Generate log filename
$logFile = "$logDirectory\WiFiLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log {
    param ($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
}

function Get-WifiInfo {
    $wifiOutput = netsh wlan show interfaces
    $ssid = ($wifiOutput | Select-String 'SSID\s+:' | Select-Object -ExpandProperty Line) -replace '.*:\s+'
    $bssid = ($wifiOutput | Select-String 'BSSID\s+:' | Select-Object -ExpandProperty Line) -replace '.*:\s+'
    $signal = ($wifiOutput | Select-String 'Signal\s+:' | Select-Object -ExpandProperty Line) -replace '.*:\s+'
    $linkSpeed = (Get-NetAdapter | Where-Object {$_.Name -like "*Wi-Fi*" -and $_.Status -eq "Up"}).LinkSpeed

    return @{
        SSID = if ($ssid) { $ssid.Trim() } else { "Hidden SSID" }
        BSSID = $bssid.Trim()
        Signal = $signal.Trim()
        LinkSpeed = $linkSpeed
    }
}

function Test-PacketLoss {
    param($target)
    try {
        $ping = Test-Connection -ComputerName $target -Count 1 -TimeoutSeconds 2 -ErrorAction Stop
        return @{
            Success = $true
            Bytes = $ping.BufferSize
            Time = $ping.ResponseTime
            TTL = $ping.ReplyDetails.TimeToLive
        }
    }
    catch {
        return @{ Success = $false }
    }
}

$previousBSSID = $null
$currentSSID = $null

Write-Log "Starting Wi-Fi monitoring script..."
while ($true) {
    $currentWifi = Get-WifiInfo
    
    if ($currentWifi.SSID -eq "Hidden SSID") {
        Write-Host "Connected to a hidden Wi-Fi network" -ForegroundColor Green
        Write-Log "Connected to a hidden Wi-Fi network"
    }
    else {
        if ($currentWifi.SSID -ne $currentSSID) {
            Write-Host "Connected to Wi-Fi: $($currentWifi.SSID)" -ForegroundColor Green
            Write-Log "Connected to Wi-Fi: $($currentWifi.SSID)"
            $currentSSID = $currentWifi.SSID
        }
        else {
            Write-Host "Current Wi-Fi: $($currentWifi.SSID)" -ForegroundColor Cyan
        }
    }
    
    if ($previousBSSID -and $currentWifi.BSSID -ne $previousBSSID) {
        Write-Host "Switched to a new access point. New BSSID: $($currentWifi.BSSID)" -ForegroundColor Yellow
        Write-Log "Switched to a new access point. New BSSID: $($currentWifi.BSSID)"
    }
    
    # Perform ping test
    $pingResult = Test-PacketLoss -target $pingTarget
    $totalPings++
    if (-not $pingResult.Success) {
        $failedPings++
    }
    
    # Calculate packet loss percentage
    $packetLoss = if ($totalPings -gt 0) { 
        [math]::Round(($failedPings / $totalPings) * 100, 2) 
    } else { 0 }
    
    # Log and display statistics
if ($pingResult.Success) {
    $pingMessage = "Ping to $pingTarget: Bytes=$($pingResult['Bytes']), Time=$($pingResult['Time'])ms, TTL=$($pingResult['TTL'])"
} else {
    $pingMessage = "Ping to $pingTarget failed"
}

    
    $logMessage = "Signal Strength: $($currentWifi.Signal) | Link Speed: $($currentWifi.LinkSpeed) | Packet Loss: $packetLoss% (Total: $totalPings, Failed: $failedPings) | $pingMessage"
    Write-Host $logMessage
    Write-Log $logMessage
    
    $previousBSSID = $currentWifi.BSSID
    Start-Sleep -Seconds $interval
}
