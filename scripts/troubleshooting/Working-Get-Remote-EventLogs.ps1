#requires -Version 5.1
<#
SYNOPSIS
  Simple Remote / Run / Fetch with date-range prompts (single day, start-end, or last N days),
  Reboot/Shutdown Root-Cause + Windows Update correlation, Uptime per session,
  optional KB filtering, and auto-zip of results.

NOTES
  - ASCII-only to avoid encoding parser issues.
  - Writes a worker script to C:\Temp on the remote, executes it, then copies CSVs and a ZIP back to local C:\Temp.
#>

$ErrorActionPreference = 'Stop'
Write-Host '=== Simple Remote / Run / Fetch (Date-Range + Root-Cause + WU Correlation + KB Filter + Uptime + Auto-Zip) ===' -ForegroundColor Cyan

# --- BEGIN EMBEDDED WORKER SCRIPT (executes locally on the remote computer) ---
# Single-quoted here-string to prevent expansion in the parent script.
$RemoteWorkerScriptContent = @'
#requires -Version 5.1
<#
Get-RemoteEvents-Plus.ps1 (v3.3 - Embedded Worker Script)

Purpose:
 - Collect crash/session events over a specified date range:
     * -Date (single day)
     * -StartDate/-EndDate (inclusive)
     * -LastNDays (rolling window)
 - Emit system status (disk + pagefile).
 - Build Reboot Root-Cause (raw) and Reboot Summary (session correlation).
 - Correlate Windows Update signals (events + registry indicators).
 - Optional KB filtering (e.g., KB5034441,KB5039302).
 - Compute Uptime per session (Boot -> next Shutdown).
 - Auto-zip all CSVs per run.

Runs LOCALLY on the remote.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$false)][string]$ComputerName = 'localhost',
  [Parameter(Mandatory=$false)][string]$Date,
  [Parameter(Mandatory=$false)][string]$StartDate,
  [Parameter(Mandatory=$false)][string]$EndDate,
  [Parameter(Mandatory=$false)][int]$LastNDays,
  [Parameter(Mandatory=$false)][switch]$QuietWarnings,
  [Parameter(Mandatory=$false)][string[]]$KBFilter,
  [System.Management.Automation.PSCredential]$Credential
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-DateRange {
  [CmdletBinding()]
  param(
    [string]$StartDate,
    [string]$EndDate,
    [string]$Date,
    [int]$LastNDays
  )

  $toDate = {
    param($s)
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    try { [datetime]::Parse($s) } catch { throw "Could not parse date string '$s'. Use yyyy-MM-dd or ISO formats." }
  }

  $start = $null
  $endInclusive = $null

  if ($StartDate -or $EndDate) {
    if (-not $StartDate -and $EndDate) { $StartDate = $EndDate }
    if ($StartDate -and -not $EndDate) { $EndDate = $StartDate }
    $start = (& $toDate $StartDate).Date
    $endInclusive = (& $toDate $EndDate).Date
  }
  elseif ($Date) {
    $d = (& $toDate $Date).Date
    $start = $d
    $endInclusive = $d
  }
  elseif ($LastNDays -ge 1) {
    $endInclusive = (Get-Date).Date
    $start = $endInclusive.AddDays(-$LastNDays + 1)
  }
  else {
    throw "No date range provided. Provide -Date, -StartDate/-EndDate, or -LastNDays."
  }

  if ($start -gt $endInclusive) { throw "StartDate ($start) cannot be after EndDate ($endInclusive)." }

  [pscustomobject]@{
    StartInclusive = $start
    EndExclusive   = $endInclusive.AddDays(1)   # exclusive upper bound includes final day fully
    Label          = if ($start.Date -eq $endInclusive.Date) { "{0:d}" -f $start } else { "{0:d} - {1:d}" -f $start, $endInclusive }
  }
}

function Write-Info { param([string]$Message, [switch]$Quiet, [switch]$AsWarning)
  if ($AsWarning) {
    if ($Quiet) { Write-Verbose $Message } else { Write-Warning $Message }
  } else { Write-Host $Message }
}

function Export-EventsCsv {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$false)]$Events,
    [Parameter(Mandatory=$true)][string]$Path
  )
  $arr = @()
  if ($null -ne $Events) { $arr = @($Events) }

  if ($arr.Count -eq 0) {
    "" | Select-Object `
      @{n='TimeCreated';e={""}},
      @{n='ProviderName';e={""}},
      @{n='Id';e={""}},
      @{n='LevelDisplayName';e={""}},
      @{n='Message';e={""}} |
      Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    Write-Host ("Saved (empty): {0}" -f $Path)
    return
  }

  $arr |
    Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message |
    Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
  Write-Host ("Saved: {0}" -f $Path)
}

function Export-FixedCsv {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]$Rows,
    [Parameter(Mandatory=$true)][string[]]$Columns,
    [Parameter(Mandatory=$true)][string]$Path
  )
  $arr = @()
  if ($null -ne $Rows) { $arr = @($Rows) }

  if ($arr.Count -eq 0) {
    "" | Select-Object $Columns | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    Write-Host ("Saved (empty): {0}" -f $Path)
    return
  }

  $arr | Select-Object $Columns | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
  Write-Host ("Saved: {0}" -f $Path)
}

function Get-EventsLocal {
  [CmdletBinding()]
  param(
    [string]$LogName,
    [int[]]$Ids,
    [datetime]$StartTime,
    [datetime]$EndTime,
    [switch]$QuietWarnings
  )
  $filter = @{ LogName = $LogName; StartTime = $StartTime; EndTime = $EndTime }
  if ($Ids -and $Ids.Count -gt 0) { $filter['Id'] = $Ids }
  try {
    @(
      Get-WinEvent -FilterHashtable $filter -ErrorAction Stop
    )
  } catch {
    $msg = ("Get-WinEvent failed for log '{0}' on {1}: {2}" -f $LogName, $env:COMPUTERNAME, $_.Exception.Message)
    if ($QuietWarnings) { Write-Verbose $msg } else { Write-Warning $msg }
    @()
  }
}

# --- Reboot/Shutdown helpers ---

function Parse-User32-1074 {
  param([System.Diagnostics.Eventing.Reader.EventRecord]$Event)
  $msg = $Event.Message
  $proc    = ($msg | Select-String -Pattern 'The process (.+?) has initiated' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -First 1
  $user    = ($msg | Select-String -Pattern 'on behalf of user (.+?) for the following' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -First 1
  $reason  = ($msg | Select-String -Pattern 'Reason:\s*(.+)' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -First 1
  $rcode   = ($msg | Select-String -Pattern 'Reason Code:\s*([^\r\n]+)' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -First 1
  $stype   = ($msg | Select-String -Pattern 'Shutdown Type:\s*([^\r\n]+)' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -First 1
  $comment = ($msg | Select-String -Pattern 'Comment:\s*([^\r\n]*)' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -First 1

  [pscustomobject]@{
    TimeCreated      = $Event.TimeCreated
    Computer         = $env:COMPUTERNAME
    Type             = 'Planned_Shutdown_1074'
    InitiatingUser   = $user
    InitiatingProcess= $proc
    Reason           = $reason
    ReasonCode       = $rcode
    ShutdownType     = $stype
    Comment          = $comment
    EventId          = $Event.Id
    ProviderName     = $Event.ProviderName
    LogName          = 'System'
    MessageShort     = ($msg -replace '\s+', ' ')
  }
}

function Parse-User32-1076 {
  param([System.Diagnostics.Eventing.Reader.EventRecord]$Event)
  $msg = $Event.Message
  $user    = ($msg | Select-String -Pattern 'supplied by user (.+?) for the last unexpected shutdown' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -First 1
  $reason  = ($msg | Select-String -Pattern 'Reason:\s*(.+)' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -First 1
  $rcode   = ($msg | Select-String -Pattern 'Reason Code:\s*([^\r\n]+)' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -First 1
  $comment = ($msg | Select-String -Pattern 'Comment:\s*([^\r\n]*)' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -First 1

  [pscustomobject]@{
    TimeCreated      = $Event.TimeCreated
    Computer         = $env:COMPUTERNAME
    Type             = 'PostUnexpected_ReasonCaptured_1076'
    InitiatingUser   = $user
    InitiatingProcess= $null
    Reason           = $reason
    ReasonCode       = $rcode
    ShutdownType     = $null
    Comment          = $comment
    EventId          = $Event.Id
    ProviderName     = $Event.ProviderName
    LogName          = 'System'
    MessageShort     = ($msg -replace '\s+', ' ')
  }
}

function Parse-KernelPower-41 {
  param([System.Diagnostics.Eventing.Reader.EventRecord]$Event)
  $msg = $Event.Message
  $bugCode = $null
  try {
    if ($Event.Properties -and $Event.Properties.Count -gt 0 -and $Event.Properties[0].Value) {
      $bugCode = [int]$Event.Properties[0].Value
    }
  } catch { }
  $hex = $null
  if ($bugCode -ne $null -and $bugCode -ne 0) { $hex = ('0x{0:X8}' -f $bugCode) }

  [pscustomobject]@{
    TimeCreated      = $Event.TimeCreated
    Computer         = $env:COMPUTERNAME
    Type             = 'Unexpected_Restart_41'
    InitiatingUser   = $null
    InitiatingProcess= $null
    Reason           = if ($hex) { "Kernel-Power 41 (BugCheckCode=$hex)" } else { "Kernel-Power 41 (no bugcheck code)" }
    ReasonCode       = $hex
    ShutdownType     = $null
    Comment          = $null
    EventId          = $Event.Id
    ProviderName     = $Event.ProviderName
    LogName          = 'System'
    MessageShort     = ($msg -replace '\s+', ' ')
  }
}

function Parse-Generic-Event {
  param([System.Diagnostics.Eventing.Reader.EventRecord]$Event, [string]$Type)
  [pscustomobject]@{
    TimeCreated      = $Event.TimeCreated
    Computer         = $env:COMPUTERNAME
    Type             = $Type
    InitiatingUser   = $null
    InitiatingProcess= $null
    Reason           = $null
    ReasonCode       = $null
    ShutdownType     = $null
    Comment          = $null
    EventId          = $Event.Id
    ProviderName     = $Event.ProviderName
    LogName          = 'System'
    MessageShort     = ($Event.Message -replace '\s+', ' ')
  }
}

function Extract-KBsFromMessage {
  param([string]$Message)
  if ([string]::IsNullOrWhiteSpace($Message)) { return @() }
  $matches = [regex]::Matches($Message, 'KB\d{4,7}')
  if ($matches.Count -gt 0) { return ($matches.Value | Sort-Object -Unique) }
  @()
}

function Normalize-KBFilter {
  param([string[]]$KBFilter)
  if (-not $KBFilter -or $KBFilter.Count -eq 0) { return @() }
  $norm = New-Object System.Collections.Generic.HashSet[string]
  foreach ($k in $KBFilter) {
    if ([string]::IsNullOrWhiteSpace($k)) { continue }
    $k2 = $k.Trim().ToUpper()
    if ($k2 -notmatch '^KB\d{4,7}$') {
      # Try to extract a KB token from raw text
      $m = [regex]::Match($k2, 'KB\d{4,7}')
      if ($m.Success) { $k2 = $m.Value } else { continue }
    }
    $null = $norm.Add($k2)
  }
  @($norm)
}

function Any-Intersects {
  param([string[]]$A, [string[]]$B)
  if (-not $A -or -not $B) { return $false }
  $hs = New-Object System.Collections.Generic.HashSet[string] ($A)
  foreach ($x in $B) { if ($hs.Contains($x)) { return $true } }
  $false
}

function Get-WindowsUpdateEvents {
  [CmdletBinding()]
  param(
    [datetime]$StartTime,
    [datetime]$EndTime,
    [string[]]$KBFilter,
    [switch]$QuietWarnings
  )
  # Provider in System: Microsoft-Windows-WindowsUpdateClient
  $events = @()
  try {
    $events = Get-WinEvent -FilterHashtable @{
      LogName='System'; ProviderName='Microsoft-Windows-WindowsUpdateClient'; StartTime=$StartTime; EndTime=$EndTime
    } -ErrorAction Stop
  } catch {
    $msg = ("Windows Update events not available on {0}: {1}" -f $env:COMPUTERNAME, $_.Exception.Message)
    if ($QuietWarnings) { Write-Verbose $msg } else { Write-Warning $msg }
    $events = @()
  }

  $arr = @($events)
  if ($KBFilter -and $KBFilter.Count -gt 0) {
    # keep only events whose message contains at least one KB in filter
    $arr = $arr | Where-Object {
      $m = Extract-KBsFromMessage -Message $_.Message
      Any-Intersects -A $m -B $KBFilter
    }
  }
  @($arr)
}

function Get-RebootEventsRaw {
  [CmdletBinding()]
  param(
    [datetime]$StartTime,
    [datetime]$EndTime,
    [switch]$QuietWarnings
  )
  $ids = @(1074,1076,6005,6006,6008,6009,41,1001)
  $events = @()
  try {
    $events = Get-WinEvent -FilterHashtable @{ LogName='System'; Id=$ids; StartTime=$StartTime; EndTime=$EndTime } -ErrorAction Stop
  } catch {
    $msg = ("Get-WinEvent failed for reboot set on {0}: {1}" -f $env:COMPUTERNAME, $_.Exception.Message)
    if ($QuietWarnings) { Write-Verbose $msg } else { Write-Warning $msg }
    $events = @()
  }

  $rows = New-Object System.Collections.Generic.List[object]
  foreach ($e in $events | Sort-Object TimeCreated) {
    switch ($e.Id) {
      1074 { $rows.Add( (Parse-User32-1074 -Event $e) ); continue }
      1076 { $rows.Add( (Parse-User32-1076 -Event $e) ); continue }
      6008 { $rows.Add( (Parse-Generic-Event -Event $e -Type 'Unexpected_Shutdown_6008') ); continue }
      6005 { $rows.Add( (Parse-Generic-Event -Event $e -Type 'Boot_Start_6005') ); continue }
      6006 { $rows.Add( (Parse-Generic-Event -Event $e -Type 'Shutdown_Clean_6006') ); continue }
      6009 { $rows.Add( (Parse-Generic-Event -Event $e -Type 'Boot_OSVersion_6009') ); continue }
      41   { $rows.Add( (Parse-KernelPower-41 -Event $e) ); continue }
      1001 { $rows.Add( (Parse-Generic-Event -Event $e -Type 'BugCheck_1001') ); continue }
      default { $rows.Add( (Parse-Generic-Event -Event $e -Type 'Other') ); continue }
    }
  }
  $rows
}

function Get-RebootRegistryIndicators {
  [CmdletBinding()]
  param()
  $hklm = 'HKLM:\'
  $wuRebootRequired = 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
  $cbsRebootPending = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'

  $hasWU = $false; $hasCBS = $false
  try { if (Test-Path ($hklm + $wuRebootRequired)) { $hasWU = $true } } catch { }
  try { if (Test-Path ($hklm + $cbsRebootPending)) { $hasCBS = $true } } catch { }

  [pscustomobject]@{
    WU_RebootRequired = $hasWU
    CBS_RebootPending = $hasCBS
  }
}

function Correlate-RebootSessions {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]$RawRows,      # from Get-RebootEventsRaw
    [Parameter(Mandatory=$true)]$WUEvents,     # from Get-WindowsUpdateEvents
    [string[]]$KBFilter,
    [datetime]$StartTime,
    [datetime]$EndTime
  )

  $shutdownTypes = @('Planned_Shutdown_1074','Shutdown_Clean_6006','Unexpected_Shutdown_6008')
  $bootTypes     = @('Boot_Start_6005','Boot_OSVersion_6009','Unexpected_Restart_41') # treat 41 as boot marker
  $rows = @($RawRows | Sort-Object TimeCreated)
  $boots = @($rows | Where-Object { $_.Type -in $bootTypes })
  $shutdowns = @($rows | Where-Object { $_.Type -in $shutdownTypes })

  # Pre-extract KBs from WU events for fast lookups
  $wuKBMap = @()
  foreach ($w in $WUEvents) {
    $wuKBMap += [pscustomobject]@{
      TimeCreated = $w.TimeCreated
      KBs = Extract-KBsFromMessage -Message $w.Message
    }
  }

  $KBFilter = Normalize-KBFilter -KBFilter $KBFilter

  $sessions = New-Object System.Collections.Generic.List[object]
  $usedShutdown = New-Object 'System.Collections.Generic.HashSet[string]'

  foreach ($b in $boots) {
    # Find closest preceding shutdown not yet used
    $candidate = $shutdowns | Where-Object { $_.TimeCreated -lt $b.TimeCreated } | Sort-Object TimeCreated -Descending | Select-Object -First 1
    if ($candidate) {
      $sid = ("{0:o}|{1}|{2}" -f $candidate.TimeCreated, $candidate.EventId, $candidate.Type)
      if (-not $usedShutdown.Contains($sid)) {
        $null = $usedShutdown.Add($sid)
        $shutdownTime = $candidate.TimeCreated
        $bootTime = $b.TimeCreated
        $offline = $null; try { $offline = [math]::Round( ($bootTime - $shutdownTime).TotalMinutes, 1) } catch { }

        # Find next shutdown after this boot to compute uptime
        $nextShutdown = $shutdowns | Where-Object { $_.TimeCreated -gt $bootTime } | Sort-Object TimeCreated | Select-Object -First 1
        $uptime = $null
        if ($nextShutdown) {
          try { $uptime = [math]::Round( ($nextShutdown.TimeCreated - $bootTime).TotalMinutes, 1) } catch { }
        }
        $uptimeToRangeEnd = $null
        try { $uptimeToRangeEnd = [math]::Round( ([datetime]::Min([datetime]::Now, $EndTime) - $bootTime).TotalMinutes, 1) } catch { }

        # Correlate WU events in a sliding window near shutdown -> boot
        $kbList = @()
        $wuWindowStart = $shutdownTime.AddHours(-4)
        $wuHits = @($wuKBMap | Where-Object { $_.TimeCreated -ge $wuWindowStart -and $_.TimeCreated -le $bootTime.AddMinutes(5) })
        if ($wuHits.Count -gt 0) {
          foreach ($hit in $wuHits) { $kbList += $hit.KBs }
          $kbList = $kbList | Where-Object { $_ } | Sort-Object -Unique
        }

        # Root cause inference (same as before, refined for KBs)
        $root = 'Unknown'
        if ($candidate.Type -eq 'Planned_Shutdown_1074') {
          $proc = $candidate.InitiatingProcess
          $reason = $candidate.Reason
          if ($kbList.Count -gt 0 -or ($reason -match 'Operating System' -or $reason -match 'Windows Update' -or $proc -match '(wuauclt|usoclient|tiworker|svchost)')) {
            $root = if ($kbList.Count -gt 0) { "Planned: Windows Update (" + ($kbList -join ',') + ")" } else { "Planned: Windows Update" }
          } elseif ($candidate.InitiatingUser -and $candidate.InitiatingUser -notmatch 'NT AUTHORITY\\SYSTEM') {
            $root = "Planned: User initiated (" + $candidate.InitiatingUser + ")"
          } else {
            $root = "Planned: Service initiated"
          }
        }
        elseif ($candidate.Type -eq 'Shutdown_Clean_6006') {
          if ($kbList.Count -gt 0) {
            $root = "Planned: Windows Update (" + ($kbList -join ',') + ")"
          } else {
            $near1074 = $rows | Where-Object { $_.Type -eq 'Planned_Shutdown_1074' -and $_.TimeCreated -le $candidate.TimeCreated -and $_.TimeCreated -ge $candidate.TimeCreated.AddMinutes(-5) } | Select-Object -First 1
            if ($near1074) {
              if ($near1074.InitiatingUser -and $near1074.InitiatingUser -notmatch 'NT AUTHORITY\\SYSTEM') {
                $root = "Planned: User initiated (" + $near1074.InitiatingUser + ")"
              } else {
                $root = "Planned: Service initiated"
              }
            } else {
              $root = "Planned: Clean shutdown"
            }
          }
        }
        elseif ($candidate.Type -eq 'Unexpected_Shutdown_6008') {
          $near41 = $rows | Where-Object { $_.Type -eq 'Unexpected_Restart_41' -and $_.TimeCreated -ge $bootTime.AddMinutes(-5) -and $_.TimeCreated -le $bootTime.AddMinutes(5) } | Select-Object -First 1
          if ($near41) {
            $root = if ($near41.ReasonCode) { "Unexpected: Crash (BugCheck " + $near41.ReasonCode + ")" } else { "Unexpected: Power loss or abrupt reset" }
          } else {
            $root = "Unexpected: Power loss or abrupt reset"
          }
        }

        # KB filter matching
        $kbJoined = if ($kbList.Count -gt 0) { $kbList -join ',' } else { $null }
        $kbFilterNorm = $KBFilter
        $matchesKB = $false
        if ($kbFilterNorm -and $kbFilterNorm.Count -gt 0) {
          $candidateKBs = @()
          if ($candidate.MessageShort) { $candidateKBs += (Extract-KBsFromMessage -Message $candidate.MessageShort) }
          if ($kbList) { $candidateKBs += $kbList }
          $candidateKBs = $candidateKBs | Sort-Object -Unique
          $matchesKB = Any-Intersects -A $candidateKBs -B $kbFilterNorm
        }

        $sessions.Add([pscustomobject]@{
          Computer              = $env:COMPUTERNAME
          ShutdownTime          = $shutdownTime
          BootTime              = $bootTime
          OfflineMinutes        = $offline
          UptimeMinutes         = $uptime
          UptimeMinutesToRangeEnd = $uptimeToRangeEnd
          RootCause             = $root
          ShutdownType          = $candidate.Type
          ShutdownEventId       = $candidate.EventId
          ShutdownProvider      = $candidate.ProviderName
          ShutdownUser          = $candidate.InitiatingUser
          ShutdownProcess       = $candidate.InitiatingProcess
          BootMarkerType        = $b.Type
          BootEventId           = $b.EventId
          BootProvider          = $b.ProviderName
          WU_KBs                = $kbJoined
          MatchesKBFilter       = $matchesKB
          KBFilter              = if ($kbFilterNorm) { ($kbFilterNorm -join ',') } else { $null }
        })
      }
    }
  }
  $sessions
}

function Get-RebootEventsReport { # raw rows for CSV
  [CmdletBinding()]
  param([datetime]$StartTime, [datetime]$EndTime, [switch]$QuietWarnings)
  Get-RebootEventsRaw -StartTime $StartTime -EndTime $EndTime -QuietWarnings:$QuietWarnings
}

function Export-RebootReportCsv {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$false)]$Rows,
    [Parameter(Mandatory=$true)][string]$Path
  )
  $cols = @('TimeCreated','Computer','Type','InitiatingUser','InitiatingProcess',
            'Reason','ReasonCode','ShutdownType','Comment','EventId','ProviderName','LogName','MessageShort')
  Export-FixedCsv -Rows $Rows -Columns $cols -Path $Path
}

function Export-RebootSummaryCsv {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$false)]$Sessions,
    [Parameter(Mandatory=$true)][string]$Path
  )
  $cols = @('Computer','ShutdownTime','BootTime','OfflineMinutes','UptimeMinutes','UptimeMinutesToRangeEnd','RootCause',
            'ShutdownType','ShutdownEventId','ShutdownProvider','ShutdownUser','ShutdownProcess',
            'BootMarkerType','BootEventId','BootProvider','WU_KBs','MatchesKBFilter','KBFilter')
  Export-FixedCsv -Rows $Sessions -Columns $cols -Path $Path
}

# --- MAIN WORKER FLOW ---
$range = Resolve-DateRange -StartDate $StartDate -EndDate $EndDate -Date $Date -LastNDays $LastNDays
$start = $range.StartInclusive
$end   = $range.EndExclusive

$csvRoot = 'C:\Temp'
if (-not (Test-Path $csvRoot)) { New-Item -Path $csvRoot -ItemType Directory -Force | Out-Null }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$rand  = ([guid]::NewGuid().ToString('N')).Substring(0,6)

# Actual remote name for pattern match
$baseComputer = $env:COMPUTERNAME.ToUpper()
$basePrefix   = ('{0}_{1}_{2}' -f $baseComputer, $stamp, $rand)

Write-Host ('Collecting events for {0} from {1} to {2} (label: {3}) ...' -f $baseComputer, $start, $end, $range.Label)

# Targeted event queries (unchanged)
$queries = @(
  @{ Name='Application_1000_1001_1002_1026'; Log='Application'; Ids = @(1000,1001,1002,1026) },
  @{ Name='System_SCM_2004'; Log='System'; Ids = @(7031,7034,2004) },
  @{ Name='Security_Session'; Log='Security'; Ids = @(4800,4801,4624,4634) },
  @{ Name='WER_Operational'; Log='Microsoft-Windows-WER-SystemErrorReporting/Operational'; Ids = @() }
)
foreach ($q in $queries) {
  Write-Host ('Querying {0} (ids: {1}) ...' -f $q.Log, ($q.Ids -join ','))
  $events = Get-EventsLocal -LogName $q.Log -Ids $q.Ids -StartTime $start -EndTime $end -QuietWarnings:$QuietWarnings
  $csvPath = Join-Path $csvRoot ($basePrefix + '_' + $q.Name + '.csv')
  Export-EventsCsv -Events $events -Path $csvPath
}

# Reboot raw + summary + WU correlation + KB filtering
Write-Host ""
Write-Host "=== Reboot/Shutdown Root-Cause (Raw + Summary + KB Filter) ==="

$kbFilterNorm = Normalize-KBFilter -KBFilter $KBFilter
$rawRows   = Get-RebootEventsReport -StartTime $start -EndTime $end -QuietWarnings:$QuietWarnings
$wuEvents  = Get-WindowsUpdateEvents -StartTime $start -EndTime $end -KBFilter $kbFilterNorm -QuietWarnings:$QuietWarnings
$sessions  = Correlate-RebootSessions -RawRows $rawRows -WUEvents $wuEvents -KBFilter $kbFilterNorm -StartTime $start -EndTime $end

$rebootCsv   = Join-Path $csvRoot ($basePrefix + '_Reboot_Report.csv')
$summaryCsv  = Join-Path $csvRoot ($basePrefix + '_Reboot_Summary.csv')
Export-RebootReportCsv  -Rows $rawRows  -Path $rebootCsv
Export-RebootSummaryCsv -Sessions $sessions -Path $summaryCsv

# If KB filter was provided, also emit a filtered summary
if ($kbFilterNorm -and $kbFilterNorm.Count -gt 0) {
  $sessionsKB = $sessions | Where-Object { $_.MatchesKBFilter -eq $true }
  $summaryKBCsv = Join-Path $csvRoot ($basePrefix + '_Reboot_Summary_KBFiltered.csv')
  Export-RebootSummaryCsv -Sessions $sessionsKB -Path $summaryKBCsv
}

# Registry indicators (current state)
$regInd = Get-RebootRegistryIndicators
$regCsv = Join-Path $csvRoot ($basePrefix + '_Reboot_Indicators.csv')
$regInd | Select-Object WU_RebootRequired, CBS_RebootPending |
  Export-Csv -Path $regCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Saved: {0}" -f $regCsv)

# System status: disk + pagefile
Write-Host ""
Write-Host "=== System Status Snapshot (Disk + Pagefile) ==="

$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
  Select-Object DeviceID, VolumeName,
    @{n='SizeGB';e={[math]::Round(($_.Size / 1GB), 2)}},
    @{n='FreeGB';e={[math]::Round(($_.FreeSpace / 1GB), 2)}},
    @{n='UsedGB';e={[math]::Round((($_.Size - $_.FreeSpace) / 1GB), 2)}},
    @{n='FreePct';e={[math]::Round((($_.FreeSpace / $_.Size) * 100), 2)}}

$disks | Format-Table -AutoSize

$pfSetting = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue |
  Select-Object Name, InitialSize, MaximumSize

$pfUsage = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue |
  Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage

$autoManaged = $null; $pagingFiles = $null; $existingPFs = $null
try {
  $mmKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
  $mm = Get-ItemProperty -Path $mmKey -ErrorAction Stop
  $autoManaged = $mm.'AutomaticManagedPagefile'
  $pagingFiles = $mm.'PagingFiles'
  $existingPFs = $mm.'ExistingPageFiles'
} catch { }

$diskRows = @()
if ($disks) {
  $disks | ForEach-Object {
    $diskRows += [pscustomobject]@{
      Section='Disk'; DeviceID=$_.DeviceID; VolumeName=$_.VolumeName;
      SizeGB=$_.SizeGB; FreeGB=$_.FreeGB; UsedGB=$_.UsedGB; FreePct=$_.FreePct
    }
  }
}

$pfSetRows = @()
if ($pfSetting) {
  $pfSetting | ForEach-Object {
    $pfSetRows += [pscustomobject]@{
      Section='PageFileSetting'; Name=$_.Name; InitialMB=$_.InitialSize; MaximumMB=$_.MaximumSize
    }
  }
}

$pfUseRows = @()
if ($pfUsage) {
  $pfUseRows | Out-Null
  $pfUsage | ForEach-Object {
    $pfUseRows += [pscustomobject]@{
      Section='PageFileUsage'; Name=$_.Name; AllocatedMB=$_.AllocatedBaseSize; CurrentUsageMB=$_.CurrentUsage; PeakUsageMB=$_.PeakUsage
    }
  }
}

$pfSummaryRow = [pscustomobject]@{
  Section='PageFileSummary'; Computer=$env:COMPUTERNAME; AutoManaged=$autoManaged;
  PagingFiles=($pagingFiles -join "`n"); ExistingPFs=($existingPFs -join "`n")
}

$combined = @()
foreach ($set in @($diskRows, $pfSetRows, $pfUseRows, $pfSummaryRow)) {
  if ($set) { $combined += @($set) }
}

$sysCsv = Join-Path 'C:\Temp' ($basePrefix + '_SystemStatus.csv')
$combined | Export-Csv -Path $sysCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Saved: {0}" -f $sysCsv)

# Auto-zip all CSVs for this run
$zipPath = Join-Path $csvRoot ($basePrefix + '.zip')
try {
  $pattern = Join-Path $csvRoot ($basePrefix + '_*.csv')
  Compress-Archive -Path $pattern -DestinationPath $zipPath -Force
  Write-Host ("Zipped all CSVs into: {0}" -f $zipPath)
} catch {
  $msg = ("Failed to create ZIP on {0}: {1}" -f $env:COMPUTERNAME, $_.Exception.Message)
  if ($QuietWarnings) { Write-Verbose $msg } else { Write-Warning $msg }
}

Write-Host ""
Write-Host "Done. CSV files and ZIP are in C:\Temp"
'@
# --- END EMBEDDED WORKER SCRIPT ---

# Step 1: Remote computer name
$ComputerName = Read-Host 'ComputerName (e.g., UserPC01 or IP)'
if ([string]::IsNullOrWhiteSpace($ComputerName)) {
  throw 'ComputerName is required.'
}

# ----------------- Streamlined, Smart Date Input -----------------
Write-Host ""
Write-Host "Provide ONE of the following:"
Write-Host " - Single date (YYYY-MM-DD) OR"
Write-Host " - A number N to mean last N days (e.g., 7) OR"
Write-Host " - Leave blank to enter Start/End dates (YYYY-MM-DD each) or Last N days"
Write-Host ""

$singleDateOrN = Read-Host 'Single date or Last N days (e.g., 2026-03-10 OR 7). Leave blank to enter Start/End'

$startDate  = $null
$endDate    = $null
$lastNDays  = $null
$singleDate = $null

# Numeric input => LastNDays
if (-not [string]::IsNullOrWhiteSpace($singleDateOrN)) {
  if ($singleDateOrN -match '^\d+$') {
    $lastNDays = [int]$singleDateOrN
  } else {
    $singleDate = $singleDateOrN
  }
} else {
  $startDate = Read-Host 'Start Date (YYYY-MM-DD, optional)'
  $endDate   = Read-Host 'End Date   (YYYY-MM-DD, optional)'
  $tmpN      = Read-Host 'Last N days (integer, optional)'
  if (-not [string]::IsNullOrWhiteSpace($tmpN)) {
    if ($tmpN -match '^\d+$') { $lastNDays = [int]$tmpN } else { throw "Last N days must be an integer (e.g., 7)." }
  }
}

# Choose whether to suppress warning noise (non-fatal)
$quietInput = Read-Host 'Suppress warnings about empty/missing logs? (Y/N, default: N)'
$QuietWarnings = ($quietInput -match '^(y|yes)$')

# Optional KB filter prompt
$kbInput = Read-Host 'Filter by KB numbers (comma-separated, optional, e.g., KB5034441,KB5039302)'
# Build KB filter array (sanitized later in the worker)
[string[]]$KBFilter = @()
if (-not [string]::IsNullOrWhiteSpace($kbInput)) {
  $KBFilter = ($kbInput -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

# Validate at least one method was provided
if ([string]::IsNullOrWhiteSpace($singleDate) -and
    [string]::IsNullOrWhiteSpace($startDate) -and
    [string]::IsNullOrWhiteSpace($endDate) -and
    -not $lastNDays) {
  throw 'A date, a start/end range, or last N days is required.'
}

# Step 2: Create PSSession
Write-Host ('Creating session to {0} ...' -f $ComputerName) -ForegroundColor Cyan
$sess = New-PSSession -ComputerName $ComputerName

# Ensure remote folder exists
$remoteFolder = 'C:\Temp'
$remoteWorkerFileName = 'RemoteEventsWorker.ps1'
$remotePs1Path = Join-Path $remoteFolder $remoteWorkerFileName

Write-Host "Remote destination folder: $remoteFolder"
Write-Host "Remote worker script path: $remotePs1Path"

Invoke-Command -Session $sess -ScriptBlock {
  param($p)
  if (-not (Test-Path -LiteralPath $p)) {
    New-Item -ItemType Directory -Path $p -Force | Out-Null
  }
} -ArgumentList $remoteFolder

# Step 3: Create worker script on remote
Write-Host ('Creating worker script on {0} ...' -f $remotePs1Path) -ForegroundColor Cyan
Invoke-Command -Session $sess -ScriptBlock {
  param($path, $content)
  $content | Set-Content -Path $path -Encoding UTF8 -Force
} -ArgumentList $remotePs1Path, $RemoteWorkerScriptContent
Write-Host 'Script creation complete.'

# Step 4: Build arguments and run the worker
$argsLine = "-ComputerName '$ComputerName'"
if ($QuietWarnings) { $argsLine += " -QuietWarnings" }

if ($KBFilter -and $KBFilter.Count -gt 0) {
  # Pass as separate -KBFilter 'KB1','KB2',... so worker receives an array
  $kbArgs = ($KBFilter | ForEach-Object { "'$_'" }) -join ' '
  $argsLine += " -KBFilter $kbArgs"
}

if ($lastNDays) {
  if ($lastNDays -lt 1) { throw "Last N days must be >= 1." }
  $argsLine += " -LastNDays $lastNDays"
} elseif (-not [string]::IsNullOrWhiteSpace($singleDate)) {
  $argsLine += " -Date '$singleDate'"
} else {
  if (-not [string]::IsNullOrWhiteSpace($startDate)) { $argsLine += " -StartDate '$startDate'" }
  if (-not [string]::IsNullOrWhiteSpace($endDate))   { $argsLine += " -EndDate '$endDate'" }
}

Write-Host ('Invoking on remote: {0} {1}' -f $remotePs1Path, $argsLine) -ForegroundColor Cyan
Invoke-Command -Session $sess -ScriptBlock {
  param($path, $argsLine)
  Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
  $command = "& `"$path`" $argsLine"
  Write-Host "Executing: $command"
  Invoke-Expression -Command $command
} -ArgumentList $remotePs1Path, $argsLine
Write-Host 'Remote script finished.'

# Step 5: Copy results back and cleanup
$remoteHost = Invoke-Command -Session $sess -ScriptBlock { $env:COMPUTERNAME }
$csvPattern = ('{0}_*.csv' -f $remoteHost)
$zipPattern = ('{0}_*.zip' -f $remoteHost)
Write-Host ("Remote result file patterns: {0} and {1}" -f $csvPattern, $zipPattern)

$localDest = 'C:\Temp'
Write-Host ("Local destination folder: {0}" -f $localDest)
if (-not (Test-Path -LiteralPath $localDest)) {
  New-Item -ItemType Directory -Path $localDest -Force | Out-Null
}

$remoteCsvSpec = Join-Path $remoteFolder $csvPattern
$remoteZipSpec = Join-Path $remoteFolder $zipPattern

Write-Host ('Copying CSVs from remote: {0}' -f $remoteCsvSpec) -ForegroundColor Cyan
try {
  Copy-Item -FromSession $sess -Path $remoteCsvSpec -Destination $localDest -Force -ErrorAction Stop
  Write-Host ('CSV results copied to {0}' -f $localDest) -ForegroundColor Green
} catch {
  Write-Warning ('No CSV files copied. Check that files matching {0} exist in {1}.' -f $csvPattern, $remoteFolder)
}

Write-Host ('Copying ZIP from remote: {0}' -f $remoteZipSpec) -ForegroundColor Cyan
try {
  Copy-Item -FromSession $sess -Path $remoteZipSpec -Destination $localDest -Force -ErrorAction Stop
  Write-Host ('ZIP copied to {0}' -f $localDest) -ForegroundColor Green
} catch {
  Write-Warning ('No ZIP file copied. Check that files matching {0} exist in {1}.' -f $zipPattern, $remoteFolder)
}

# Clean up the worker file on the remote machine
Invoke-Command -Session $sess -ScriptBlock {
  param($p)
  Remove-Item -Path $p -Force -ErrorAction SilentlyContinue
} -ArgumentList $remotePs1Path
Write-Host "Cleaned up worker script on remote machine." -ForegroundColor Yellow

Write-Host ('Opening results folder: {0}' -f $localDest) -ForegroundColor Yellow
try { Invoke-Item $localDest } catch { }

if ($sess) { Remove-PSSession -Session $sess }
Write-Host '=== Done ===' -ForegroundColor Cyan
