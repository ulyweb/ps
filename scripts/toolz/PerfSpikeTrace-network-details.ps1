<#
.DESCRIPTION
DNS/TCP network detail (TCP/IP + DNS Client providers)
A boot capture you can enable for the next reboot, with an auto-stop ~8½ minutes after startup and automatic CSV generation
Everything stays native (logman + tracerpt + a one-time Scheduled Task). No ADK required.
.NOTES

.EXAMPLE
How to use
1) Regular (interactive) capture with DNS/TCP detail
Start-PerfSpikeTrace -IncludeNetDetail
# Reproduce the issue (trace will stop after >8 min OR when CPU >= 100% for 25s)
# Or stop early:
Stop-PerfSpikeTrace


.OUTPUTS
ETW: C:\Traces\PerfSpike.etl
CSV: C:\Traces\PerfSpike-summary.csv
Top processes (optional sampler): C:\Traces\TopProcs.csv
Watchdog log: C:\Traces\PerfSpike.log

.BOOT SCENARIO (next reboot) with optional DNS/TCP detail
# Set up once, then reboot to capture:
Enable-BootPerfSpikeTrace -IncludeNetDetail
# After reboot, it auto-stops ~8m30s after startup and writes the CSV.
# (It also deletes its one-time scheduled task automatically.)
# When done (or to cancel before use):
Disable-BootPerfSpikeTrace

#>

# Run PowerShell as Administrator


function Start-PerfSpikeTrace {
  param(
    [string]$Name = 'PerfSpike',
    [string]$OutDir = 'C:\Traces',
    [int]$AutoStopMinutes = 8,               # auto-stop after this many minutes
    [double]$CpuThresholdPercent = 100.0,    # e.g., 100 = 100%
    [int]$CpuThresholdSeconds = 25,          # consecutive seconds above threshold
    [int]$SampleIntervalSeconds = 1,         # CPU sampling interval
    [switch]$IncludeNetDetail                 # adds TCP/IP + DNS Client providers
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

  Remove-Item -Force -ErrorAction SilentlyContinue $Global:PerfSpike.Flag, $Global:PerfSpike.Done, $Global:PerfSpike.Log

  # Clean up any old set (suppress harmless errors if not present)
  & logman stop   $Name -ets *> $null
  & logman delete $Name -ets *> $null

  # Create the base trace (no providers yet)
  & logman create trace $Name `
      -o $Global:PerfSpike.Etl `
      -ow `
      -bs 1024 `
      -nb 128 640 `
      -max 1024 *> $null

  # Core providers: CPU, Disk/File I/O, Network (kernel), perf sampling
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

  if ($IncludeNetDetail) {
    # Add user-mode network detail: TCP/IP + DNS Client
    $providers += @(
      @{Name='Microsoft-Windows-TCPIP';        Flags='0xFFFFFFFF'; Level='5'}
      @{Name='Microsoft-Windows-DNS-Client';   Flags='0xFFFFFFFF'; Level='5'}
    )
  }

  foreach ($p in $providers) {
    & logman update trace $Name -p $p.Name $p.Flags $p.Level *> $null
  }

  # Lightweight top-process sampler (2s). Exits when $Flag appears.
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

  # Watchdog #1: time-based auto-stop (> N minutes)
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
      if ($val -ge $Threshold) { $over++ } else { $over = 0 }
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
  if ($IncludeNetDetail) { "Network detail enabled: TCPIP + DNS Client providers." | Out-Null }
  "Trace: $($Global:PerfSpike.Etl)"
  "CSV:   $($Global:PerfSpike.Csv) (created on auto/manual stop)"
  "Top processes sampler: $($Global:PerfSpike.Top)"
  "Watchdog log: $($Global:PerfSpike.Log)"
  "Stop early any time with: Stop-PerfSpikeTrace"
}

function Stop-PerfSpikeTrace {
  param([string]$Name = 'PerfSpike')

  if (-not $Global:PerfSpike) {
    & logman stop $Name -ets *> $null
    "Stopped. If you know the ETL path, run:  tracerpt <path>.etl -o <path>.csv -of CSV"
    return
  }

  New-Item -ItemType File -Path $Global:PerfSpike.Flag -Force | Out-Null

  if (-not (Test-Path $Global:PerfSpike.Done)) {
    New-Item -ItemType File -Path $Global:PerfSpike.Done -Force | Out-Null
    & logman stop $Global:PerfSpike.Name -ets *> $null
    & tracerpt $Global:PerfSpike.Etl -o $Global:PerfSpike.Csv -of CSV *> $null
  }

  Get-Job -Name TopProcs, PerfSpikeTimer, PerfSpikeCPU -ErrorAction SilentlyContinue |
    Stop-Job -PassThru | Remove-Job | Out-Null

  "Trace:  $($Global:PerfSpike.Etl)`nCSV:    $($Global:PerfSpike.Csv)`nTopProcs: $($Global:PerfSpike.Top)`nLog:     $($Global:PerfSpike.Log)"
}

# --- Boot capture helpers -----------------------------------------------------

function Enable-BootPerfSpikeTrace {
  <#
    Sets up an **autologger** trace that starts at next boot and
    auto-stops ~8.5 minutes after service start to generate the CSV.
    Also includes optional DNS/TCP detail.
  #>
  param(
    [string]$Name = 'BootPerfSpike',
    [string]$OutDir = 'C:\Traces',
    [int]$AutoStopMinutes = 8,
    [switch]$IncludeNetDetail
  )

  if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
      ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Please run PowerShell as Administrator."
  }

  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

  $Etl = Join-Path $OutDir "$Name.etl"
  $Csv = Join-Path $OutDir "$Name-summary.csv"

  # Clean older definitions if any
  & logman stop   $Name -ets *> $null
  & logman delete $Name -ets *> $null

  # Create autologger (starts at next boot)
  & logman create trace $Name `
      -o $Etl `
      -ow `
      -bs 1024 `
      -nb 128 640 `
      -max 1024 `
      -b boot *> $null   # <- autologger

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
  if ($IncludeNetDetail) {
    $providers += @(
      @{Name='Microsoft-Windows-TCPIP';        Flags='0xFFFFFFFF'; Level='5'}
      @{Name='Microsoft-Windows-DNS-Client';   Flags='0xFFFFFFFF'; Level='5'}
    )
  }

  foreach ($p in $providers) {
    & logman update trace $Name -p $p.Name $p.Flags $p.Level *> $null
  }

  # One-time Scheduled Task to stop the autologger and convert to CSV after boot
  $TaskName = "$Name-Stopper"
  $Command  = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"Start-Sleep -Seconds $([int]([double]$AutoStopMinutes*60)+30); logman stop $Name -ets; tracerpt '$Etl' -o '$Csv' -of CSV; schtasks /Delete /TN '$TaskName' /F`""

  # Remove any old task, then create a new "at startup" task
  schtasks /Delete /TN $TaskName /F *> $null
  schtasks /Create /SC ONSTART /TN $TaskName /TR $Command /RL HIGHEST /F *> $null

  "Boot capture enabled. Reboot to record startup. It will auto-stop ~${AutoStopMinutes}m 30s after boot and write:"
  "  ETL: $Etl"
  "  CSV: $Csv"
  "To disable before/after the run: Disable-BootPerfSpikeTrace"
}

function Disable-BootPerfSpikeTrace {
  param([string]$Name = 'BootPerfSpike')

  & logman stop   $Name -ets *> $null
  & logman delete $Name -ets *> $null
  schtasks /Delete /TN "$Name-Stopper" /F *> $null

  "Boot capture disabled and any stopper task removed."
}
