$outlookProcess = Get-Process OUTLOOK -ErrorAction SilentlyContinue

if ($outlookProcess) {
    Write-Host "Outlook is already running. Monitoring existing process."
} else {
    Write-Host "Starting Outlook..."
    Start-Process OUTLOOK
    Start-Sleep -Seconds 5
    $outlookProcess = Get-Process OUTLOOK -ErrorAction SilentlyContinue
}

if ($outlookProcess) {
    Write-Host "Monitoring Outlook process (PID: $($outlookProcess.Id))"
    
    while ($true) {
        $currentProcess = Get-Process -Id $outlookProcess.Id -ErrorAction SilentlyContinue
        
        if ($currentProcess) {
            $cpu = $currentProcess.CPU
            $memory = $currentProcess.WorkingSet64 / 1MB
            $diskRead = $currentProcess.ReadOperationCount
            $diskWrite = $currentProcess.WriteOperationCount
            
            Write-Host "CPU: $($cpu.ToString("F2"))% | Memory: $($memory.ToString("F2")) MB | Disk Reads: $diskRead | Disk Writes: $diskWrite"
            
            Start-Sleep -Seconds 2
        } else {
            Write-Host "Outlook process has ended."
            break
        }
    }
} else {
    Write-Host "Failed to start or find Outlook process."
}
