<#
.SYNOPSIS
  The IT Admin Toolkit: A single script offering local disk space cleanup and remote system diagnostics.

.DESCRIPTION
  This script provides two primary modes of operation:
  1. REMOTE DIAGNOSTICS: Connects to a remote host, executes an embedded worker script for events/disk analysis, and retrieves results.
  2. LOCAL CLEANUP: Analyzes C:\Windows\Temp and a selected user's AppData to identify and delete large temporary/cache files.

.NOTES
  - Runs in Admin mode when performing Local Cleanup.
  - Requires user input for mode selection and specific parameters (ComputerName/Date/Profile).
#>

$ErrorActionPreference = 'Stop'

Write-Host '=== IT Admin Toolkit: Mode Selection ===' -ForegroundColor Cyan

# --- EMBEDDED WORKER SCRIPT CONTENT (FOR REMOTE DIAGNOSTICS ONLY) ---

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

# --- MAIN (Remote Worker Script) ---
`$range = Parse-DateRange -DateString `$Date
`$start = `$range.Start
`$end   = `$range.End

`$csvRoot = 'C:\Temp'
if (-not (Test-Path `$csvRoot)) { New-Item -Path `$csvRoot -ItemType Directory -Force | Out-Null }
`$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
`$rand  = ([guid]::NewGuid().ToString('N')).Substring(0,6)
`$base  = ('{0}_{1}_{2}' -f `$ComputerName.ToUpper(), `$stamp, `$rand)

Write-Host ('Collecting events for {0} from {1} to {2} ...' -f `$ComputerName, `$start, `$end)

`$queries = @(
  @{ Name='Application_Stability'; Log='Application'; Ids = @(1000,1001,1002,1026,333) }, 
  @{ Name='System_Failures_Reboots'; Log='System'; Ids = @(7031,7034,2004,6005,6008,1074,7000,7009) },
  @{ Name='Security_Session'; Log='Security'; Ids = @(4800,4801,4624,4634,4625) }, 
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

`$osInfo = Get-CimInstance Win32_OperatingSystem
`$totalRAMGB = [math]::Round((`$osInfo.TotalVisibleMemorySize * 1KB) / 1GB, 2)
`$freeRAMGB  = [math]::Round((`$osInfo.FreePhysicalMemory * 1KB) / 1GB, 2)
`$usedRAMGB  = [math]::Round((`$totalRAMGB - `$freeRAMGB), 2)
`$totalVirtualMBRaw = `$osInfo.TotalVirtualMemorySize
`$freeVirtualMBRaw  = `$osInfo.FreeVirtualMemory

`$memoryDisplayObject = [pscustomobject]@{
  TotalRAM = "{0:N2} GB" -f `$totalRAMGB
  FreeRAM  = "{0:N2} GB" -f `$freeRAMGB
  UsedRAM  = "{0:N2} GB" -f `$usedRAMGB
  TotalVirtual = "{0:N0} MB" -f `$totalVirtualMBRaw
  FreeVirtual  = "{0:N0} MB" -f `$freeVirtualMBRaw
}
`$memoryDisplayObject | Format-Table -AutoSize

`$disksForCsv = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, VolumeName,
  @{Name='SizeGB';Expression={[math]::Round((`$_.Size / 1GB), 2)}},
  @{Name='FreeGB';Expression={[math]::Round((`$_.FreeSpace / 1GB), 2)}},
  @{Name='UsedGB';Expression={[math]::Round(((`$_.Size - `$_.FreeSpace) / 1GB), 2)}},
  @{Name='FreePct';Expression={[math]::Round( ((`$_.FreeSpace / `$_.Size) * 100), 2) }}
`$disksForCsv | Format-Table -AutoSize

`$pfSetting = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue | Select-Object Name, InitialSize, MaximumSize
`$pfUsage   = Get-CimInstance Win32_PageFileUsage  -ErrorAction SilentlyContinue | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage

`$pfSummary = [pscustomobject]@{
  Computer    = `$env:COMPUTERNAME
  AutoManaged = `$autoManaged
  PagingFiles = (`$pagingFiles -join ' | ')
  ExistingPFs = (`$existingPFs -join ' | ')
}

# CSV Data Consolidation
`$memRow = [pscustomobject]@{
  Section='Memory'; TotalRAMGB=`$totalRAMGB; FreeRAMGB=`$freeRAMGB; UsedRAMGB=`$usedRAMGB;
  TotalVirtualMB=`$totalVirtualMBRaw; FreeVirtualMB=`$freeVirtualMBRaw
}

`$diskRows = @()
if (`$disksForCsv) {
  `$disksForCsv | ForEach-Object {
    `$diskRows += [pscustomobject]@{
      Section='Disk'; DeviceID=`$_.DeviceID; VolumeName=`$_.VolumeName;
      SizeGB=`$_.SizeGB; FreeGB=`$_.FreeGB; UsedGB=`$_.UsedGB; FreePct=`$_.FreePct
    }
  }
}

`$combined = @()
foreach (`$set in @(`$memRow, `$diskRows, `$pfSetRows, `$pfUseRows, `$pfSummaryRow)) {
  if (`$set) { `$combined += @(`$set) }
}

`$sysCsv = Join-Path `$csvRoot (`$base + '_SystemStatus.csv')
`$combined | Export-Csv -Path `$sysCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Saved: {0}" -f `$sysCsv)
Write-Host ""
Write-Host "Done. CSV files are in C:\Temp"
"@


# --- 3. FUNCTION FOR REMOTE DATA COLLECTION ---

function Invoke-RemoteDataCollection {
    param($RemoteWorkerScriptContent)

    $ErrorActionPreference = 'Stop'

    Write-Host '=== Starting Remote Data Collection ===' -ForegroundColor Cyan

    # Step 1: Remote computer name (MANDATORY PROMPT)
    $ComputerName = Read-Host 'ComputerName (e.g., UserPC01 or IP)'
    if ([string]::IsNullOrWhiteSpace($ComputerName)) {
      throw 'ComputerName is required.'
    }

    # Define paths
    $remoteFolder = 'C:\Temp'
    $remoteWorkerFileName = 'RemoteEventsWorker.ps1' 
    $remotePs1Path = Join-Path $remoteFolder $remoteWorkerFileName
    Write-Host "Remote destination folder: C:\Temp"
    Write-Host "Remote worker script path: $remotePs1Path"

    # Create PSSession
    Write-Host ('Creating session to {0} ...' -f $ComputerName) -ForegroundColor Cyan
    $sess = New-PSSession -ComputerName $ComputerName

    try {
        # Ensure remote folder exists
        Invoke-Command -Session $sess -ScriptBlock {
          param($p)
          if (-not (Test-Path -LiteralPath $p)) {
            New-Item -ItemType Directory -Path $p -Force | Out-Null
          }
        } -ArgumentList $remoteFolder

        # Step 4: Create script on remote (Embed content)
        Write-Host ('Creating worker script on {0} ...' -f $remotePs1Path) -ForegroundColor Cyan
        Invoke-Command -Session $sess -ScriptBlock {
            param($path, $content)
            $content | Set-Content -Path $path -Encoding UTF8 -Force
        } -ArgumentList $remotePs1Path, $RemoteWorkerScriptContent
        Write-Host 'Script creation complete.'

        # Step 5: Run the created script on the remote 
        $defaultDate = '2025-10-06'
        $scriptDate = Read-Host "REQUIRED: Date for events [default: $defaultDate]"

        if ([string]::IsNullOrWhiteSpace($scriptDate)) { 
            $scriptDate = $defaultDate
            Write-Host "Using default date: $defaultDate" -ForegroundColor Yellow
        }

        $argsLine = "-ComputerName '$ComputerName' -Date '$scriptDate'"
        Write-Host ('Invoking on remote: {0} {1}' -f $remotePs1Path, $argsLine) -ForegroundColor Cyan

        Invoke-Command -Session $sess -ScriptBlock {
          param($path, $argsLine)
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
        $localDest = 'C:\Temp' 
        
        Write-Host ("Remote result file pattern: {0}" -f $defaultPattern)
        Write-Host ("Local destination folder: {0}" -f $localDest)

        if (-not (Test-Path -LiteralPath $localDest)) {
          New-Item -ItemType Directory -Path $localDest -Force | Out-Null
        }

        $remotePathSpec = Join-Path $remoteFolder $pattern
        Write-Host ('Copying from remote: {0}' -f $remotePathSpec) -ForegroundColor Cyan

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
        Write-Warning ("Operation failed: $($_.Exception.Message)")
    } finally {
        if ($sess) { Remove-PSSession -Session $sess }
        Write-Host '=== Remote Collection Done ===' -ForegroundColor Cyan
    }
}


# --- 4. FUNCTION FOR LOCAL CLEANUP (Analyze-TempDiskUsage.ps1 Logic) ---

function Start-LocalTempCleanup {
    # Self-elevation check is done within this function's scope
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Restarting script for Local Cleanup with Administrator privileges..." -ForegroundColor Red
        $ScriptPath = $MyInvocation.MyCommand.Definition
        $Arguments = @("& `"$ScriptPath`" -Mode Cleanup") + $args
        Start-Process powershell.exe -Verb RunAs -ArgumentList $Arguments
        exit
    }
    
    # --- Local Cleanup Functions (Defined Here for Scope) ---
    function Get-TotalDirSize {
        param([string]$Dir)
        try {
            $Size = (Get-ChildItem -Path $Dir -File -Recurse -Force -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum
            return $Size
        }
        catch { return -1 }
    }

    function Get-LargestTempItems {
      param([Parameter(Mandatory=$true)][string]$Path, [int]$TopN = 10)
      # (This function contains the core logic for calculating disk usage and listing top N items)
      
      Write-Host "--- Analyzing [$Path] ---" -ForegroundColor Cyan
      $TotalBytes = 0; $Results = @();
      $TopLevelItems = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue | Where-Object {$_.Name -ne "." -and $_.Name -ne ".."}
      if (-not $TopLevelItems) { Write-Host "Directory is empty or inaccessible." -ForegroundColor DarkYellow; return $null }

      foreach ($Item in $TopLevelItems) {
        $ItemBytes = 0; $ItemType = "File"; $AccessDenied = $false
        if (-not $Item.PSIsContainer) { $ItemBytes = $Item.Length; $TotalBytes += $ItemBytes }
        else {
          $ItemType = "Folder"
          $ItemBytes = Get-TotalDirSize -Dir $Item.FullName
          if ($ItemBytes -eq -1) { $ItemType = "Folder (Access Denied)"; $AccessDenied = $true }
          else { $TotalBytes += $ItemBytes }
        }
        if ($ItemBytes -ne 0 -and -not $AccessDenied) {
            $Results += [PSCustomObject]@{ Name = $Item.Name; Type = $ItemType; SizeGB = [math]::Round($ItemBytes / 1GB, 2); Path = $Item.FullName }
        }
      }
      
      $TotalSizeGB = [math]::Round($TotalBytes / 1GB, 2)
      Write-Host ("Total Size Calculated: {0:N2} GB" -f $TotalSizeGB) -ForegroundColor Yellow
      
      $TopResults = $Results | Sort-Object SizeGB -Descending | Select-Object -First $TopN Name, Type, @{Name='Size'; Expression={ if ($_.SizeGB -eq -1) {"Access Denied"} elseif ($_.SizeGB -ge 0) {"{0:N2} GB" -f $_.SizeGB} else {"{0}" -f $_.SizeGB} }}, Path
      
      if ($TopResults) {
        Write-Host "`nTop $TopN Largest Items Found:`n" -ForegroundColor DarkYellow
        $TopResults | Format-Table -AutoSize
        return $Results
      }
      else {
        Write-Host "No large items found (or all inaccessible)." -ForegroundColor DarkYellow
        return $null
      }
    }

    function Prompt-And-Delete {
        param([PSCustomObject[]]$ItemsToDelete)
        # (This function contains the core deletion logic, including the final confirmation prompt and display)
        
        if (-not $ItemsToDelete) { return }
        Write-Host "`n========================================`n" -ForegroundColor Red
        Write-Host "CONFIRMATION REQUIRED: The following items will be PERMANENTLY deleted." -ForegroundColor Red
        
        $ItemsToDelete | Select-Object Name, Type, @{Name='Size'; Expression={ "{0:N2} GB" -f $_.SizeGB }}, Path | Sort-Object Size -Descending | Format-Table -AutoSize
        $TotalToBeDeletedGB = [math]::Round(($ItemsToDelete | Measure-Object -Property SizeGB -Sum).Sum, 2)
        Write-Host ("Total space to be reclaimed: {0:N2} GB" -f $TotalToBeDeletedGB) -ForegroundColor Red
        Write-Host "========================================`n" -ForegroundColor Red
        
        $Confirmation = Read-Host "Proceed with PERMANENTLY deleting ALL ${ItemsToDelete.Count} items listed above? (Y/N)"
        
        if ($Confirmation -match '^(y|yes)$') {
            Write-Host "Initiating PERMANENT, FORCED deletion..." -ForegroundColor Red
            $DeletedCount = 0; $TotalDeletedSizeGB = 0.0
            foreach ($Item in $ItemsToDelete) {
                try {
                    Remove-Item -Path $Item.Path -Recurse -Force -ErrorAction Stop
                    $TotalDeletedSizeGB += $Item.SizeGB; $DeletedCount++
                    Write-Host "  [DELETED] {0}" -f $Item.Path -ForegroundColor Green
                }
                catch {
                    Write-Host "  [FAILED] Could not delete {0} (Error: {1})" -f $Item.Path, $_.Exception.Message -ForegroundColor DarkRed
                }
            }
            Write-Host "`nCleanup Complete!" -ForegroundColor Green
            Write-Host "Total items deleted: $DeletedCount" -ForegroundColor Green
            Write-Host ("Total space reclaimed: {0:N2} GB" -f $TotalDeletedSizeGB) -ForegroundColor Green 
        } else { Write-Host "Deletion cancelled by user." -ForegroundColor Yellow }
    }
    # --- End Local Cleanup Functions ---

    Write-Host "STATUS: Beginning Local Disk Cleanup." -ForegroundColor Green
    $AllResults = @()

    # 1. System-wide Temp Folder 
    $WindowsResults = Get-LargestTempItems -Path "C:\Windows\Temp"
    if ($WindowsResults) { $AllResults += $WindowsResults }

    Write-Host "`n========================================`n" -ForegroundColor DarkGray

    # --- USER PROFILE SELECTION ---
    Write-Host "--- User Profile Selection ---" -ForegroundColor Yellow

    $UserProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | 
        Where-Object {$_.Name -notmatch '^(Public|Default|Default User|All Users|Administrator|\.)$'} | 
        Sort-Object Name

    if (-not $UserProfiles) { Write-Host "Error: No active user profiles found under C:\Users." -ForegroundColor Red; exit }

    $ProfileMap = @{}; Write-Host "Please select the user profile to analyze (for AppData & Temp):" -ForegroundColor Cyan
    $UserProfilesToDisplay = @()
    for ($i = 0; $i -lt $UserProfiles.Count; $i++) {
        $Index = $i + 1
        $ProfileMap[$Index] = $UserProfiles[$i]
        $UserProfilesToDisplay += "  [{0}] {1}" -f $Index, $UserProfiles[$i].Name
    }
    $UserProfilesToDisplay | Out-Host

    do {
        $Selection = Read-Host "Enter the number of the profile to analyze (e.g., 1)"
        if ($ProfileMap.ContainsKey([int]$Selection)) { break }
        Write-Host "Invalid selection. Please enter a valid number from the list." -ForegroundColor Red
    } while ($true)

    $SelectedUser = $ProfileMap[[int]$Selection].Name
    $SelectedProfilePath = $ProfileMap[[int]$Selection].FullName
    Write-Host "`nSelected Profile: $SelectedUser ($SelectedProfilePath)" -ForegroundColor Green
    Write-Host "`nAnalysis starting for selected profile..." -ForegroundColor Cyan

    # 2. Selected User's Temp Folder
    $UserTempPath = Join-Path $SelectedProfilePath "AppData\Local\Temp"
    $UserTempResults = Get-LargestTempItems -Path $UserTempPath
    if ($UserTempResults) { $AllResults += $UserTempResults }

    Write-Host "`n========================================`n" -ForegroundColor DarkGray

    # 3. Selected User's Local AppData Folder (Program Caches/Data)
    $LocalAppDataPath = Join-Path $SelectedProfilePath "AppData\Local"
    $AppDataResults = Get-LargestTempItems -Path $LocalAppDataPath
    if ($AppDataResults) { $AllResults += $AppDataResults }

    # 4. Prompt for deletion
    if ($AllResults.Count -gt 0) {
        Prompt-And-Delete -ItemsToDelete $AllResults
    } else {
        Write-Host "`nNo major temporary or program files found for deletion." -ForegroundColor Cyan
    }
}


# --- 5. MAIN SCRIPT EXECUTION (Menu) ---

Write-Host "  [1] Remote System Diagnostics (Invoke-RemoteDataCollect)"
Write-Host "  [2] Local Disk Space Cleanup (Analyze-TempDiskUsage)"

$Mode = Read-Host "Enter the number of the mode to execute (1 or 2)"

switch ($Mode) {
    "1" {
        Invoke-RemoteDataCollection -RemoteWorkerScriptContent $RemoteWorkerScriptContent
    }
    "2" {
        Start-LocalTempCleanup
    }
    default {
        Write-Host "Invalid selection. Exiting." -ForegroundColor Red
    }
}
