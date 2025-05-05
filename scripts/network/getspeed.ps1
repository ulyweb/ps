$url = "http://cachefly.cachefly.net/100mb.test" # Example URL
$output = "C:\temp\testfile.tmp" # Temporary file path
$wc = New-Object System.Net.WebClient
$start = Get-Date
$wc.DownloadFile($url, $output)
$end = Get-Date
$time = ($end - $start).TotalSeconds
# Calculate speed (e.g., 100 MB / time in seconds * 8 = Mbps)
$speedMbps = (100 / $time) * 8
Write-Host "Estimated Download Speed: $($speedMbps.ToString('F2')) Mbps"
Remove-Item $output # Clean up
