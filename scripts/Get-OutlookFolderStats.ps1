# Function to get Outlook folder statistics
function Get-OutlookFolderStats {
    $outlook = New-Object -ComObject Outlook.Application
    $namespace = $outlook.GetNamespace("MAPI")
    $inbox = $namespace.GetDefaultFolder(6) # 6 represents the Inbox folder

    $stats = @{
        TotalItems = $inbox.Items.Count
        UnreadItems = $inbox.UnReadItemCount
        LastSyncTime = $inbox.LastModificationTime
    }

    return $stats
}

# Main script
Write-Host "Starting Outlook synchronization monitoring..."
$initialStats = Get-OutlookFolderStats

while ($true) {
    Start-Sleep -Seconds 5
    $currentStats = Get-OutlookFolderStats

    $itemDiff = $currentStats.TotalItems - $initialStats.TotalItems
    $unreadDiff = $currentStats.UnreadItems - $initialStats.UnreadItems

    Write-Host "Last Sync: $($currentStats.LastSyncTime)"
    Write-Host "Total Items: $($currentStats.TotalItems) (Change: $itemDiff)"
    Write-Host "Unread Items: $($currentStats.UnreadItems) (Change: $unreadDiff)"
    Write-Host "------------------------"

    $initialStats = $currentStats
}
