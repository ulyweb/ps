while ($true) {
    $signal = (netsh wlan show interfaces) -Match '^\s+Signal' -Replace '^\s+Signal\s+:\s+',''
    Write-Output "Signal Strength: $signal%"
    Start-Sleep -Seconds 10
}
