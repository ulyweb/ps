function Start-PerfSpikeTrace {
  param(
    [string]$Name = 'PerfSpike',
    [string]$OutDir = 'C:\Traces'
  )

  # Must be elevated
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

  # Clean up quietly if an old set exists
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
    # Add each provider; if a provider isn't present on a given build, continue
    & logman update trace $Name -p $p.Name $p.Flags $p.Level *> $null
  }

  # Optional: sample top processes every 2s in the background
  Start-Job -Name TopProcs -ScriptBlock {
    $log = 'C:\Traces\TopProcs.csv'
    "Timestamp,CPU(s),WS(MB),ID,Name" | Out-File -Encoding ascii $log
    while ($true) {
      $sample = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 |
        ForEach-Object {
          '{0},{1},{2},{3},{4}' -f (Get-Date).ToString('s'),
            [math]::Round($_.CPU,2),
            [math]::Round(($_.WS/1MB),1),
            $_.Id,$_.ProcessName
        }
      $sample | Out-File -Append -Encoding ascii $log
      Start-Sleep 2
    }
  } | Out-Null

  & logman start $Name -ets *> $null
  "Started trace '$Name'. Reproduce the issue, then run Stop-PerfSpikeTrace."
}

function Stop-PerfSpikeTrace {
  param([string]$Name = 'PerfSpike')
  & logman stop $Name -ets *> $null
  Get-Job -Name TopProcs -ErrorAction SilentlyContinue | Stop-Job -PassThru | Remove-Job | Out-Null
  if ($Global:PerfSpike) {
    & tracerpt $Global:PerfSpike.Etl -o $Global:PerfSpike.Csv -of CSV *> $null
    "Trace:  $($Global:PerfSpike.Etl)`nCSV:    $($Global:PerfSpike.Csv)`nTopProcs (if used): C:\Traces\TopProcs.csv"
  } else {
    "Stopped. (Global metadata not found; run tracerpt on the ETL manually if needed.)"
  }
}
