# Run PowerShell as Administrator


## Reproduce the issue. The trace will auto-stop:
##  - after >8 minutes, OR
##  - when CPU >= 100% for 25 consecutive seconds.
## You can also stop early:
# USAGE: TO Start type in: Start-PerfSpikeTrace
# USAGE: To Stop type in: Stop-PerfSpikeTrace

## If you want different thresholds later, change the defaults:
# USAGE:  Start-PerfSpikeTrace -AutoStopMinutes 10 -CpuThresholdPercent 95 -CpuThresholdSeconds 15



function Start-PerfSpikeTrace {
  param(
    [string]$Name = 'PerfSpike',
    [string]$OutDir = 'C:\Traces',
    [int]$AutoStopMinutes = 8,               # auto-stop after this many minutes
    [double]$CpuThresholdPercent = 100.0,    # e.g., 100 = 100%
    [int]$CpuThresholdSeconds = 25,          # consecutive seconds above threshold
    [int]$SampleIntervalSeconds = 1          # CPU sampling interval
  )

  # Must be elevated
  if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
      ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Please run PowerShell as Administrator."
  }

  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

  $Global:PerfSpike = [pscustomobject]@{
    Name  = $Name
    Etl   = Join-Path $OutDir "$Name.etl"
    Csv   = Join-Path $OutDir "$Name-summary.csv"
    Top   = Join-Path $OutDir "TopProcs.csv"
    Flag  = Join-Path $OutDir "$Name.autostop.flag"  # tells jobs to exit
    Done  = Join-Path $OutDir "$Name.done"           # ensures stop runs once
    Log   = Join-Path $OutDir "$Name.log"            # basic log from watchdogs
  }

  # Reset flags/logs
  Remove-Item -Force -ErrorAction SilentlyContinue $Global:PerfSpike.Flag, $Global:PerfSpike.Done, $Global:PerfSpike.Log

  # Clean up any old set (suppress harmless errors)
  & logman stop   $Name -ets *> $null
  & logman delete $Name -ets *> $null

  # Create the base trace (no providers yet)
  & logman create trace $Name `
      -o $Global:PerfSpike.Etl `
      -ow `
      -bs 1024 `
      -nb 128 640 `
      -max 1024 *> $null

  # Add providers one by one (CPU, Disk/File I/O, Network, sampling, etc.)
  $providers = @(
    @{Name='Microsoft-Windows-Kernel-Process';         Flags='0xFFFFFFFF'; Level='5'}
    @{Name='Microsoft-Windows-Kernel-Thread';          Flags='0xFFFFFFFF'; Level='5'}
    @{Name='Microsoft-Windows-Kernel-Image';           Flags='0xFFFFFFFF'; Level='5'}
    @{Name='Microsoft-Windows-Kernel-File';            Flags='0xFFFFFFFF'; Level='5'}
    @{Name='Microsoft-Windows-Kernel-IO';              Flags='0xFFFFFFFF'; Level='5'}
    @{Name='Microsoft-Windows-Kernel-Network';         Flags='0xFFFFFFFF'; Level='5'}
    @{Name='Microsoft-Windows-Kernel-PerfInfo';        Flags='0xFFFFFFFF'; Level='5'}
    @{Name='Microsoft-Windows-Kernel-SampledProfile';  Flags='0xFFFFFFFF'; Level='5'}
  )
  foreach ($p in $providers) {
    & logman update trace $Name -p $p.Name $p.Flags $p.Level *> $null
  }

  # Optional: sample top processes every 2s; exits when $Flag appears
  Start-Job -Name TopProcs -ScriptBlock {
    param($TopPath, $FlagPath, $Interval)
    "Timestamp,CPU(s),WS(MB),ID,Name" | Out-File -Encoding ascii $TopPath
    while ($true) {
      if (Test-Path $FlagPath) { break }
      $sample = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 |
        ForEach-Object {
          '{0},{1},{2},{3},{4}' -f (Get-Date).ToString('s'),
            [math]::Round($_.CPU,2),
            [math]::Round(($_.WS/1MB),1),
            $_.Id,$_.ProcessName
        }
      $sample | Out-File -Append -Encoding ascii $TopPath
      Start-Sleep -Seconds $Interval
    }
  } -ArgumentList $Global:PerfSpike.Top, $Global:PerfSpike.Flag, 2 | Out-Null

  # Watchdog #1: Time-based auto-stop (> N minutes)
  Start-Job -Name PerfSpikeTimer -ScriptBlock {
    param($Name, $Etl, $Csv, $FlagPath, $DonePath, $Minutes, $LogPath)
    Start-Sleep -Seconds ([int]([double]$Minutes * 60))
    if (-not (Test-Path $DonePath)) {
      New-Item -ItemType File -Path $DonePath -Force | Out-Null
      "[$(Get-Date -Format s)] Timer fired ($Minutes min). Stopping trace." | Out-File -Append -Encoding ascii $LogPath
      New-Item -ItemType File -Path $FlagPath -Force | Out-Null
      & logman stop $Name -ets *> $null
      & tracerpt $Etl -o $Csv -of CSV *> $null
      "[$(Get-Date -Format s)] Timer completed stop and CSV." | Out-File -Append -Encoding ascii $LogPath
    }
  } -ArgumentList $Global:PerfSpike.Name, $Global:PerfSpike.Etl, $Global:PerfSpike.Csv, $Global:PerfSpike.Flag, $Global:PerfSpike.Done, $AutoStopMinutes, $Global:PerfSpike.Log | Out-Null

  # Watchdog #2: CPU threshold (≥ X% for Y consecutive seconds)
  Start-Job -Name PerfSpikeCPU -ScriptBlock {
    param($Name, $Etl, $Csv, $FlagPath, $DonePath, $Threshold, $ConsecSecs, $Interval, $LogPath)
    $path = '\Processor(_Total)\% Processor Time'
    $over = 0
    while ($true) {
      if (Test-Path $FlagPath) { break }
      try {
        $val = (Get-Counter -Counter $path -SampleInterval $Interval -MaxSamples 1).CounterSamples[0].CookedValue
      } catch {
        Start-Sleep -Seconds $Interval
        continue
      }
      if ($val -ge $Threshold) {
        $over++
      } else {
        $over = 0
      }
      if ($over -ge $ConsecSecs) {
        if (-not (Test-Path $DonePath)) {
          New-Item -ItemType File -Path $DonePath -Force | Out-Null
          "[$(Get-Date -Format s)] CPU watchdog fired: $val% >= $Threshold% for $ConsecSecs sec. Stopping trace." | Out-File -Append -Encoding ascii $LogPath
          New-Item -ItemType File -Path $FlagPath -Force | Out-Null
          & logman stop $Name -ets *> $null
          & tracerpt $Etl -o $Csv -of CSV *> $null
          "[$(Get-Date -Format s)] CPU watchdog completed stop and CSV." | Out-File -Append -Encoding ascii $LogPath
        }
        break
      }
    }
  } -ArgumentList $Global:PerfSpike.Name, $Global:PerfSpike.Etl, $Global:PerfSpike.Csv, $Global:PerfSpike.Flag, $Global:PerfSpike.Done, $CpuThresholdPercent, $CpuThresholdSeconds, $SampleIntervalSeconds, $Global:PerfSpike.Log | Out-Null

  # Start ETW
  & logman start $Name -ets *> $null

  "Started trace '$Name'. Auto-stop: > $AutoStopMinutes min OR CPU >= $CpuThresholdPercent% for $CpuThresholdSeconds sec."
  "Trace: $($Global:PerfSpike.Etl)"
  "CSV:   $($Global:PerfSpike.Csv) (created on auto/ manual stop)"
  "Top processes sampler: $($Global:PerfSpike.Top)"
  "Watchdog log: $($Global:PerfSpike.Log)"
  "When done (or if you want to stop early), run: Stop-PerfSpikeTrace"
}

function Stop-PerfSpikeTrace {
  param([string]$Name = 'PerfSpike')

  if (-not $Global:PerfSpike) {
    # Best effort stop when metadata missing
    & logman stop $Name -ets *> $null
    "Stopped. If you know the ETL path, run:  tracerpt <path>.etl -o <path>.csv -of CSV"
    return
  }

  # Signal background jobs to exit loops
  New-Item -ItemType File -Path $Global:PerfSpike.Flag -Force | Out-Null

  # Ensure single-stop behavior
  if (-not (Test-Path $Global:PerfSpike.Done)) {
    New-Item -ItemType File -Path $Global:PerfSpike.Done -Force | Out-Null
    & logman stop $Global:PerfSpike.Name -ets *> $null
    & tracerpt $Global:PerfSpike.Etl -o $Global:PerfSpike.Csv -of CSV *> $null
  }

  # Clean up local jobs
  Get-Job -Name TopProcs, PerfSpikeTimer, PerfSpikeCPU -ErrorAction SilentlyContinue |
    Stop-Job -PassThru | Remove-Job | Out-Null

  "Trace:  $($Global:PerfSpike.Etl)`nCSV:    $($Global:PerfSpike.Csv)`nTopProcs: $($Global:PerfSpike.Top)`nLog:     $($Global:PerfSpike.Log)"
}
