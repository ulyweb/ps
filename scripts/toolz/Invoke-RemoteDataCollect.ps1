<#
.SYNOPSIS
  Invokes a remote PowerShell session on a target computer, executes an embedded data collection script (events and system status), retrieves the output files locally, and cleans up the remote worker file.

.DESCRIPTION
  This script is designed for portability, containing all necessary logic to connect to a remote host (via PSSession), dynamically deploy a worker script to C:\Temp, run that script with specified arguments, download the resulting CSVs, and automatically remove the worker script from the remote host.

.PARAMETER ComputerName
  The name or IP address of the remote computer to connect to. (Required)

.PARAMETER Date
  The date (e.g., YYYY-MM-DD) for which system events should be collected. (Required)

.NOTES
  - All-in-one script. No external dependencies.
  - Requires minimal input: ComputerName and Date.
  - Automatically saves results to the local C:\Temp folder and opens it upon completion.
  - Assumes current user has WinRM and administrative rights on the target host.

.EXAMPLE
  .\Invoke-RemoteDataCollect.ps1
  # The script will prompt for the ComputerName and Date.
#>

$ErrorActionPreference = 'Stop'

Write-Host '=== Invoke-RemoteDataCollect (All-in-One) ===' -ForegroundColor Cyan

# --- BEGIN EMBEDDED WORKER SCRIPT CONTENT ---
# This is the worker script that runs on the remote machine.
$RemoteWorkerScriptContent = @"
<#
RemoteEventsWorker.ps1 (Embedded Worker Script)
Purpose:
  - Collect key crash and session events for a specific date, including reboots and service failures.
  - Emit current memory, disk space, and pagefile configuration/usage.
#>

param(
  [Parameter(Mandatory=`$false)][string]`$ComputerName = 'localhost',
  [Parameter(Mandatory=`$true )][string]`$Date,
  [System.Management.Automation.PSCredential]`$Credential
)

function Parse-DateRange {
  param([string]`$DateString)
  try { `$start = [datetime]::Parse(`$DateString) }
  catch { throw ("Could not parse date string '{{0}}'. Use yyyy-MM-dd or ISO formats." -f `$DateString) }
  `$end = `$start.AddDays(1)
  return @{ Start = `$start; End = `$end }
}

function Export-EventsCsv {
  param(`$Events, [string]`$Path)
  if (-not `$Events -or `$Events.Count -eq 0) {
    # Create an empty CSV with headers for consistency
    `$nullObj = "" | Select-Object @{n='TimeCreated';e={""}}, @{n='ProviderName';e={""}}, @{n='Id';e={""}}, @{n='LevelDisplayName';e={""}}, @{n='Message';e={""}}
    `$nullObj | Export-Csv -Path `$Path -NoTypeInformation -Encoding UTF8
    Write-Host ("Saved (empty): {0}" -f `$Path)
    return
  }
  `$Events |
    Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message |
    Export-Csv -Path `$Path -NoTypeInformation -Encoding UTF8
  Write-Host ("Saved: {0}" -f `$Path)
}

function Get-EventsLocalOrRemote {
  param([string]`$Computer,[string]`$LogName,[int[]]`$Ids,[datetime]`$StartTime,[datetime]`$EndTime,[System.Management.Automation.PSCredential]`$Cred)
  `$filter = @{ LogName = `$LogName; StartTime = `$StartTime; EndTime = `$EndTime }
  if (`$Ids -and `$Ids.Count -gt 0) { `$filter['Id'] = `$Ids }

  try { return Get-WinEvent -FilterHashtable `$filter -ErrorAction Stop }
  catch { Write-Warning ('Get-WinEvent failed for log ''{{0}}'' on {{1}}: {{2}}' -f `$LogName, `$Computer, `$_.Exception.Message); return @() }
}

# --- MAIN ---
`$range = Parse-DateRange -DateString `$Date
`$start = `$range.Start
`$end   = `$range.End

`$csvRoot = 'C:\Temp'
if (-not (Test-Path `$csvRoot)) { New-Item -Path `$csvRoot -ItemType Directory -Force | Out-Null }
`$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
`$rand  = ([guid]::NewGuid().ToString('N')).Substring(0,6)

# Use the passed `$ComputerName` parameter for the base filename
`$base  = ('{0}_{1}_{2}' -f `$ComputerName.ToUpper(), `$stamp, `$rand)

Write-Host ('Collecting events for {0} from {1} to {2} ...' -f `$ComputerName, `$start, `$end)

# What to collect (CRASH/SERVICE/SESSION/REBOOT)
`$queries = @(
  # Application crashes, hangs, .NET runtime errors, and Resource Warnings (333)
  @{ Name='Application_Stability'; Log='Application'; Ids = @(1000,1001,1002,1026,333) }, 
  # Service failures (7000, 7009), Resource Exhaustion (2004), and SYSTEM FAILURE/REBOOT events (6005, 6008, 1074)
  @{ Name='System_Failures_Reboots'; Log='System'; Ids = @(7031,7034,2004,6005,6008,1074,7000,7009) },
  # Session lock/unlock, logon/logoff (Security), and Logon Failures (4625)
  @{ Name='Security_Session'; Log='Security'; Ids = @(4800,4801,4624,4634,4625) }, 
  # WER operational (if exists)
  @{ Name='WER_Operational'; Log='Microsoft-Windows-WER-SystemErrorReporting/Operational'; Ids = @() }
)

foreach (`$q in `$queries) {
  try {
    Write-Host ('Querying {0} (ids: {1}) ...' -f `$q.Log, (`$q.Ids -join ',')) 
    `$events = Get-EventsLocalOrRemote -Computer `$ComputerName -LogName `$q.Log -Ids `$q.Ids -StartTime `$start -EndTime `$end -Cred `$Credential
    `$csvPath = Join-Path `$csvRoot (`$base + '_' + `$q.Name + '.csv')
    Export-EventsCsv -Events `$events -Path `$csvPath
  } catch {
    Write-Warning ('Failed to collect {0}: {1}' -f `$q.Log, `$_.Exception.Message)
  }
}

# --- System status: disk space + pagefile + memory ---
Write-Host ""
Write-Host "=== System Status Snapshot (Disk + Pagefile + Memory) ==="

# ADDED: Memory Snapshot
`$osInfo = Get-CimInstance Win32_OperatingSystem

# Convert Physical Memory (KB to GB)
`$totalRAMGB = [math]::Round((`$osInfo.TotalVisibleMemorySize * 1KB) / 1GB, 2)
`$freeRAMGB  = [math]::Round((`$osInfo.FreePhysicalMemory * 1KB) / 1GB, 2)
`$usedRAMGB  = [math]::Round((`$totalRAMGB - `$freeRAMGB), 2)

# Raw Virtual Memory (MB)
`$totalVirtualMBRaw = `$osInfo.TotalVirtualMemorySize
`$freeVirtualMBRaw  = `$osInfo.FreeVirtualMemory

# FIX: Create memory object with explicitly named properties for clean Format-Table output
`$memoryDisplayObject = [pscustomobject]@{
  TotalRAM = "{0:N2} GB" -f `$totalRAMGB
  FreeRAM  = "{0:N2} GB" -f `$freeRAMGB
  UsedRAM  = "{0:N2} GB" -f `$usedRAMGB
  TotalVirtual = "{0:N0} MB" -f `$totalVirtualMBRaw
  FreeVirtual  = "{0:N0} MB" -f `$freeVirtualMBRaw
}

# Display memory
`$memoryDisplayObject | Format-Table -AutoSize


# All fixed disks - Convert to GB
`$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, VolumeName,
  @{Name='SizeGB';Expression={[math]::Round((`$_.Size / 1GB), 2)}},
  @{Name='FreeGB';Expression={[math]::Round((`$_.FreeSpace / 1GB), 2)}},
  @{Name='UsedGB';Expression={[math]::Round(((`$_.Size - `$_.FreeSpace) / 1GB), 2)}},
  @{Name='FreePct';Expression={[math]::Round( ((`$_.FreeSpace / `$_.Size) * 100), 2) }}
`$disks | Format-Table -AutoSize

# Pagefile settings (configured) and usage (current)
`$pfSetting = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue | Select-Object Name, InitialSize, MaximumSize
`$pfUsage   = Get-CimInstance Win32_PageFileUsage  -ErrorAction SilentlyContinue | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage

# Auto-managed flag + declared paging files (if any)
try {
  `$mmKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
  `$mm = Get-ItemProperty -Path `$mmKey -ErrorAction Stop
  `$autoManaged = `$mm.'AutomaticManagedPagefile'
  `$pagingFiles = `$mm.'PagingFiles'
  `$existingPFs = `$mm.'ExistingPageFiles'
} catch { `$autoManaged = `$null; `$pagingFiles = `$null; `$existingPFs = `$null }

`$pfSummary = [pscustomobject]@{
  Computer    = `$env:COMPUTERNAME
  AutoManaged = `$autoManaged
  PagingFiles = (`$pagingFiles -join ' | ')
  ExistingPFs = (`$existingPFs -join ' | ')
}

# Build rows (null-safe) for CSV

# ADDED: Memory row for CSV (using raw calculated numbers for export)
`$memRow = [pscustomobject]@{
  Section='Memory'; TotalRAMGB=`$totalRAMGB; FreeRAMGB=`$freeRAMGB; UsedRAMGB=`$usedRAMGB;
  TotalVirtualMB=`$totalVirtualMBRaw; FreeVirtualMB=`$freeVirtualMBRaw
}
# END ADDED

# Disk Rows (using raw calculated objects for export)
`$diskRows = @()
if (`$disks) {
  `$disks | ForEach-Object {
    `$diskRows += [pscustomobject]@{
      Section='Disk'; DeviceID=`$_.DeviceID; VolumeName=`$_.VolumeName;
      # NOTE: These are referencing the correctly-calculated properties from the pipeline above
      SizeGB=`$_.SizeGB; FreeGB=`$_.FreeGB; UsedGB=`$_.UsedGB; FreePct=`$_.FreePct
    }
  }
}

`$pfSetRows = @()
if (`$pfSetting) {
  `$pfSetting | ForEach-Object {
    `$pfSetRows += [pscustomobject]@{
      Section='PageFileSetting'; Name=`$_.Name; InitialMB=`$_.InitialSize; MaximumMB=`$_.MaximumSize
    }
  }
}

`$pfUseRows = @()
if (`$pfUsage) {
  `$pfUseRows += [pscustomobject]@{
      Section='PageFileUsage'; Name=`$_.Name; AllocatedMB=`$_.AllocatedBaseSize; CurrentUsageMB=`$_.CurrentUsage; PeakUsageMB=`$_.PeakUsage
    }
  }

`$pfSummaryRow = [pscustomobject]@{
  Section='PageFileSummary'; Computer=`$pfSummary.Computer; AutoManaged=`$pfSummary.AutoManaged;
  PagingFiles=`$pfSummary.PagingFiles; ExistingPFs=`$pfSummary.ExistingPFs
}

# Combine rows safely (null/empty tolerant) and export
`$combined = @()
# Ensure the new memory row is included
foreach (`$set in @(`$memRow, `$diskRows, `$pfSetRows, `$pfUseRows, `$pfSummaryRow)) {
  if (`$set) { `$combined += @(`$set) }
}

`$sysCsv = Join-Path `$csvRoot (`$base + '_SystemStatus.csv')
`$combined | Export-Csv -Path `$sysCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Saved: {0}" -f `$sysCsv)

Write-Host ""
Write-Host "Done. CSV files are in C:\Temp"
"@

# --- END EMBEDDED WORKER SCRIPT CONTENT ---


# Step 1: Remote computer name (MANDATORY PROMPT)
$ComputerName = Read-Host 'ComputerName (e.g., UserPC01 or IP)'
if ([string]::IsNullOrWhiteSpace($ComputerName)) {
  throw 'ComputerName is required.'
}

# ----------------- Streamlined Defaults -----------------

# Define the remote worker file path
$remoteFolder = 'C:\Temp'
$remoteWorkerFileName = 'RemoteEventsWorker.ps1' 
$remotePs1Path = Join-Path $remoteFolder $remoteWorkerFileName
Write-Host "Remote destination folder: C:\Temp"
Write-Host "Remote worker script path: $remotePs1Path"

# Create PSSession
Write-Host ('Creating session to {0} ...' -f $ComputerName) -ForegroundColor Cyan
$sess = New-PSSession -ComputerName $ComputerName

# Ensure remote folder exists
Invoke-Command -Session $sess -ScriptBlock {
  param($p)
  if (-not (Test-Path -LiteralPath $p)) {
    New-Item -ItemType Directory -Path $p -Force | Out-Null
  }
} -ArgumentList $remoteFolder

# Step 4: Create script on remote (REPLACING Copy-Item)
Write-Host ('Creating worker script on {0} ...' -f $remotePs1Path) -ForegroundColor Cyan
Invoke-Command -Session $sess -ScriptBlock {
    param($path, $content)
    $content | Set-Content -Path $path -Encoding UTF8 -Force
} -ArgumentList $remotePs1Path, $RemoteWorkerScriptContent
Write-Host 'Script creation complete.'


# Step 5: Run the created script on the remote 

# ADD DEFAULT DATE LOGIC
$defaultDate = '2025-10-06'
$scriptDate = Read-Host "REQUIRED: Date to search for events [default: $defaultDate]"

if ([string]::IsNullOrWhiteSpace($scriptDate)) { 
    $scriptDate = $defaultDate
    Write-Host "Using default date: $defaultDate" -ForegroundColor Yellow
}
# END ADD DEFAULT DATE LOGIC


# Optional arguments (Default: none)
$optionalArgs = ''

# Construct the FULL argument line (Passing $ComputerName for file naming)
$argsLine = "-ComputerName '$ComputerName' -Date '$scriptDate'"
if (-not [string]::IsNullOrWhiteSpace($optionalArgs)) {
    $argsLine += " $optionalArgs"
}

Write-Host ('Invoking on remote: {0} {1}' -f $remotePs1Path, $argsLine) -ForegroundColor Cyan

Invoke-Command -Session $sess -ScriptBlock {
  param($path, $argsLine)
  
  # Set Execution Policy (required for unsigned worker script)
  Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
  
  $command = "& `"$path`" $argsLine"
  Write-Host "Executing: $command"
  Invoke-Expression -Command $command
  
} -ArgumentList $remotePs1Path, $argsLine

Write-Host 'Remote script finished.'

# Step 6: Copy results back and Cleanup

$remoteHost = Invoke-Command -Session $sess -ScriptBlock { $env:COMPUTERNAME }
$defaultPattern = ('{0}_*.csv' -f $remoteHost)

$pattern = $defaultPattern 
Write-Host ("Remote result file pattern: {0}" -f $defaultPattern)

# Local destination (C:\Temp)
$localDestDefault = 'C:\Temp'
$localDest = $localDestDefault 
Write-Host ("Local destination folder: {0}" -f $localDestDefault)

if (-not (Test-Path -LiteralPath $localDest)) {
  New-Item -ItemType Directory -Path $localDest -Force | Out-Null
}

$remotePathSpec = Join-Path $remoteFolder $pattern
Write-Host ('Copying from remote: {0}' -f $remotePathSpec) -ForegroundColor Cyan

try {
  Copy-Item -FromSession $sess -Path $remotePathSpec -Destination $localDest -Force -ErrorAction Stop
  Write-Host ('Results copied to {0}' -f $localDest) -ForegroundColor Green
  
  # Clean up the worker file on the remote machine
  Invoke-Command -Session $sess -ScriptBlock {
      param($p)
      Remove-Item -Path $p -Force -ErrorAction SilentlyContinue
  } -ArgumentList $remotePs1Path
  Write-Host "Cleaned up worker script on remote machine." -ForegroundColor Yellow
  
  # Open the folder immediately
  Write-Host ('Opening results folder: {0}' -f $localDest) -ForegroundColor Yellow
  Invoke-Item $localDest 
} catch {
  Write-Warning ('No files copied. Check that files matching {0} exist in {1}.' -f $pattern, $remoteFolder)
}

# Cleanup PSSession
if ($sess) { Remove-PSSession -Session $sess }
Write-Host '=== Done ===' -ForegroundColor Cyan
