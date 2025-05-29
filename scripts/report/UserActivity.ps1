Clear-host
# Prompt for computer and number of days
$computer = Read-Host "Enter the computer name to query (e.g. localhost or remote name)"
$daysBack = Read-Host "Enter how many days of history you'd like to include (e.g. 7)"

# Setup report folder
$reportFolder = "C:\Reports"
if (-not (Test-Path $reportFolder)) {
    New-Item -Path $reportFolder -ItemType Directory | Out-Null
}

$daysBack = [int]$daysBack

try {
    Write-Host "Gathering lock/unlock events from $computer for the past $daysBack days..." -ForegroundColor Cyan

    # Fetch events
    $events = Get-WinEvent -ComputerName $computer -FilterHashtable @{
        LogName    = 'Security'
        Id         = 4800, 4801
        StartTime  = (Get-Date).AddDays(-$daysBack)
    } -ErrorAction Stop

    # Build structured data
    $structured = $events | ForEach-Object {
        [PSCustomObject]@{
            User      = $_.Properties[1].Value
            Date      = $_.TimeCreated.Date
            TimeStamp = $_.TimeCreated
            Action    = if ($_.Id -eq 4800) { "Locked" } else { "Unlocked" }
            Computer  = $computer
        }
    } | Sort-Object User, TimeStamp

    $results = @()

    # Group by User + Date
    $grouped = $structured | Group-Object User, Date
    foreach ($group in $grouped) {
        $user = $group.Group[0].User
        $date = $group.Group[0].Date
        $eventsForDay = $group.Group

        $unlocked = $eventsForDay | Where-Object { $_.Action -eq "Unlocked" } | Select-Object -ExpandProperty TimeStamp
        $locked   = $eventsForDay | Where-Object { $_.Action -eq "Locked" }   | Select-Object -ExpandProperty TimeStamp

        $sessions = @()
        for ($i = 0; $i -lt [Math]::Min($unlocked.Count, $locked.Count); $i++) {
            $start = $unlocked[$i]
            $end   = $locked[$i]
            if ($end -gt $start) {
                $sessions += ($end - $start)
            }
        }

        $totalSeconds = ($sessions | Measure-Object -Property TotalSeconds -Sum).Sum
        $totalTime = [TimeSpan]::FromSeconds($totalSeconds)

        $results += [PSCustomObject]@{
            User               = $user
            Date               = $date.ToString("MM/dd/yyyy")
            Login_Count        = $unlocked.Count
            Logout_Count       = $locked.Count
            Hours_Worked       = "{0:N2}" -f $totalTime.TotalHours
            Computer           = $computer
        }
    }

    if ($results.Count -eq 0) {
        Write-Host "⚠️ No lock/unlock sessions found." -ForegroundColor Yellow
    } else {
        $results | Sort-Object User, Date | Format-Table -AutoSize

        # Create timestamped filename
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $filename  = "UserActivityReport_${computer}_$timestamp.csv"
        $exportPath = Join-Path -Path $reportFolder -ChildPath $filename

        $results | Export-Csv -Path $exportPath -NoTypeInformation
        Write-Host "`n✅ Report saved to: $exportPath" -ForegroundColor Green
    }

} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
}
