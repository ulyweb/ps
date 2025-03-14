function Refresh-NetworkConfig {
    [CmdletBinding()]
    param ()

    Write-Host "Releasing IP address..." -ForegroundColor Yellow
    ipconfig /release

    Write-Host "Renewing IP address..." -ForegroundColor Yellow
    ipconfig /renew

    Write-Host "Flushing DNS cache..." -ForegroundColor Yellow
    Clear-DnsClientCache

    Write-Host "Network configuration refreshed successfully!" -ForegroundColor Green
}
