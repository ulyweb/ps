function Start-PerfSpikeTrace {
  param(
    [string]$Name = 'PerfSpike',
    [string]$OutDir = 'C:\Traces'
  )
  if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
      ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Please run PowerShell as Administrator."
  }
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  $Global:PerfSpike = [pscustomobject]@{
    Name = $Name
    Etl  = Join-Path $OutDir "$Name.etl"
    Csv  = Join-Path $OutDir "$Name-summary.csv"
  }

  logman stop   $Name -ets 2>$null
  logman delete $Name -ets 2>$null

  logman create trace $Name `
    -o $Global:PerfSpike.Etl `
    -ow `
    -bs 1024 `
    -nb 128 640 `
    -max 1024 `
    -p "Microsoft-Windows-Kernel-Process" 0xFFFFFFFF 5 `
    -p "Microsoft-Windows-Kernel-Thread"  0xFFFFFFFF 5 `
    -p "Microsoft-Windows-Kernel-Image"   0xFFFFFFFF 5 `
    -p "Microsoft-Windows-Kernel-File"    0xFFFFFFFF 5 `
    -p "Microsoft-Windows-Kernel-IO"      0xFFFFFFFF 5 `
    -p "Microsoft-Windows-Kernel-Network" 0xFFFFFFFF 5 `
    -p "Microsoft-Windows-Kernel-PerfInfo" 0xFFFFFFFF 5 `
    -p "Microsoft-Windows-Kernel-SampledProfile" 0xFFFFFFFF 5

  # Optional helper: sample top processes every 2s
  Start-Job -Name TopProcs -ScriptBlock {
    $log = 'C:\Traces\TopProcs.csv'
    "Timestamp,CPU(s),WS(MB),ID,Name" | Out-File -Encoding ascii $log
    while ($true) {
      $sample = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 `
        | ForEach-Object {
            '{0},{1},{2},{3},{4}' -f (Get-Date).ToString('s'),
               [math]::Round($_.CPU,2),
               [math]::Round(($_.WS/1MB),1),
               $_.Id,$_.ProcessName
          }
      $sample | Out-File -Append -Encoding ascii $log
      Start-Sleep 2
    }
  } | Out-Null

  logman start $Name -ets
  "Started trace '$Name'. Reproduce the issue, then run Stop-PerfSpikeTrace."
}

function Stop-PerfSpikeTrace {
  param([string]$Name = 'PerfSpike')
  logman stop $Name -ets | Out-Null
  Get-Job -Name TopProcs -ErrorAction SilentlyContinue | Stop-Job -PassThru | Remove-Job | Out-Null
  if ($Global:PerfSpike) {
    tracerpt $Global:PerfSpike.Etl -o $Global:PerfSpike.Csv -of CSV | Out-Null
    "Trace:  $($Global:PerfSpike.Etl)`nCSV:    $($Global:PerfSpike.Csv)`nTopProcs (if used): C:\Traces\TopProcs.csv"
  } else {
    "Stopped. (Global metadata not found; run tracerpt on the ETL manually if needed.)"
  }
}
