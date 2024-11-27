# Reset network settings and reinstall network drivers
Try {
    netsh winsock reset
    netsh int ip reset
    ipconfig /flushdns
    ipconfig /release
    ipconfig /renew

    Write-Output "Network settings reset and drivers reinstalled."
    
    Write-Output "Press any key to reboot the system..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    Restart-Computer
} Catch {
    Write-Output "An error occurred: $_"
}
