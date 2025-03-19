function Show-WlanReport {
    # Generate WLAN Report
    Write-Host "Generating WLAN report..."
    netsh wlan show wlanreport | Out-Null

    # Define the default report path
    $reportPath = "C:\ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html"
    
    # Check if the report exists before opening
    if (Test-Path $reportPath) {
        Write-Host "Opening WLAN report..."
        Start-Process $reportPath
    } else {
        Write-Host "WLAN report not found at expected location: $reportPath" -ForegroundColor Red
    }
}

# Call the function
Show-WlanReport
