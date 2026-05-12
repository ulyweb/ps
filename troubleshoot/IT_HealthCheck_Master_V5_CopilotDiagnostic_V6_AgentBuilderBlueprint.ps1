<# ============================================
 Master Deployment Tool: Enterprise Dashboard (Manage and Monitor UI)
 Architecture: All-in-One Embedded Payload (SPA Web App)
 Updates: Dynamic UI routing for launching HTML in Browser vs CSV in Excel
 Run As: Administrator on IT Workstation or Target Device
============================================ #>

$runMode = Read-Host "Run target: [L]ocal machine or [R]emote machine? (L/R)"
$isLocal = ($runMode -match "^(?i)l")

if ($isLocal) {
    $targetPC = $env:COMPUTERNAME
    Write-Host "`n[1/4] Target set to Local Machine ($targetPC). Skipping WinRM..." -ForegroundColor Cyan
} else {
    $targetPC = Read-Host "Enter the remote machine name or IP"
    Write-Host "`n[1/4] Establishing WinRM Session to $targetPC..." -ForegroundColor Cyan
    try {
        $sess = New-PSSession -ComputerName $targetPC -ErrorAction Stop
    } catch {
        Write-Host "CRITICAL ERROR: Failed to connect to $targetPC. Verify WinRM is running and the machine is online." -ForegroundColor Red
        exit
    }
}

# ==========================================
# EMBEDDED PAYLOAD: THE DASHBOARD SCRIPT
# ==========================================
$DashboardPayload = @'
<# ============================================
 Enterprise UI Health Dashboard
 Architecture: Multi-Tab SPA with On-Demand WMI/CIM Fetching
============================================ #>
if ($null -eq ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit }
if (-not (Test-Path "C:\Temp")) { New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null }
$ErrorActionPreference = "Continue" 

function Invoke-Interactive {
    param([string]$Execute, [string]$Argument)
    $activeUser = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if ($null -eq $activeUser) { return $false }
    $taskName = "DeviceAudit_Bridge_$([Math]::Abs((Get-Random)).ToString())"
    
    $action = New-ScheduledTaskAction -Execute $Execute -Argument $Argument
    $principal = New-ScheduledTaskPrincipal -UserId $activeUser -LogonType Interactive -RunLevel Highest
    $task = New-ScheduledTask -Action $action -Principal $principal
    
    try {
        Register-ScheduledTask -TaskName $taskName -InputObject $task -Force -ErrorAction SilentlyContinue | Out-Null
        Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Seconds 2
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        return $true
    } catch { return $false }
}

function Get-InteractiveWindows {
    $script = "Get-Process | Where-Object { -not [string]::IsNullOrWhiteSpace(`$_.MainWindowTitle) -and `$_.MainWindowTitle -ne 'Task Host Window' } | ForEach-Object { `"`$(`$_.Name)|`$(`$_.Id)|`$(`$_.MainWindowTitle)`" } | Out-File 'C:\Temp\active_windows.txt' -Force -Encoding UTF8"
    [System.IO.File]::WriteAllText("C:\Temp\GetWindows.ps1", $script)
    
    $vbs = "CreateObject(`"WScript.Shell`").Run `"powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Temp\GetWindows.ps1`", 0, True"
    [System.IO.File]::WriteAllText("C:\Temp\RunHidden.vbs", $vbs)
    
    Invoke-Interactive -Execute "wscript.exe" -Argument "C:\Temp\RunHidden.vbs" | Out-Null
    
    Start-Sleep -Seconds 2
    
    $winList = @()
    if (Test-Path "C:\Temp\active_windows.txt") {
        Get-Content "C:\Temp\active_windows.txt" | ForEach-Object {
            $parts = $_ -split '\|', 3
            if ($parts.Length -eq 3) {
                $winList += [pscustomobject]@{ Name = $parts[0]; PID = $parts[1]; Title = $parts[2] }
            }
        }
        Remove-Item "C:\Temp\active_windows.txt" -Force -ErrorAction SilentlyContinue
    }
    Remove-Item "C:\Temp\GetWindows.ps1" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Temp\RunHidden.vbs" -Force -ErrorAction SilentlyContinue
    return $winList
}

function ConvertTo-DashboardHtmlSafe {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    try { return [System.Net.WebUtility]::HtmlEncode([string]$Value) } catch { return [string]$Value }
}

function ConvertTo-DashboardInt {
    param([object]$Value)
    try { if ($null -eq $Value) { return 0 } return [int]$Value } catch { return 0 }
}

function Get-DashboardStatusClass {
    param([int]$Value, [int]$Warning, [int]$Critical)
    if ($Value -ge $Critical) { return "critical" }
    if ($Value -ge $Warning) { return "warning" }
    return "good"
}

function New-CaptureHtmlDashboard {
    param(
        [object[]]$Rows,
        [string]$OutputPath,
        [int]$Days,
        [datetime]$GeneratedAt,
        [hashtable]$SessionCache
    )

    if ($null -eq $Rows) { $Rows = @() }
    $rowsArray = @($Rows)
    $hostname = $env:COMPUTERNAME
    $firstRow = $null

    if ($rowsArray.Count -gt 0) { $firstRow = $rowsArray[0] }

    $manufacturer = ""; $model = ""; $cpu = ""; $totalRam = ""; $bios = ""; $bootTime = ""; $hibernate = ""; $vbs = ""; $hyperv = ""; $network = ""; $ipv4 = ""; $uptime = ""; $pendingReboot = ""; $recentPatches = ""; $activeWindows = ""; $recentProcesses = ""

    if ($null -ne $firstRow) {
        $manufacturer = $firstRow.Manufacturer
        $model = $firstRow.System_Model
        $cpu = $firstRow.CPU
        $totalRam = $firstRow.TotalRAM_GB
        $bios = $firstRow.BIOS_Version
        $bootTime = $firstRow.System_Boot_Time
        $hibernate = $firstRow.Hibernate_Status
        $vbs = $firstRow.VBS_Status
        $hyperv = $firstRow.HyperV_Status
        $network = $firstRow.ActiveNetwork
        $ipv4 = $firstRow.IPv4_Address
        $uptime = $firstRow.Uptime_Live
        $pendingReboot = $firstRow.PendingReboot_Live
        $recentPatches = $firstRow.RecentPatches_Live
        $activeWindows = $firstRow.Live_Active_Windows
        $recentProcesses = $firstRow.Live_Recent_Processes
    }

    $totalShutdowns = 0; $totalCleanReboots = 0; $totalBSODs = 0; $totalAppCrashes = 0; $totalAppHangs = 0; $totalNetworkDrops = 0
    $totalRamSpikes = 0; $totalDiskSpikes = 0; $totalCpuSpikes = 0
    $peakCpu = 0; $peakRam = 0; $peakDisk = 0; $peakGpu = 0; $peakNpu = 0

    foreach ($row in $rowsArray) {
        $totalShutdowns += ConvertTo-DashboardInt $row.Events_Shutdowns_Count
        $totalCleanReboots += ConvertTo-DashboardInt $row.Events_CleanReboots_Count
        $totalBSODs += ConvertTo-DashboardInt $row.Events_BlueScreens_Count
        $totalAppCrashes += ConvertTo-DashboardInt $row.Events_AppCrashes_Count
        $totalAppHangs += ConvertTo-DashboardInt $row.Events_AppHangs_Count
        $totalNetworkDrops += ConvertTo-DashboardInt $row.Events_NetworkDrops_Count
        
        $totalRamSpikes += ConvertTo-DashboardInt $row.Events_RAMSpikes_Count
        $totalDiskSpikes += ConvertTo-DashboardInt $row.Events_DiskSpikes_Count
        $totalCpuSpikes += ConvertTo-DashboardInt $row.Events_CPUSpikes_Count

        $cpuNow = ConvertTo-DashboardInt $row.Live_CPU_Usage_Pct
        $ramNow = ConvertTo-DashboardInt $row.Live_RAM_Usage_Pct
        $diskNow = ConvertTo-DashboardInt $row.Live_SystemDrive_Usage_Pct
        $gpuNow = ConvertTo-DashboardInt $row.Live_GPU_Usage_Pct
        $npuNow = ConvertTo-DashboardInt $row.Live_NPU_Usage_Pct

        if ($cpuNow -gt $peakCpu) { $peakCpu = $cpuNow }
        if ($ramNow -gt $peakRam) { $peakRam = $ramNow }
        if ($diskNow -gt $peakDisk) { $peakDisk = $diskNow }
        if ($gpuNow -gt $peakGpu) { $peakGpu = $gpuNow }
        if ($npuNow -gt $peakNpu) { $peakNpu = $npuNow }
    }

    $totalEvents = $totalShutdowns + $totalCleanReboots + $totalBSODs + $totalAppCrashes + $totalAppHangs + $totalNetworkDrops + $totalRamSpikes + $totalDiskSpikes + $totalCpuSpikes
    $healthClass = "good"; $healthText = "Stable"

    if ($totalBSODs -gt 0 -or $totalShutdowns -gt 0 -or $totalDiskSpikes -gt 0) {
        $healthClass = "critical"; $healthText = "Needs Review"
    } elseif ($totalAppCrashes -gt 0 -or $totalAppHangs -gt 0 -or $totalNetworkDrops -gt 0 -or $totalRamSpikes -gt 0 -or $totalCpuSpikes -gt 0) {
        $healthClass = "warning"; $healthText = "Review Recommended"
    }

    $cpuClass = Get-DashboardStatusClass -Value $peakCpu -Warning 60 -Critical 85
    $ramClass = Get-DashboardStatusClass -Value $peakRam -Warning 70 -Critical 90
    $diskClass = Get-DashboardStatusClass -Value $peakDisk -Warning 75 -Critical 90
    $gpuClass = Get-DashboardStatusClass -Value $peakGpu -Warning 60 -Critical 85
    $npuClass = Get-DashboardStatusClass -Value $peakNpu -Warning 60 -Critical 85

    $eventRowsHtml = ""
    foreach ($row in $rowsArray) {
        $shutdownCount = ConvertTo-DashboardInt $row.Events_Shutdowns_Count
        $rebootCount = ConvertTo-DashboardInt $row.Events_CleanReboots_Count
        $bsodCount = ConvertTo-DashboardInt $row.Events_BlueScreens_Count
        $crashCount = ConvertTo-DashboardInt $row.Events_AppCrashes_Count
        $hangCount = ConvertTo-DashboardInt $row.Events_AppHangs_Count
        $networkCount = ConvertTo-DashboardInt $row.Events_NetworkDrops_Count
        $ramSpikeCount = ConvertTo-DashboardInt $row.Events_RAMSpikes_Count
        $diskSpikeCount = ConvertTo-DashboardInt $row.Events_DiskSpikes_Count
        $cpuSpikeCount = ConvertTo-DashboardInt $row.Events_CPUSpikes_Count

        $shutdownClass = Get-DashboardStatusClass -Value $shutdownCount -Warning 1 -Critical 1
        $rebootClass = Get-DashboardStatusClass -Value $rebootCount -Warning 2 -Critical 5
        $bsodClass = Get-DashboardStatusClass -Value $bsodCount -Warning 1 -Critical 1
        $crashClass = Get-DashboardStatusClass -Value $crashCount -Warning 1 -Critical 5
        $hangClass = Get-DashboardStatusClass -Value $hangCount -Warning 1 -Critical 5
        $netClass = Get-DashboardStatusClass -Value $networkCount -Warning 1 -Critical 5
        $ramSpikeClass = Get-DashboardStatusClass -Value $ramSpikeCount -Warning 1 -Critical 5
        $diskSpikeClass = Get-DashboardStatusClass -Value $diskSpikeCount -Warning 1 -Critical 2
        $cpuSpikeClass = Get-DashboardStatusClass -Value $cpuSpikeCount -Warning 1 -Critical 5

        $eventRowsHtml += @"
<tr>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Report_Date)</td>
  <td><span class="badge $shutdownClass">$shutdownCount</span></td>
  <td><span class="badge $rebootClass">$rebootCount</span></td>
  <td><span class="badge $bsodClass">$bsodCount</span></td>
  <td><span class="badge $crashClass">$crashCount</span></td>
  <td><span class="badge $hangClass">$hangCount</span></td>
  <td><span class="badge $netClass">$networkCount</span></td>
  <td><span class="badge $ramSpikeClass">$ramSpikeCount</span></td>
  <td><span class="badge $diskSpikeClass">$diskSpikeCount</span></td>
  <td><span class="badge $cpuSpikeClass">$cpuSpikeCount</span></td>
</tr>
"@
    }

    $contextRowsHtml = ""
    foreach ($row in $rowsArray) {
        $contextRowsHtml += @"
<tr>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Report_Date)</td>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Context_Shutdowns)</td>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Context_CleanReboots)</td>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Context_BlueScreens)</td>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Context_AppCrashes)</td>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Context_AppHangs)</td>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Context_NetworkDrops)</td>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Context_RAMSpikes)</td>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Context_DiskSpikes)</td>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Context_CPUSpikes)</td>
</tr>
"@
    }

    $detailRowsHtml = ""
    foreach ($row in $rowsArray) {
        $detailRowsHtml += @"
<tr>
  <td>$(ConvertTo-DashboardHtmlSafe $row.Report_Date)</td>
  <td><div class="detailbox">$(ConvertTo-DashboardHtmlSafe $row.Details_Shutdowns)</div></td>
  <td><div class="detailbox">$(ConvertTo-DashboardHtmlSafe $row.Details_CleanReboots)</div></td>
  <td><div class="detailbox">$(ConvertTo-DashboardHtmlSafe $row.Details_BlueScreens)</div></td>
  <td><div class="detailbox">$(ConvertTo-DashboardHtmlSafe $row.Details_AppCrashes)</div></td>
  <td><div class="detailbox">$(ConvertTo-DashboardHtmlSafe $row.Details_AppHangs)</div></td>
  <td><div class="detailbox">$(ConvertTo-DashboardHtmlSafe $row.Details_NetworkDrops)</div></td>
  <td><div class="detailbox">$(ConvertTo-DashboardHtmlSafe $row.Details_RAMSpikes)</div></td>
  <td><div class="detailbox">$(ConvertTo-DashboardHtmlSafe $row.Details_DiskSpikes)</div></td>
  <td><div class="detailbox">$(ConvertTo-DashboardHtmlSafe $row.Details_CPUSpikes)</div></td>
</tr>
"@
    }

    # --- SESSION CACHE INJECTIONS ---
    $cacheHtml = ""

    if ($null -ne $SessionCache -and $null -ne $SessionCache.Processes) {
        $pRows = ""
        foreach ($p in $SessionCache.Processes) {
            $pRows += "<tr><td>$(ConvertTo-DashboardHtmlSafe $p.Name)</td><td>$(ConvertTo-DashboardHtmlSafe $p.PID)</td><td style='color:var(--accent); font-weight:bold;'>$(ConvertTo-DashboardHtmlSafe $p.CPU)%</td><td>$(ConvertTo-DashboardHtmlSafe $p.RAM) MB</td></tr>"
        }
        $copilotPromptHtml
      $cacheHtml += @"
<div class="card span-12">
    <h2>Snapshot: Active Processes (Fetched during session)</h2>
    <div class="table-wrapper">
        <table>
            <thead><tr><th>Process Name</th><th>PID</th><th>CPU Utilization</th><th>Memory Usage</th></tr></thead>
            <tbody>$pRows</tbody>
        </table>
    </div>
</div>
"@
    }

    if ($null -ne $SessionCache -and $null -ne $SessionCache.Services) {
        $sRows = ""
        foreach ($s in $SessionCache.Services) {
            $sBadge = "warning"
            if ($s.Status -match 'Running') { $sBadge = "good" }
            if ($s.Status -match 'Stopped') { $sBadge = "critical" }
            $sRows += "<tr><td>$(ConvertTo-DashboardHtmlSafe $s.DisplayName)</td><td>$(ConvertTo-DashboardHtmlSafe $s.Name)</td><td><span class='badge $sBadge'>$(ConvertTo-DashboardHtmlSafe $s.Status)</span></td><td>$(ConvertTo-DashboardHtmlSafe $s.StartType)</td></tr>"
        }
        $copilotPromptHtml
      $cacheHtml += @"
<div class="card span-12">
    <h2>Snapshot: System Services (Fetched during session)</h2>
    <div class="table-wrapper">
        <table>
            <thead><tr><th>Display Name</th><th>Internal Name</th><th>Status</th><th>Startup Type</th></tr></thead>
            <tbody>$sRows</tbody>
        </table>
    </div>
</div>
"@
    }

    if ($null -ne $SessionCache -and $null -ne $SessionCache.Apps) {
        $aRows = ""
        foreach ($a in $SessionCache.Apps) {
            $aRows += "<tr><td>$(ConvertTo-DashboardHtmlSafe $a.Name)</td><td>$(ConvertTo-DashboardHtmlSafe $a.Publisher)</td><td>$(ConvertTo-DashboardHtmlSafe $a.Version)</td></tr>"
        }
        $copilotPromptHtml
      $cacheHtml += @"
<div class="card span-12">
    <h2>Snapshot: Installed Applications (Fetched during session)</h2>
    <div class="table-wrapper">
        <table>
            <thead><tr><th>Application Name</th><th>Publisher</th><th>Version</th></tr></thead>
            <tbody>$aRows</tbody>
        </table>
    </div>
</div>
"@
    }

    if ($null -ne $SessionCache -and $null -ne $SessionCache.Hardware) {
        $hRows = ""
        foreach ($h in $SessionCache.Hardware) {
            $hBadge = if($h.Status -eq 'OK'){"good"}else{"critical"}
            $hRows += "<tr><td>$(ConvertTo-DashboardHtmlSafe $h.Name)</td><td>$(ConvertTo-DashboardHtmlSafe $h.Manufacturer)</td><td>$(ConvertTo-DashboardHtmlSafe $h.DeviceID)</td><td><span class='badge $hBadge'>$(ConvertTo-DashboardHtmlSafe $h.Status)</span></td></tr>"
        }
        $copilotPromptHtml
      $cacheHtml += @"
<div class="card span-12">
    <h2>Snapshot: Device Manager (Fetched during session)</h2>
    <div class="table-wrapper">
        <table>
            <thead><tr><th>Device Name</th><th>Manufacturer</th><th>Device ID</th><th>Status</th></tr></thead>
            <tbody>$hRows</tbody>
        </table>
    </div>
</div>
"@
    }

    $safeHost = ConvertTo-DashboardHtmlSafe $hostname
    $safeManufacturer = ConvertTo-DashboardHtmlSafe $manufacturer
    $safeModel = ConvertTo-DashboardHtmlSafe $model
    $safeCpu = ConvertTo-DashboardHtmlSafe $cpu
    $safeTotalRam = ConvertTo-DashboardHtmlSafe $totalRam
    $safeBios = ConvertTo-DashboardHtmlSafe $bios
    $safeBootTime = ConvertTo-DashboardHtmlSafe $bootTime
    $safeHibernate = ConvertTo-DashboardHtmlSafe $hibernate
    $safeVbs = ConvertTo-DashboardHtmlSafe $vbs
    $safeHyperv = ConvertTo-DashboardHtmlSafe $hyperv
    $safeNetwork = ConvertTo-DashboardHtmlSafe $network
    $safeIpv4 = ConvertTo-DashboardHtmlSafe $ipv4
    $safeUptime = ConvertTo-DashboardHtmlSafe $uptime
    $safePendingReboot = ConvertTo-DashboardHtmlSafe $pendingReboot
    $safeRecentPatches = ConvertTo-DashboardHtmlSafe $recentPatches
    $safeActiveWindows = ConvertTo-DashboardHtmlSafe $activeWindows
    $safeRecentProcesses = ConvertTo-DashboardHtmlSafe $recentProcesses
    $generatedText = $GeneratedAt.ToString("yyyy-MM-dd HH:mm:ss")

    # --- COPILOT DIAGNOSTIC PROMPT GENERATOR V5 ---
    # Purpose:
    #   Creates exactly two copy/paste-ready Copilot prompts inside the exported HTML dashboard:
    #   1. Root Cause + Safe Self-Healing
    #   2. ServiceNow + User Communication
    #
    # Design:
    #   General IT department wording, not Executive-only.
    #   Safe remediation model:
    #     Detect -> Summarize -> Recommend -> Approve -> Remediate -> Document

    $summaryForCopilot = @"
IT_HealthCheck Report Summary

System Identity:
- Hostname: $hostname
- Manufacturer: $manufacturer
- Model: $model
- CPU: $cpu
- Total RAM GB: $totalRam
- BIOS Version: $bios
- System Boot Time: $bootTime
- Hibernate Status: $hibernate
- VBS Status: $vbs
- Hyper-V Status: $hyperv

Network:
- Active Network: $network
- IPv4 Address: $ipv4

Live Resource Metrics:
- Peak CPU: $peakCpu%
- Peak RAM: $peakRam%
- Peak Disk: $peakDisk%
- Peak GPU: $peakGpu%
- Peak NPU: $peakNpu%
- Uptime: $uptime
- Pending Reboot: $pendingReboot
- Recent Patches: $recentPatches

Historical Event Counts:
- Total Events: $totalEvents
- Unexpected Shutdowns: $totalShutdowns
- Clean Reboots: $totalCleanReboots
- BSOD / Bugcheck Events: $totalBSODs
- Application Crashes: $totalAppCrashes
- Application Hangs: $totalAppHangs
- Network Drops: $totalNetworkDrops
- RAM Exhaustion Events: $totalRamSpikes
- Disk Warning Events: $totalDiskSpikes
- CPU / Thermal / Processor Power Events: $totalCpuSpikes

Live User / Session Context:
- Active Windows at Capture Time:
$activeWindows

- Recently Launched Processes at Capture Time:
$recentProcesses

Session Cache Notes:
- Processes Snapshot: Included in this HTML report if fetched during the support session.
- Services Snapshot: Included in this HTML report if fetched during the support session.
- Installed Apps Snapshot: Included in this HTML report if fetched during the support session.
- Device Manager Snapshot: Included in this HTML report if fetched during the support session.

Daily Matrix, Context Details, and Expanded Diagnostic Event Details are included in the report below.
"@

    $rootCausePrompt = @"
Act as a senior Windows 11 endpoint support engineer for a general IT department.

I am providing an IT_HealthCheck report generated from an internal diagnostic dashboard. Analyze the evidence and help identify likely root cause and safe self-healing actions.

Important rules:
- Separate confirmed findings from likely causes.
- Do not assume facts that are not present in the report.
- Use built-in Windows tools and safe recovery steps first.
- Do not recommend destructive actions, OS reset, profile rebuild, registry edits, driver removal, device removal, service changes, or hardware replacement unless the evidence supports it and IT approval is required.
- Prioritize business continuity, user productivity, data safety, and audit-ready support.
- If evidence is inconclusive, state exactly what should be checked next.

Analyze these areas:
1. Unexpected shutdowns, clean reboots, Kernel-Power, and BSOD / bugcheck events.
2. Application crashes and hangs.
3. Network drops, IPv4, active adapter, and link speed.
4. RAM exhaustion, disk warnings, CPU / thermal / processor power events.
5. Live CPU, RAM, disk, GPU, and NPU usage.
6. BIOS, system model, boot time, hibernate status, VBS, and Hyper-V status.
7. Active windows and recently launched processes.
8. Session cache snapshots for processes, services, installed apps, and Device Manager.
9. Pending reboot and recent patches.

Return the answer using this format:
- Overall Health Assessment
- Confirmed Findings
- Likely Root Cause Category
- Safe Self-Healing Steps
- Admin-Only Remediation Steps
- What Not To Do Yet
- What Evidence To Collect Next
- Escalation Recommendation

Here is the IT_HealthCheck report summary:

$summaryForCopilot
"@

    $ticketPrompt = @"
Act as an IT Service Desk documentation assistant.

Use the IT_HealthCheck report summary below to create support-ready documentation for a general IT department ticket.

Important rules:
- Keep the language professional, concise, and audit-ready.
- Do not overstate root cause unless confirmed by evidence.
- Separate investigation, actions taken, and recommended next steps.
- Include business impact in plain language.
- Include a short user-facing message that is polite and non-technical.
- If the issue is unresolved, set status to Open / Monitoring or Open / Pending Follow-up.
- If the report supports resolution, set status to Resolved and explain why.

Return the answer using this format:

Category:
[INC, RITM, or INFO]

Subject:
[Short professional summary]

Business Impact:
[1-2 sentences]

Description:
[Concise issue/report summary]

Work Notes:
1. Requester:
2. Device:
3. Issue / Objective:
4. Investigation Summary:
5. Confirmed Findings:
6. Likely Cause:
7. Resolution / Action Plan:
8. Follow-Up / Monitoring:
9. Status:

User Message:
[Short, friendly, professional message to send to the user]

Here is the IT_HealthCheck report summary:

$summaryForCopilot
"@

    $safeRootCausePrompt = ConvertTo-DashboardHtmlSafe $rootCausePrompt
    $safeTicketPrompt = ConvertTo-DashboardHtmlSafe $ticketPrompt

    # --- AGENT BUILDER BLUEPRINT V6 ---
    # Purpose:
    #   Provides a ready-to-copy package for creating a dedicated
    #   IT_HealthCheck Windows 11 Self-Healing Agent in Microsoft 365
    #   Copilot Agent Builder or Copilot Studio.
    #
    # Note:
    #   This does not create the agent automatically.
    #   It gives IT staff a complete name, description, instructions,
    #   guardrails, starter prompts, and knowledge-source guidance.

    $agentBuilderPrompt = @"
Create a new Microsoft 365 Copilot agent or Copilot Studio agent using the following blueprint.

Agent Name:
IT_HealthCheck Windows 11 Self-Healing Assistant

Agent Description:
A general IT support agent that analyzes IT_HealthCheck dashboard reports, Windows 11 endpoint telemetry, event logs, resource anomalies, and support-session snapshots to identify likely root cause, recommend safe self-healing actions, and generate ticket-ready documentation.

Primary Users:
General IT support technicians, endpoint support engineers, service desk analysts, field support technicians, and escalation support teams.

Agent Purpose:
Help IT technicians interpret IT_HealthCheck HTML or CSV reports and convert raw Windows 11 evidence into safe, structured troubleshooting guidance and support documentation.

Core Responsibilities:
1. Analyze IT_HealthCheck report summaries.
2. Separate confirmed findings from likely causes.
3. Identify likely root cause categories such as hardware, OS, user profile, application, network, docking/peripheral, thermal, storage, memory, update, or policy-related.
4. Recommend safe built-in Windows recovery steps first.
5. Clearly label admin-only remediation.
6. Avoid destructive repair unless evidence supports escalation.
7. Generate ServiceNow-ready or ITSM-ready documentation.
8. Generate a short, professional user-facing message.
9. Recommend next evidence to collect if findings are inconclusive.

Operating Model:
Use this workflow:
Detect -> Summarize -> Recommend -> Approve -> Remediate -> Document

Safety and Governance Rules:
- Do not claim a root cause unless the report evidence supports it.
- Do not recommend OS reset, profile rebuild, registry edits, driver removal, device removal, hardware replacement, or service changes unless evidence supports it and IT approval is required.
- Do not recommend bypassing security tools, disabling EDR/AV, or weakening corporate policy.
- Prefer built-in Windows tools first, such as Windows Update, Get Help troubleshooters, Device Manager review, Reliability Monitor, Event Viewer review, Settings checks, and safe application restart/reset steps.
- Treat device removal, service stop/start, hibernate enablement, GPUpdate, process termination, and driver-level actions as IT-controlled remediation.
- If the evidence is incomplete, say what is missing and what to capture next.
- Keep output concise, professional, and audit-ready.
- Use general IT support language, not executive-only language.

Inputs the agent should expect:
- IT_HealthCheck HTML dashboard text
- IT_HealthCheck CSV rows
- Event detail sections
- User symptom summary
- Business impact
- Device model and hostname
- Active processes snapshot
- Services snapshot
- Installed apps snapshot
- Device Manager snapshot
- Recent patches
- Pending reboot status
- Network, IPv4, adapter, link speed
- Hibernate, VBS, Hyper-V, BIOS, boot time
- RAM exhaustion, disk warnings, CPU/thermal warnings
- Shutdowns, BSODs, application crashes, application hangs, and network drops

Output Format 1 - Root Cause and Safe Self-Healing:
When asked to analyze a report, return:
1. Overall Health Assessment
2. Confirmed Findings
3. Likely Root Cause Category
4. Safe Self-Healing Steps
5. Admin-Only Remediation Steps
6. What Not To Do Yet
7. What Evidence To Collect Next
8. Escalation Recommendation

Output Format 2 - Ticket and User Communication:
When asked to create documentation, return:
Category:
Subject:
Business Impact:
Description:
Work Notes:
1. Requester
2. Device
3. Issue / Objective
4. Investigation Summary
5. Confirmed Findings
6. Likely Cause
7. Resolution / Action Plan
8. Follow-Up / Monitoring
9. Status

User Message:
Short, friendly, professional, non-technical message for the user.

Starter Prompts:
1. Analyze this IT_HealthCheck report and identify the likely root cause with safe self-healing steps.
2. Create an ITSM ticket summary and user-facing message from this IT_HealthCheck report.
3. Determine whether this issue appears hardware, OS, profile, application, network, dock/peripheral, thermal, memory, storage, update, or policy-related.
4. Review these Windows 11 event details and tell me what evidence is confirmed versus only possible.
5. Recommend safe next steps and tell me what should not be done yet.

Knowledge Source Guidance:
Add internal IT documentation if available, such as:
- Windows 11 endpoint support runbooks
- Service Desk troubleshooting standards
- Device replacement or break/fix policy
- Endpoint engineering guidance
- Printer support guidance
- Docking station troubleshooting guide
- VPN/network support guide
- Security and EDR handling policy
- ServiceNow documentation standards
- IT_HealthCheck README or operating guide

Recommended Agent Behavior:
- Always ask for the report or symptom details if none are provided.
- Never invent missing event IDs or root cause.
- If a report shows no clear failure pattern, recommend continued monitoring and specific next evidence.
- If the report shows BSOD, repeated Kernel-Power, disk warnings, or thermal throttling, prioritize stability and hardware/firmware review.
- If the report shows app crashes/hangs with no OS-level instability, prioritize application/profile/add-in troubleshooting.
- If the report shows network drops, prioritize adapter, driver, Wi-Fi, dock, VPN, and network path review.
- If pending reboot is true or recent patches are present, consider reboot/update completion as a safe early action.
- If Device Manager snapshot shows non-OK devices, recommend review before device removal.
- If service actions are needed, label them as admin-only and require IT approval.

Test Prompt After Creating Agent:
Analyze this IT_HealthCheck report. Separate confirmed findings from likely causes. Recommend safe self-healing steps first, identify any admin-only remediation, and provide ITSM-ready work notes plus a user-facing message.

Current Report Summary Template:
$summaryForCopilot
"@

    $safeAgentBuilderPrompt = ConvertTo-DashboardHtmlSafe $agentBuilderPrompt

    $copilotPromptHtml = @"
      <div class="card span-12">
        <h2>Copilot Diagnostic Assistant</h2>
        <div style="color:var(--muted); font-size:13px; line-height:1.6; margin-bottom:16px;">
          Use this section to reduce IT troubleshooting to two guided Copilot actions. 
          Copy Prompt 1 for root cause and safe self-healing guidance. 
          Copy Prompt 2 for ticket documentation and user communication.
        </div>

        <div class="grid" style="grid-template-columns:repeat(2,minmax(320px,1fr)); gap:18px;">
          
          <div style="background:rgba(2,6,23,.45); border:1px solid var(--border); border-radius:16px; padding:16px;">
            <h2 style="margin-bottom:10px;">Prompt 1 - Root Cause + Safe Self-Healing</h2>
            <div style="color:var(--muted); font-size:12px; line-height:1.5; margin-bottom:10px;">
              Paste this into Copilot to analyze likely root cause, safe recovery steps, admin-only actions, and escalation guidance.
            </div>
            <textarea id="copilotPromptRootCause" readonly style="width:100%; min-height:260px; resize:vertical; background:#020617; color:#cbd5e1; border:1px solid var(--border); border-radius:12px; padding:12px; font-family:Consolas, monospace; font-size:12px; line-height:1.5;">$safeRootCausePrompt</textarea>
            <button 
              onclick="(function(t){t.focus();t.select();document.execCommand('copy');})(document.getElementById('copilotPromptRootCause'))"
              style="margin-top:12px; background:transparent; border:1px solid var(--accent); color:var(--accent); padding:9px 14px; border-radius:8px; font-size:12px; font-weight:700; cursor:pointer; text-transform:uppercase; letter-spacing:.8px;">
              Copy Prompt 1
            </button>
          </div>

          <div style="background:rgba(2,6,23,.45); border:1px solid var(--border); border-radius:16px; padding:16px;">
            <h2 style="margin-bottom:10px;">Prompt 2 - Ticket + User Communication</h2>
            <div style="color:var(--muted); font-size:12px; line-height:1.5; margin-bottom:10px;">
              Paste this into Copilot to create Service Desk-ready notes, action plan, status, and a professional user-facing message.
            </div>
            <textarea id="copilotPromptTicket" readonly style="width:100%; min-height:260px; resize:vertical; background:#020617; color:#cbd5e1; border:1px solid var(--border); border-radius:12px; padding:12px; font-family:Consolas, monospace; font-size:12px; line-height:1.5;">$safeTicketPrompt</textarea>
            <button 
              onclick="(function(t){t.focus();t.select();document.execCommand('copy');})(document.getElementById('copilotPromptTicket'))"
              style="margin-top:12px; background:transparent; border:1px solid var(--accent); color:var(--accent); padding:9px 14px; border-radius:8px; font-size:12px; font-weight:700; cursor:pointer; text-transform:uppercase; letter-spacing:.8px;">
              Copy Prompt 2
            </button>
          </div>

        </div>

        <div style="margin-top:16px; color:var(--muted); font-size:12px; line-height:1.5;">
        <details style="margin-top:18px; background:rgba(2,6,23,.45); border:1px solid var(--border); border-radius:16px; padding:16px;">
          <summary style="cursor:pointer; color:var(--accent); font-weight:800; text-transform:uppercase; letter-spacing:.8px;">
            IT_HealthCheck Agent Builder Blueprint
          </summary>

          <div style="color:var(--muted); font-size:12px; line-height:1.5; margin-top:12px; margin-bottom:12px;">
            Use this package to build a dedicated IT_HealthCheck Windows 11 Self-Healing Agent in Microsoft 365 Copilot Agent Builder or Copilot Studio. 
            This is intended for agent creators and IT leads, not for every daily troubleshooting session.
          </div>

          <textarea id="agentBuilderPrompt" readonly style="width:100%; min-height:300px; resize:vertical; background:#020617; color:#cbd5e1; border:1px solid var(--border); border-radius:12px; padding:12px; font-family:Consolas, monospace; font-size:12px; line-height:1.5;">$safeAgentBuilderPrompt</textarea>

          <button
            onclick="(function(t){t.focus();t.select();document.execCommand('copy');})(document.getElementById('agentBuilderPrompt'))"
            style="margin-top:12px; background:transparent; border:1px solid var(--accent); color:var(--accent); padding:9px 14px; border-radius:8px; font-size:12px; font-weight:700; cursor:pointer; text-transform:uppercase; letter-spacing:.8px;">
            Copy Agent Builder Blueprint
          </button>

          <div style="margin-top:12px; color:var(--muted); font-size:12px; line-height:1.5;">
            Suggested usage: Create the agent once, test it with several IT_HealthCheck reports, then publish/share according to your organization’s AI governance process.
          </div>
        </details>
          Recommended workflow: Generate report → Copy Prompt 1 into Copilot → Review safe remediation → Copy Prompt 2 for ticket notes and user communication.
        </div>
      </div>
"@

    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Enterprise IT Capture Dashboard - $safeHost</title>
<style>
:root {
  --bg:#070b14;
  --panel:#111827;
  --panel2:#0f172a;
  --text:#e5e7eb;
  --muted:#94a3b8;
  --border:#1f2937;
  --accent:#38bdf8;
  --good:#10b981;
  --warning:#f59e0b;
  --critical:#ef4444;
  --shadow:0 12px 35px rgba(0,0,0,.35);
}

* { box-sizing:border-box; }

body {
  margin:0;
  font-family:Segoe UI, Arial, sans-serif;
  background:
    radial-gradient(circle at top left, rgba(56,189,248,.16), transparent 30%),
    radial-gradient(circle at top right, rgba(16,185,129,.12), transparent 28%),
    var(--bg);
  color:var(--text);
}

.header {
  padding:28px 34px;
  border-bottom:1px solid var(--border);
  background:rgba(15,23,42,.90);
}

.header-top {
  display:flex;
  justify-content:space-between;
  gap:20px;
  align-items:flex-start;
}

h1 {
  margin:0;
  font-size:26px;
  letter-spacing:.4px;
}

.subtitle {
  margin-top:8px;
  color:var(--muted);
  font-size:13px;
}

.status-pill {
  display:inline-flex;
  align-items:center;
  border:1px solid var(--border);
  background:rgba(255,255,255,.03);
  border-radius:999px;
  padding:8px 12px;
  font-size:12px;
  font-weight:700;
  text-transform:uppercase;
  letter-spacing:.8px;
}

.status-pill.good { color:var(--good); border-color:rgba(16,185,129,.35); }
.status-pill.warning { color:var(--warning); border-color:rgba(245,158,11,.35); }
.status-pill.critical { color:var(--critical); border-color:rgba(239,68,68,.35); }

.container { padding:28px 34px 42px; overflow-x: auto; }

.grid {
  display:grid;
  grid-template-columns:repeat(12,1fr);
  gap:18px;
}

.card {
  background:linear-gradient(180deg, rgba(17,24,39,.96), rgba(15,23,42,.96));
  border:1px solid var(--border);
  border-radius:18px;
  padding:20px;
  box-shadow:var(--shadow);
}

.card h2 {
  margin:0 0 16px;
  color:var(--accent);
  font-size:13px;
  text-transform:uppercase;
  letter-spacing:1.2px;
}

.span-3 { grid-column:span 3; }
.span-4 { grid-column:span 4; }
.span-6 { grid-column:span 6; }
.span-12 { grid-column:span 12; }

.metric-value {
  font-size:30px;
  font-weight:800;
  margin-bottom:6px;
}

.metric-label {
  color:var(--muted);
  font-size:12px;
  line-height:1.4;
}

.kv {
  display:flex;
  justify-content:space-between;
  gap:16px;
  padding:9px 0;
  border-bottom:1px dashed rgba(148,163,184,.22);
  font-size:13px;
}

.kv:last-child { border-bottom:0; }
.kv .k { color:var(--muted); }

.kv .v {
  text-align:right;
  font-weight:600;
  max-width:68%;
  overflow-wrap:anywhere;
}

.bar {
  height:10px;
  background:#1e293b;
  border-radius:999px;
  overflow:hidden;
  margin-top:12px;
  border:1px solid rgba(148,163,184,.18);
}

.fill { height:100%; }
.fill.good { background:var(--good); }
.fill.warning { background:var(--warning); }
.fill.critical { background:var(--critical); }

.table-wrapper {
  overflow-x: auto;
  border: 1px solid var(--border);
  border-radius: 8px;
}

table {
  width:100%;
  border-collapse:collapse;
  font-size:12px;
}

th {
  color:var(--accent);
  text-transform:uppercase;
  letter-spacing:.8px;
  font-size:11px;
  text-align:left;
  padding:12px;
  background:rgba(2,6,23,.45);
  border-bottom:1px solid var(--border);
  white-space: nowrap;
}

td {
  padding:12px;
  border-bottom:1px solid rgba(31,41,55,.85);
  vertical-align:top;
}

tr:hover td { background:rgba(56,189,248,.04); }

.badge {
  display:inline-block;
  min-width:30px;
  text-align:center;
  border-radius:8px;
  padding:4px 8px;
  font-weight:800;
  border:1px solid transparent;
}

.badge.good {
  color:var(--good);
  background:rgba(16,185,129,.10);
  border-color:rgba(16,185,129,.28);
}

.badge.warning {
  color:var(--warning);
  background:rgba(245,158,11,.10);
  border-color:rgba(245,158,11,.28);
}

.badge.critical {
  color:var(--critical);
  background:rgba(239,68,68,.10);
  border-color:rgba(239,68,68,.28);
}

.prebox,
.detailbox {
  white-space:pre-wrap;
  word-break:break-word;
  color:#cbd5e1;
  background:rgba(2,6,23,.45);
  border:1px solid var(--border);
  border-radius:14px;
  padding:14px;
  font-family:Consolas, monospace;
  font-size:12px;
  line-height:1.55;
  max-height:280px;
  overflow:auto;
}

.detailbox {
  min-width:260px;
}

.footer {
  color:var(--muted);
  font-size:12px;
  margin-top:24px;
  text-align:center;
}

@media print {
  body { background:white; color:black; }
  .header { background:white; }
  .card { box-shadow:none; break-inside:avoid; }
}

@media (max-width:1100px) {
  .span-3, .span-4,
  .span-6 { grid-column:span 12; }
  .header-top { flex-direction:column; }
}
</style>
</head>
<body>
  <div class="header">
    <div class="header-top">
      <div>
        <h1>Enterprise IT Manage and Monitor Capture Dashboard</h1>
        <div class="subtitle">
          Host: <b>$safeHost</b> &nbsp; | &nbsp;
          IPv4: <b>$safeIpv4</b> &nbsp; | &nbsp;
          Lookback: <b>$Days</b> day(s) &nbsp; | &nbsp;
          Generated: <b>$generatedText</b>
        </div>
      </div>
      <div class="status-pill $healthClass">$healthText</div>
    </div>
  </div>

  <div class="container">
    <div class="grid">

      <div class="card span-12" style="margin-bottom: 5px;">
        <h2>Historical Resource Anomaly Warnings (Spikes)</h2>
        <div class="grid" style="grid-template-columns: repeat(3, 1fr); gap: 10px; margin-top: 0; margin-bottom: 0;">
            <div style="background: rgba(2,6,23,.45); padding: 15px; border-radius: 8px; border: 1px solid var(--border);">
                <div class="metric-label">Memory Exhaustion Events (RAM)</div>
                <div class="metric-value" style="color: $(if($totalRamSpikes -gt 0){'var(--warning)'}else{'var(--good)'})">$totalRamSpikes</div>
            </div>
            <div style="background: rgba(2,6,23,.45); padding: 15px; border-radius: 8px; border: 1px solid var(--border);">
                <div class="metric-label">Low Storage Capacity Warnings (Disk)</div>
                <div class="metric-value" style="color: $(if($totalDiskSpikes -gt 0){'var(--critical)'}else{'var(--good)'})">$totalDiskSpikes</div>
            </div>
            <div style="background: rgba(2,6,23,.45); padding: 15px; border-radius: 8px; border: 1px solid var(--border);">
                <div class="metric-label">Thermal Throttling / Processor Power Warnings (CPU)</div>
                <div class="metric-value" style="color: $(if($totalCpuSpikes -gt 0){'var(--warning)'}else{'var(--good)'})">$totalCpuSpikes</div>
            </div>
        </div>
      </div>

      <div class="card span-3">
        <h2>Total Events</h2>
        <div class="metric-value">$totalEvents</div>
        <div class="metric-label">Combined shutdown, reboot, BSOD, application, network, and resource events.</div>
      </div>

      <div class="card span-3">
        <h2>BSOD Events</h2>
        <div class="metric-value">$totalBSODs</div>
        <div class="metric-label">Bugcheck / blue screen indicators from System logs.</div>
      </div>

      <div class="card span-3">
        <h2>Unexpected Shutdowns</h2>
        <div class="metric-value">$totalShutdowns</div>
        <div class="metric-label">Kernel-Power or unexpected shutdown activity.</div>
      </div>

      <div class="card span-3">
        <h2>Network Drops</h2>
        <div class="metric-value">$totalNetworkDrops</div>
        <div class="metric-label">NDIS / WLAN warning or error activity.</div>
      </div>

      <div class="card span-6">
        <h2>System Identity</h2>
        <div class="kv"><div class="k">Manufacturer</div><div class="v">$safeManufacturer</div></div>
        <div class="kv"><div class="k">Model</div><div class="v">$safeModel</div></div>
        <div class="kv"><div class="k">CPU</div><div class="v">$safeCpu</div></div>
        <div class="kv"><div class="k">Total RAM</div><div class="v">$safeTotalRam GB</div></div>
        <div class="kv"><div class="k">BIOS</div><div class="v">$safeBios</div></div>
        <div class="kv"><div class="k">Boot Time</div><div class="v">$safeBootTime</div></div>
        <div class="kv"><div class="k">Hibernate Status</div><div class="v">$safeHibernate</div></div>
      </div>

      <div class="card span-6">
        <h2>Security and Network</h2>
        <div class="kv"><div class="k">VBS Status</div><div class="v">$safeVbs</div></div>
        <div class="kv"><div class="k">Hyper-V</div><div class="v">$safeHyperv</div></div>
        <div class="kv"><div class="k">IPv4 Address</div><div class="v">$safeIpv4</div></div>
        <div class="kv"><div class="k">Active Network</div><div class="v">$safeNetwork</div></div>
        <div class="kv"><div class="k">Live Uptime</div><div class="v">$safeUptime</div></div>
        <div class="kv"><div class="k">Pending Reboot</div><div class="v">$safePendingReboot</div></div>
      </div>

      <div class="card span-3">
        <h2>Peak CPU</h2>
        <div class="metric-value">$peakCpu%</div>
        <div class="bar"><div class="fill $cpuClass" style="width:$peakCpu%"></div></div>
      </div>

      <div class="card span-3">
        <h2>Peak RAM</h2>
        <div class="metric-value">$peakRam%</div>
        <div class="bar"><div class="fill $ramClass" style="width:$peakRam%"></div></div>
      </div>

      <div class="card span-3">
        <h2>Peak Disk</h2>
        <div class="metric-value">$peakDisk%</div>
        <div class="bar"><div class="fill $diskClass" style="width:$peakDisk%"></div></div>
      </div>

      <div class="card span-3">
        <h2>Peak GPU / NPU</h2>
        <div class="metric-label">GPU: <b>$peakGpu%</b></div>
        <div class="bar"><div class="fill $gpuClass" style="width:$peakGpu%"></div></div>
        <div style="height:10px"></div>
        <div class="metric-label">NPU: <b>$peakNpu%</b></div>
        <div class="bar"><div class="fill $npuClass" style="width:$peakNpu%"></div></div>
      </div>

      <div class="card span-12">
        <h2>Daily Event Matrix</h2>
        <div class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Unexpected Shutdowns</th>
              <th>Clean Reboots</th>
              <th>BSODs</th>
              <th>App Crashes</th>
              <th>App Hangs</th>
              <th>Network Drops</th>
              <th>RAM Exhaustion</th>
              <th>Disk Warnings</th>
              <th>CPU/Thermal Spikes</th>
            </tr>
          </thead>
          <tbody>
            $eventRowsHtml
          </tbody>
        </table>
        </div>
      </div>

      <div class="card span-12">
        <h2>Event Context Details</h2>
        <div class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Shutdown Context</th>
              <th>Reboot Context</th>
              <th>BSOD Context</th>
              <th>Crash Context</th>
              <th>Hang Context</th>
              <th>Network Context</th>
              <th>RAM Spikes</th>
              <th>Disk Spikes</th>
              <th>CPU Spikes</th>
            </tr>
          </thead>
          <tbody>
            $contextRowsHtml
          </tbody>
        </table>
        </div>
      </div>

      <div class="card span-12">
        <h2>Expanded Diagnostic Event Details</h2>
        <div class="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Shutdown Details</th>
              <th>Reboot Details</th>
              <th>BSOD Details</th>
              <th>Crash Details</th>
              <th>Hang Details</th>
              <th>Network Details</th>
              <th>RAM Details</th>
              <th>Disk Details</th>
              <th>CPU Details</th>
            </tr>
          </thead>
          <tbody>
            $detailRowsHtml
          </tbody>
        </table>
        </div>
      </div>

      <div class="card span-6">
        <h2>Live Active Windows at Capture Time</h2>
        <div class="prebox">$safeActiveWindows</div>
      </div>

      <div class="card span-6">
        <h2>Recently Launched Processes at Capture Time</h2>
        <div class="prebox">$safeRecentProcesses</div>
      </div>

      <div class="card span-12">
        <h2>Recent Patch Snapshot</h2>
        <div class="prebox">$safeRecentPatches</div>
      </div>
      
      $copilotPromptHtml
      $cacheHtml

    </div>

    <div class="footer">
      Offline HTML report generated by Enterprise IT Manage and Monitor Dashboard. Source CSV remains available separately for audit/export.
    </div>
  </div>
</body>
</html>
"@

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($OutputPath, $html, $utf8NoBom)
    return $OutputPath
}

# --- HTML/CSS/JS SINGLE PAGE APP PAYLOAD ---
$htmlPayload = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Manage and Monitor - $($env:COMPUTERNAME)</title>
<style>
  :root {
    --bg: #0b0f19; --sidebar: #0f1523; --panel: #141c2f; --text: #e2e8f0; --text-muted: #94a3b8;
    --accent: #0ea5e9; --accent-hover: #38bdf8; --border: #1e293b; --good: #10b981; --bad: #ef4444; --warn: #f59e0b;
    --glow: 0 0 15px rgba(14, 165, 233, 0.3);
  }
  
  body.light-mode {
    --bg: #f8fafc; --sidebar: #f1f5f9; --panel: #ffffff; --text: #0f172a; --text-muted: #64748b;
    --border: #e2e8f0; --glow: 0 0 15px rgba(14, 165, 233, 0.15);
  }
  body.light-mode .logo, body.light-mode .host-title { color: #0f172a; }
  body.light-mode th { background: rgba(0,0,0,0.05); color: var(--accent); }
  body.light-mode .modal-header { background: rgba(0,0,0,0.05); }
  body.light-mode .modal-body { color: #334155; }
  body.light-mode .bar-bg { background: #e2e8f0; border-color: #cbd5e1; }
  body.light-mode .nav-item:hover { background: rgba(14, 165, 233, 0.1); color: #0f172a; }
  body.light-mode .settings-input { background: #ffffff; color: #0f172a; border: 1px solid #cbd5e1; }

  body { margin: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: var(--bg); color: var(--text); display: flex; height: 100vh; overflow: hidden; transition: background 0.3s, color 0.3s; }
  
  .sidebar { width: 260px; background: var(--sidebar); border-right: 1px solid var(--border); display: flex; flex-direction: column; box-shadow: 2px 0 10px rgba(0,0,0,0.5); z-index: 10; transition: background 0.3s; }
  .logo { padding: 20px; font-size: 20px; font-weight: 800; color: #fff; border-bottom: 1px solid var(--border); letter-spacing: 1px; text-transform: uppercase; text-shadow: var(--glow); transition: color 0.3s; }
  .logo span { color: var(--accent); }
  .nav-item { padding: 16px 20px; cursor: pointer; border-left: 4px solid transparent; transition: all 0.2s; font-size: 13px; font-weight: 500; text-transform: uppercase; letter-spacing: 1px; color: var(--text-muted); }
  .nav-item:hover { background: rgba(14, 165, 233, 0.05); color: var(--text); }
  .nav-item.active { border-left-color: var(--accent); background: var(--panel); color: var(--accent); font-weight: 700; box-shadow: inset 20px 0 20px -20px rgba(14,165,233,0.3); }
  
  .main { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
  .topbar { height: 60px; background: var(--panel); border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; padding: 0 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); z-index: 5; transition: background 0.3s;}
  .host-title { font-size: 18px; font-weight: 600; color: #fff; letter-spacing: 1px; display: flex; align-items: center; gap: 15px; transition: color 0.3s;}
  .live-clock { font-family: monospace; font-size: 14px; color: var(--accent); background: rgba(14,165,233,0.1); padding: 4px 10px; border-radius: 4px; border: 1px solid rgba(14,165,233,0.3); }
  
  .top-actions { display: flex; align-items: center; }
  .btn { background: var(--panel); border: 1px solid var(--border); color: var(--text); padding: 8px 16px; border-radius: 4px; cursor: pointer; margin-left: 10px; font-size: 12px; font-weight: bold; transition: 0.2s; text-transform: uppercase; letter-spacing: 1px;}
  .btn:hover { border-color: var(--accent); box-shadow: var(--glow); color: var(--accent); }
  .btn-danger { color: var(--bad); border-color: rgba(239, 68, 68, 0.5); }
  .btn-danger:hover { background: rgba(239, 68, 68, 0.1); border-color: var(--bad); box-shadow: 0 0 15px rgba(239,68,68,0.3); color: var(--bad); }
  
  .content-area { flex: 1; padding: 25px; overflow-y: auto; }
  .tab-pane { display: none; animation: fadeIn 0.3s; }
  .tab-pane.active { display: block; }
  @keyframes fadeIn { from { opacity: 0; transform: translateY(5px); } to { opacity: 1; transform: translateY(0); } }
  
  .table-wrapper { background: var(--sidebar); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1); transition: background 0.3s;}
  table { width: 100%; border-collapse: collapse; font-size: 13px; text-align: left; }
  th, td { padding: 12px 15px; border-bottom: 1px solid var(--border); }
  th { background: rgba(0,0,0,0.3); font-weight: 700; color: var(--accent); text-transform: uppercase; font-size: 11px; letter-spacing: 1px; position: sticky; top: 0;}
  tr:hover { background: rgba(14, 165, 233, 0.05); }
  .clickable-row:hover { background: rgba(14, 165, 233, 0.1); cursor: pointer; }
  
  .badge { padding: 4px 10px; border-radius: 4px; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;}
  .badge.good { background: rgba(16, 185, 129, 0.1); color: var(--good); border: 1px solid rgba(16, 185, 129, 0.3); }
  .badge.bad { background: rgba(239, 68, 68, 0.1); color: var(--bad); border: 1px solid rgba(239, 68, 68, 0.3); }
  .badge.warn { background: rgba(245, 158, 11, 0.1); color: var(--warn); border: 1px solid rgba(245, 158, 11, 0.3); }
  .bar-bg { width: 100%; background: #1e293b; border-radius: 6px; height: 10px; margin-top: 6px; overflow: hidden; border: 1px solid #334155; transition: background 0.3s;}
  .bar-fill { height: 100%; background: var(--good); transition: width 0.4s ease-out, background 0.4s; }
  .bar-fill.med { background: var(--warn); }
  .bar-fill.high { background: var(--bad); }

  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 25px; }
  .card { background: var(--sidebar); border: 1px solid var(--border); border-radius: 8px; padding: 25px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); transition: background 0.3s;}
  .card h3 { margin: 0 0 20px 0; font-size: 14px; color: var(--accent); text-transform: uppercase; border-bottom: 1px dashed var(--border); padding-bottom: 10px; letter-spacing: 1px;}
  .kv { display: flex; justify-content: space-between; margin-bottom: 12px; font-size: 13px; align-items: center;}
  .kv-label { color: var(--text-muted); }
  .kv-val { font-weight: 600; text-align: right;}
  
  .modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.6); z-index: 1000; justify-content: center; align-items: center; backdrop-filter: blur(3px);}
  .modal { background: var(--sidebar); border: 1px solid var(--border); border-radius: 8px; width: 60%; max-height: 80vh; display: flex; flex-direction: column; box-shadow: 0 10px 40px rgba(0,0,0,0.5); transition: background 0.3s;}
  .modal-sm { width: 400px; }
  .modal-header { padding: 15px 20px; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; background: rgba(0,0,0,0.1); }
  .modal-title { font-weight: bold; color: var(--accent); font-size: 14px; text-transform: uppercase; letter-spacing: 1px;}
  .modal-close { cursor: pointer; color: var(--text-muted); font-weight: bold; font-size: 18px; }
  .modal-close:hover { color: var(--bad); }
  .modal-body { padding: 20px; overflow-y: auto; font-family: Consolas, monospace; font-size: 13px; white-space: pre-wrap; line-height: 1.6; }

  .action-btn { background: transparent; border: 1px solid var(--accent); color: var(--accent); padding: 4px 10px; border-radius: 4px; font-size: 11px; font-weight: bold; cursor: pointer; transition: 0.2s; text-transform: uppercase;}
  .action-btn:hover { background: var(--accent); color: #fff; box-shadow: var(--glow);}
  .action-btn.danger { border-color: var(--bad); color: var(--bad); }
  .action-btn.danger:hover { background: var(--bad); color: #fff; box-shadow: 0 0 10px rgba(239,68,68,0.4);}

  .settings-input { background: #0b0f19; border: 1px solid var(--border); color: var(--text); padding: 8px; border-radius: 4px; font-size: 14px; width: 100%; margin-top: 10px; box-sizing: border-box; }
  
  .loader { text-align: center; padding: 40px; color: var(--accent); font-style: italic; font-weight: bold; letter-spacing: 1px; animation: pulse 1.5s infinite;}
  @keyframes pulse { 0% { opacity: 0.5; } 50% { opacity: 1; } 100% { opacity: 0.5; } }
</style>
</head>
<body>

<div class="sidebar">
  <div class="logo">Manage &<span> Monitor</span></div>
  <div class="nav-item active" onclick="navTo(this, 'overview')">&#128200; Telemetry Overview</div>
  <div class="nav-item" onclick="navTo(this, 'activity')">&#128065; Live User Activity</div>
  <div class="nav-item" onclick="navTo(this, 'processes')">&#9881; Active Processes</div>
  <div class="nav-item" onclick="navTo(this, 'services')">&#9881; System Services</div>
  <div class="nav-item" onclick="navTo(this, 'apps')">&#128190; Installed Apps</div>
  <div class="nav-item" onclick="navTo(this, 'devicemanager')">&#128187; Device Manager</div>
  <div class="nav-item" onclick="navTo(this, 'events')">&#9888; App & System Logs</div>
  <div class="nav-item" onclick="navTo(this, 'deviceevents')">&#128268; Hardware Events</div>
  <div class="nav-item" onclick="navTo(this, 'powerevents')">&#9889; Power Events</div>
  <div class="nav-item" style="margin-top:auto; border-top:1px solid var(--border);" onclick="navTo(this, 'reports')">&#128202; Capture & Reports</div>
</div>

<div class="main">
  <div class="topbar">
    <div class="host-title">
        <span id="top-host">$($env:COMPUTERNAME)</span>
        <div class="live-clock" id="live-clock">Loading Time...</div>
    </div>
    <div class="top-actions">
      <span style="color:var(--good); font-size:12px; margin-right:15px; font-weight:bold; letter-spacing:1px; text-shadow:0 0 8px rgba(16,185,129,0.5);">&#11044; SECURE TUNNEL ONLINE</span>
      <button class="btn" onclick="openSettings()">&#9881; Settings</button>
      <button class="btn" onclick="toggleTheme()">&#127767; Theme</button>
      <button class="btn btn-danger" onclick="shutdownServer()">Disconnect & Pull Logs</button>
    </div>
  </div>

  <div class="content-area">
    
    <div id="tab-overview" class="tab-pane active">
      <div class="grid">
        <div class="card">
          <h3>Live Resource Utilization</h3>
          <div style="margin-bottom:15px;">
            <div class="kv"><span class="kv-label">CPU Core Usage</span><span class="kv-val" id="lbl-cpu">0%</span></div>
            <div class="bar-bg"><div class="bar-fill" id="bar-cpu" style="width:0%"></div></div>
          </div>
          <div style="margin-bottom:15px;">
            <div class="kv"><span class="kv-label">Physical Memory (RAM)</span><span class="kv-val" id="lbl-ram">0%</span></div>
            <div class="bar-bg"><div class="bar-fill" id="bar-ram" style="width:0%"></div></div>
          </div>
          <div style="margin-bottom:15px;">
            <div class="kv"><span class="kv-label">GPU Utilization</span><span class="kv-val" id="lbl-gpu">0%</span></div>
            <div class="bar-bg"><div class="bar-fill" id="bar-gpu" style="width:0%"></div></div>
          </div>
          <div style="margin-bottom:15px;">
            <div class="kv"><span class="kv-label">NPU Utilization</span><span class="kv-val" id="lbl-npu">0%</span></div>
            <div class="bar-bg"><div class="bar-fill" id="bar-npu" style="width:0%"></div></div>
          </div>
          <div style="margin-bottom:5px;">
            <div class="kv"><span class="kv-label">System Drive (C:)</span><span class="kv-val" id="lbl-disk">0%</span></div>
            <div class="bar-bg"><div class="bar-fill" id="bar-disk" style="width:0%"></div></div>
          </div>
        </div>
        <div class="card">
          <h3>Hardware Identity & Network</h3>
          <div class="kv"><span class="kv-label">Hostname</span><span class="kv-val" id="sys-host">Loading...</span></div>
          <div class="kv"><span class="kv-label">Manufacturer</span><span class="kv-val" id="sys-brand">Loading...</span></div>
          <div class="kv"><span class="kv-label">System Model</span><span class="kv-val" id="sys-model">Loading...</span></div>
          <div class="kv"><span class="kv-label">Processor</span><span class="kv-val" id="sys-cpu">Loading...</span></div>
          <div class="kv"><span class="kv-label">Total RAM</span><span class="kv-val" id="sys-totram">Loading...</span></div>
          <div class="kv"><span class="kv-label">BIOS Version</span><span class="kv-val" id="sys-bios">Loading...</span></div>
          <div class="kv" style="margin-top:20px; border-top:1px dashed var(--border); padding-top:15px;"><span class="kv-label">System Boot Time</span><span class="kv-val" id="sys-boot">Loading...</span></div>
          <div class="kv">
            <span class="kv-label">Hibernate</span>
            <span style="text-align: right;">
                <span class="kv-val" id="sys-hiber">Loading...</span>
                <button id="btn-hiber" class="action-btn" style="display:none; margin-left:10px;" onclick="enableHibernate()">Enable</button>
            </span>
          </div>
          <div class="kv"><span class="kv-label">VBS Status</span><span class="kv-val" id="sys-vbs" style="color:var(--good);">Loading...</span></div>
          <div class="kv"><span class="kv-label">Hyper-V</span><span class="kv-val" id="sys-hyperv">Loading...</span></div>
          <div class="kv" style="margin-top:20px; border-top:1px dashed var(--border); padding-top:15px;"><span class="kv-label">Active Adapter</span><span class="kv-val" id="sys-net" style="color:var(--accent);">Loading...</span></div>
          <div class="kv"><span class="kv-label">IPv4 Address</span><span class="kv-val" id="sys-ip">Loading...</span></div>
        </div>
      </div>
    </div>

    <div id="tab-activity" class="tab-pane">
      <div style="display:flex; justify-content:space-between; align-items:flex-end; margin-bottom: 15px;">
          <h3 style="color:var(--accent); font-size:14px; text-transform:uppercase; margin:0; letter-spacing:1px;">Active Foreground Windows (User Screen)</h3>
      </div>
      <div class="table-wrapper" style="margin-bottom: 30px;">
        <table id="tbl-activewindows">
          <thead><tr><th>Application</th><th>PID</th><th>Window Title (Content Focus)</th><th>Actions</th></tr></thead>
          <tbody><tr class="loader"><td colspan="4">Awaiting Manual Fetch...</td></tr></tbody>
        </table>
      </div>

      <div style="display:flex; justify-content:space-between; align-items:flex-end; margin-bottom: 15px;">
          <h3 style="color:var(--accent); font-size:14px; text-transform:uppercase; margin:0; letter-spacing:1px;">Recently Launched Processes (Audit Trail)</h3>
      </div>
      <div class="table-wrapper">
        <table id="tbl-recentprocs">
          <thead><tr><th>Process Name</th><th>PID</th><th>Launch Time</th></tr></thead>
          <tbody><tr class="loader"><td colspan="3">Awaiting Manual Fetch...</td></tr></tbody>
        </table>
      </div>
    </div>

    <div id="tab-processes" class="tab-pane">
      <div class="table-wrapper">
        <table id="tbl-procs">
          <thead><tr><th>Process Name</th><th>PID</th><th>CPU (%)</th><th>Memory (MB)</th><th>Actions</th></tr></thead>
          <tbody><tr class="loader"><td colspan="5">Awaiting Manual Fetch...</td></tr></tbody>
        </table>
      </div>
    </div>

    <div id="tab-services" class="tab-pane">
      <div class="table-wrapper">
        <table id="tbl-services">
          <thead><tr><th>Display Name</th><th>Internal Name</th><th>Status</th><th>Startup Type</th><th>Actions</th></tr></thead>
          <tbody><tr class="loader"><td colspan="5">Awaiting Manual Fetch...</td></tr></tbody>
        </table>
      </div>
    </div>

    <div id="tab-apps" class="tab-pane">
      <div class="table-wrapper">
        <table id="tbl-apps">
          <thead><tr><th>Application Name</th><th>Publisher</th><th>Version</th></tr></thead>
          <tbody><tr class="loader"><td colspan="3">Awaiting Manual Fetch...</td></tr></tbody>
        </table>
      </div>
    </div>

    <div id="tab-devicemanager" class="tab-pane">
      <div class="table-wrapper">
        <table id="tbl-hardware">
          <thead><tr><th>Device Name</th><th>Manufacturer</th><th>Device ID</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody><tr class="loader"><td colspan="5">Awaiting Manual Fetch...</td></tr></tbody>
        </table>
      </div>
    </div>

    <div id="tab-events" class="tab-pane">
      <div class="table-wrapper">
        <table id="tbl-events">
          <thead><tr><th>Event Time</th><th>Log</th><th>Provider</th><th>Description Summary</th><th>ID</th><th>Level</th></tr></thead>
          <tbody><tr class="loader"><td colspan="6">Awaiting Manual Fetch...</td></tr></tbody>
        </table>
      </div>
    </div>

    <div id="tab-deviceevents" class="tab-pane">
      <div class="table-wrapper">
        <table id="tbl-deviceevents">
          <thead><tr><th>Event Time</th><th>Provider</th><th>Hardware Event Summary</th><th>ID</th><th>Level</th></tr></thead>
          <tbody><tr class="loader"><td colspan="5">Awaiting Manual Fetch...</td></tr></tbody>
        </table>
      </div>
    </div>

    <div id="tab-powerevents" class="tab-pane">
      <div class="table-wrapper">
        <table id="tbl-powerevents">
          <thead><tr><th>Event Time</th><th>Provider</th><th>Power Event Summary</th><th>ID</th><th>Level</th></tr></thead>
          <tbody><tr class="loader"><td colspan="5">Awaiting Manual Fetch...</td></tr></tbody>
        </table>
      </div>
    </div>

    <div id="tab-reports" class="tab-pane">
      <div class="card" style="text-align:center; padding: 50px 20px; max-width:800px; margin:0 auto;">
        
        <h2 id="report-title-text" style="color:var(--accent); text-transform:uppercase; margin-bottom:10px; letter-spacing:2px;">GENERATE 2-DAY MATRIX</h2>
        <p style="color:var(--text-muted); margin-bottom:30px; margin-left:auto; margin-right:auto;">
          This will compile a deep <b>Day-by-Day</b> historical scan of application crashes, network drops, unexpected shutdowns, BSODs, IPv4 identity, and detailed diagnostic event messages into a comprehensive CSV matrix and offline HTML dashboard. Live metrics will be mirrored on each row.
        </p>
        <button class="btn" style="font-size:16px; padding:15px 30px;" onclick="generateCaptureLog()">Generate Capture CSV + HTML Dashboard Now</button>
        <div id="capture-status" style="margin-top:20px; font-weight:bold; color:var(--good);"></div>

        <div style="margin-top: 40px; padding-top: 30px; border-top: 1px dashed var(--border);">
            <h3 style="color:var(--accent); font-size:14px; text-transform:uppercase; margin-bottom:15px;">Advanced Actions: Group Policy</h3>
            <p style="color:var(--text-muted); font-size:12px; margin-bottom:15px;">Manually check or force background Group Policy updates.</p>
            <div class="kv" style="max-width: 400px; margin: 0 auto 15px auto;">
                <span class="kv-label">Last GPUpdate:</span>
                <span class="kv-val" id="sys-gpupdate" style="color:var(--warn);">Awaiting Manual Check...</span>
            </div>
            <div style="display:flex; justify-content:center; gap:10px; align-items:center;">
                <button class="btn action-btn" style="padding:10px 15px; margin:0;" onclick="checkGPUpdate()">&#128269; Check Status</button>
                <button class="btn action-btn danger" style="padding:10px 15px; margin:0;" onclick="triggerGPUpdate()">&#9889; Force Update</button>
            </div>
        </div>

        <div style="margin-top: 40px; padding-top: 30px; border-top: 1px dashed var(--border);">
            <h3 style="color:var(--accent); font-size:14px; text-transform:uppercase; margin-bottom:15px;">Locally Stored Logs (Remote Machine)</h3>
            <p style="color:var(--text-muted); font-size:12px; margin-bottom:15px;">Select an existing log to launch directly on the user's screen (Excel or Browser).</p>
            <div style="display:flex; justify-content:center; gap:10px; align-items:center;">
                <select id="log-selector" class="settings-input" style="width:350px; margin-top:0; padding:10px;"></select>
                <button class="btn action-btn" style="padding:10px 15px; margin:0;" onclick="openSelectedLog()">&#128196; Open Report</button>
            </div>
            <div id="open-status" style="margin-top:15px; font-weight:bold; font-size:12px;"></div>
        </div>

      </div>
    </div>

  </div>
</div>

<div class="modal-overlay" id="event-modal" onclick="closeModal(event)">
  <div class="modal" onclick="event.stopPropagation()">
    <div class="modal-header">
      <div class="modal-title" id="modal-title">Event Properties</div>
      <div class="modal-close" onclick="document.getElementById('event-modal').style.display='none'">&#10005;</div>
    </div>
    <div class="modal-body" id="modal-body">Loading...</div>
  </div>
</div>

<div class="modal-overlay" id="settings-modal" onclick="closeModal(event)">
  <div class="modal modal-sm" onclick="event.stopPropagation()">
    <div class="modal-header">
      <div class="modal-title">Dashboard Settings</div>
      <div class="modal-close" onclick="document.getElementById('settings-modal').style.display='none'">&#10005;</div>
    </div>
    <div class="modal-body" style="font-family:'Segoe UI', sans-serif;">
      
      <label for="fetch-mode-input" style="font-weight:600; color:var(--text); text-transform:uppercase; font-size:12px; letter-spacing:1px;">Data Fetch Mode:</label><br>
      <select id="fetch-mode-input" class="settings-input" style="margin-bottom:20px;">
          <option value="manual">Manual (Trigger to Fetch)</option>
          <option value="auto">Automatic (Fetch on Tab Open)</option>
      </select>
      
      <label for="days-input" style="font-weight:600; color:var(--text); text-transform:uppercase; font-size:12px; letter-spacing:1px;">Telemetry Lookback Period (Days):</label><br>
      <input type="number" id="days-input" class="settings-input" value="2" min="1" max="365">
      
      <p style="color:var(--text-muted); font-size:12px; margin-top:15px; padding-top:10px; border-top:1px dashed var(--border);">
        Adjusting these parameters allows you to control the load placed on the remote machine when querying WMI and Event Logs.
      </p>
      <button class="btn action-btn" style="margin-left:0; margin-top:10px; padding:8px 16px; font-size:12px;" onclick="saveSettings()">Save & Apply</button>
    </div>
  </div>
</div>

<script>
  let overviewInterval;
  let telemetryDays = 2;
  let autoFetchData = false; 
  
  function toggleTheme() { document.body.classList.toggle('light-mode'); }
  
  setInterval(() => {
      const ptTime = new Date().toLocaleString("en-US", {timeZone: "America/Los_Angeles", hour: '2-digit', minute:'2-digit', second:'2-digit', hour12: true});
      const ptDate = new Date().toLocaleString("en-US", {timeZone: "America/Los_Angeles", month: 'short', day:'numeric', year:'numeric'});
      document.getElementById('live-clock').innerText = ptDate + " | " + ptTime + " PT";
  }, 1000);

  function switchTab(tabId) {
    document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(el => el.classList.remove('active'));
    document.getElementById('tab-' + tabId).classList.add('active');
  }

  function navTo(el, tabId) {
      document.querySelectorAll('.nav-item').forEach(item => item.classList.remove('active'));
      el.classList.add('active');
      
      document.querySelectorAll('.tab-pane').forEach(pane => pane.classList.remove('active'));
      document.getElementById('tab-' + tabId).classList.add('active');
      
      if (tabId === 'overview') return;
      if (tabId === 'reports') { loadLogList(); return; }

      if (autoFetchData) {
          triggerLoad(tabId);
      } else {
          promptFetch(tabId);
      }
  }

  function promptFetch(tabId) {
      let tbodyId, btnAction, colSpan, txt;
      if(tabId === 'activity') {
          document.querySelector('#tbl-activewindows tbody').innerHTML = '<tr><td colspan="4" style="text-align:center; padding:40px;"><button class="btn action-btn" style="font-size:14px; padding:10px 20px;" onclick="loadActivity()">Fetch Live Activity Now</button></td></tr>';
          document.querySelector('#tbl-recentprocs tbody').innerHTML = '<tr><td colspan="3" style="text-align:center; padding:40px; color:var(--text-muted); font-style:italic;">Awaiting Manual Fetch...</td></tr>';
          return;
      }

      if(tabId === 'processes') { tbodyId = '#tbl-procs tbody'; btnAction = 'loadProcesses()'; colSpan=5; txt='Processes'; }
      if(tabId === 'services') { tbodyId = '#tbl-services tbody'; btnAction = 'loadServices()'; colSpan=5; txt='Services'; }
      if(tabId === 'apps') { tbodyId = '#tbl-apps tbody'; btnAction = 'loadApps()'; colSpan=3; txt='Installed Apps'; }
      if(tabId === 'devicemanager') { tbodyId = '#tbl-hardware tbody'; btnAction = 'loadHardware()'; colSpan=5; txt='Device Manager'; }
      if(tabId === 'events') { tbodyId = '#tbl-events tbody'; btnAction = 'loadEvents()'; colSpan=6; txt='App & System Logs'; }
      if(tabId === 'deviceevents') { tbodyId = '#tbl-deviceevents tbody'; btnAction = 'loadDeviceEvents()'; colSpan=5; txt='Hardware Events'; }
      if(tabId === 'powerevents') { tbodyId = '#tbl-powerevents tbody'; btnAction = 'loadPowerEvents()'; colSpan=5; txt='Power Events'; }

      if(tbodyId) {
          document.querySelector(tbodyId).innerHTML = '<tr><td colspan="' + colSpan + '" style="text-align:center; padding:40px;"><button class="btn action-btn" style="font-size:14px; padding:10px 20px;" onclick="' + btnAction + '">Fetch ' + txt + ' Now</button></td></tr>';
      }
  }

  function triggerLoad(tabId) {
      if(tabId === 'activity') loadActivity();
      if(tabId === 'processes') loadProcesses();
      if(tabId === 'services') loadServices();
      if(tabId === 'apps') loadApps();
      if(tabId === 'devicemanager') loadHardware();
      if(tabId === 'events') loadEvents();
      if(tabId === 'deviceevents') loadDeviceEvents();
      if(tabId === 'powerevents') loadPowerEvents();
  }

  function closeModal(e) { 
      if(e.target.id === 'event-modal') { document.getElementById('event-modal').style.display = 'none'; } 
      if(e.target.id === 'settings-modal') { document.getElementById('settings-modal').style.display = 'none'; } 
  }
  
  function showEventDetails(title, bodyText) {
      document.getElementById('modal-title').innerText = title;
      document.getElementById('modal-body').innerText = bodyText;
      document.getElementById('event-modal').style.display = 'flex';
  }

  function openSettings() {
      document.getElementById('days-input').value = telemetryDays;
      document.getElementById('fetch-mode-input').value = autoFetchData ? 'auto' : 'manual';
      document.getElementById('settings-modal').style.display = 'flex';
  }

  function saveSettings() {
      let val = parseInt(document.getElementById('days-input').value);
      if(val >= 1 && val <= 365) {
          telemetryDays = val;
          autoFetchData = (document.getElementById('fetch-mode-input').value === 'auto');
          
          document.getElementById('settings-modal').style.display = 'none';
          document.getElementById('report-title-text').innerText = "GENERATE " + telemetryDays + "-DAY MATRIX";
          
          const activeTab = document.querySelector('.tab-pane.active').id.replace('tab-', '');
          if (activeTab !== 'overview' && activeTab !== 'reports') {
             if(autoFetchData) triggerLoad(activeTab); else promptFetch(activeTab);
          }
      } else {
          alert("Please enter a valid number of days (1-365).");
      }
  }

  async function shutdownServer() {
      if (confirm("Disconnect session? Any newly generated logs will be pulled to your local C:\\Temp automatically.")) {
          try { 
              await fetch('/api/shutdown'); 
          } catch(e) {
              console.log("Server stopped.");
          }
          document.body.innerHTML = "<div style='display:flex; justify-content:center; align-items:center; height:100vh; font-size:24px; color:#0ea5e9; text-shadow:0 0 15px rgba(14,165,233,0.5); font-weight:bold; letter-spacing:2px;'>SESSION SECURELY TERMINATED. YOU CAN CLOSE THIS TAB.</div>";
      }
  }

  async function killProc(targetPid, name) {
      if (confirm("Force kill process: " + name + " (PID: " + targetPid + ")?")) {
          try {
              const res = await fetch('/api/action/kill?pid=' + targetPid + '&name=' + encodeURIComponent(name), {method: 'POST'});
              const data = await res.json();
              
              alert("Execution Result:\n\n" + data.output);
              
              setTimeout(() => {
                  const activeTab = document.querySelector('.tab-pane.active').id.replace('tab-', '');
                  if(activeTab === 'activity') { loadActivity(); } else { loadProcesses(); }
              }, 2000);
          } catch (e) {
              alert("Failed to communicate with the backend server.");
          }
      }
  }

  async function svcAction(name, action) {
      if (confirm(action.toUpperCase() + " service: " + name + "?")) {
          await fetch('/api/action/service?name=' + name + '&action=' + action, {method: 'POST'});
          loadServices();
      }
  }
  
  async function removeDevice(id) {
      if (confirm("WARNING: Removing devices can cause system instability or re-detection loops. Proceed?")) {
          try {
              await fetch('/api/action/removedevice?id=' + encodeURIComponent(id), {method: 'POST'});
              loadHardware();
          } catch(e) {
              alert("Failed to communicate with the backend server.");
          }
      }
  }
  
  async function enableHibernate() {
      if (confirm("Enable system Hibernate and add it to the Windows Power Menu?")) {
          document.getElementById('sys-hiber').innerText = "Enabling...";
          document.getElementById('btn-hiber').style.display = "none";
          try {
              await fetch('/api/action/hibernate', {method: 'POST'});
              fetchOverview();
          } catch(e) {
              alert("Failed to communicate with the backend server.");
          }
      }
  }

  async function checkGPUpdate() {
      document.getElementById('sys-gpupdate').innerText = "Querying remote machine...";
      document.getElementById('sys-gpupdate').style.color = "var(--warn)";
      try {
          const res = await fetch('/api/gpupdate');
          const data = await res.json();
          document.getElementById('sys-gpupdate').innerText = data.LastGP;
          document.getElementById('sys-gpupdate').style.color = "var(--good)";
      } catch(e) {
          document.getElementById('sys-gpupdate').innerText = "Failed to query.";
          document.getElementById('sys-gpupdate').style.color = "var(--bad)";
      }
  }

  async function triggerGPUpdate() {
      document.getElementById('sys-gpupdate').innerText = "Running GPUpdate /force...";
      document.getElementById('sys-gpupdate').style.color = "var(--warn)";
      try {
          await fetch('/api/action/gpupdate', {method: 'POST'});
          document.getElementById('sys-gpupdate').innerText = "Command Sent. Check status again in ~30 seconds.";
      } catch(e) {}
  }

  async function generateCaptureLog() {
      document.getElementById('capture-status').innerText = "Scanning " + telemetryDays + " days of Event Logs. This may take 30-60 seconds...";
      document.getElementById('capture-status').style.color = "var(--warn)";
      try {
          const res = await fetch('/api/capture?days=' + telemetryDays, {method: 'POST'});
          const data = await res.json();
          let captureMsg = "Success! CSV saved at: " + data.path;
          if (data.htmlPath) { captureMsg += " | HTML dashboard saved at: " + data.htmlPath; }
          document.getElementById('capture-status').innerText = captureMsg;
          document.getElementById('capture-status').style.color = "var(--good)";
          loadLogList();
      } catch (e) {
          document.getElementById('capture-status').innerText = "Failed to generate log. Check console.";
          document.getElementById('capture-status').style.color = "var(--bad)";
      }
  }

  async function loadLogList() {
      try {
          const res = await fetch('/api/logs');
          const logs = await res.json();
          const sel = document.getElementById('log-selector');
          sel.innerHTML = '';
          if(!logs || logs.length === 0) {
              sel.innerHTML = '<option value="">No logs found in remote C:\\Temp</option>';
          } else {
              logs.reverse().forEach(l => {
                  const opt = document.createElement('option');
                  opt.value = l.Name;
                  opt.innerText = l.Name;
                  sel.appendChild(opt);
              });
          }
      } catch(e) {}
  }

  async function openSelectedLog() {
      const sel = document.getElementById('log-selector').value;
      if(!sel) return;
      
      let isHtml = sel.toLowerCase().endsWith('.html');
      let actionText = isHtml ? "Opening HTML Dashboard in default browser..." : "Triggering Excel in remote session...";
      
      document.getElementById('open-status').innerText = actionText;
      document.getElementById('open-status').style.color = "var(--warn)";
      try {
          await fetch('/api/action/openlog?file=' + encodeURIComponent(sel), {method: 'POST'});
          document.getElementById('open-status').innerText = "Successfully launched " + sel;
          document.getElementById('open-status').style.color = "var(--good)";
      } catch(e) {
          document.getElementById('open-status').innerText = "Failed to launch.";
          document.getElementById('open-status').style.color = "var(--bad)";
      }
  }

  async function fetchOverview() {
      try {
          const res = await fetch('/api/overview');
          const data = await res.json();
          
          document.getElementById('sys-host').innerText = data.Sys.Host;
          document.getElementById('sys-brand').innerText = data.Sys.Brand;
          document.getElementById('sys-model').innerText = data.Sys.Model;
          document.getElementById('sys-cpu').innerText = data.Sys.CPUName;
          document.getElementById('sys-totram').innerText = data.Sys.TotRAM;
          document.getElementById('sys-bios').innerText = data.Sys.BIOS;
          document.getElementById('sys-boot').innerText = data.Sys.BootTime;
          document.getElementById('sys-hiber').innerText = data.Sys.Hibernate;
          if (data.Sys.Hibernate === 'Disabled') {
              document.getElementById('btn-hiber').style.display = 'inline-block';
          } else {
              document.getElementById('btn-hiber').style.display = 'none';
          }
          document.getElementById('sys-vbs').innerText = data.Sys.VBS;
          document.getElementById('sys-hyperv').innerText = data.Sys.HyperV;
          document.getElementById('sys-net').innerText = data.Sys.Net;
          document.getElementById('sys-ip').innerText = data.Sys.IP;

          document.getElementById('lbl-cpu').innerText = data.Perf.CPU + "%";
          document.getElementById('bar-cpu').style.width = data.Perf.CPU + "%";
          document.getElementById('bar-cpu').className = "bar-fill " + (data.Perf.CPU > 85 ? 'high' : (data.Perf.CPU > 60 ? 'med' : ''));

          document.getElementById('lbl-ram').innerText = data.Perf.RAM + "%";
          document.getElementById('bar-ram').style.width = data.Perf.RAM + "%";
          document.getElementById('bar-ram').className = "bar-fill " + (data.Perf.RAM > 85 ? 'high' : (data.Perf.RAM > 60 ? 'med' : 'med'));

          document.getElementById('lbl-gpu').innerText = data.Perf.GPU + "%";
          document.getElementById('bar-gpu').style.width = data.Perf.GPU + "%";
          document.getElementById('bar-gpu').className = "bar-fill " + (data.Perf.GPU > 85 ? 'high' : (data.Perf.GPU > 60 ? 'med' : 'med'));

          document.getElementById('lbl-npu').innerText = data.Perf.NPU + "%";
          document.getElementById('bar-npu').style.width = data.Perf.NPU + "%";
          document.getElementById('bar-npu').className = "bar-fill " + (data.Perf.NPU > 85 ? 'high' : (data.Perf.NPU > 60 ? 'med' : 'med'));

          document.getElementById('lbl-disk').innerText = data.Perf.DiskPct + "% (" + data.Perf.DiskFree + " Free)";
          document.getElementById('bar-disk').style.width = data.Perf.DiskPct + "%";
          document.getElementById('bar-disk').className = "bar-fill " + (data.Perf.DiskPct > 90 ? 'high' : (data.Perf.DiskPct > 75 ? 'med' : 'med'));
      } catch (e) {}
  }

  async function loadActivity() {
      document.querySelector('#tbl-activewindows tbody').innerHTML = '<tr class="loader"><td colspan="4">Polling Session Graphics...</td></tr>';
      document.querySelector('#tbl-recentprocs tbody').innerHTML = '<tr class="loader"><td colspan="3">Querying Launch History...</td></tr>';
      try {
          const res = await fetch('/api/activity');
          const data = await res.json();
          
          const t1 = document.querySelector('#tbl-activewindows tbody');
          t1.innerHTML = '';
          if(data.ActiveWindows.length === 0) {
              t1.innerHTML = '<tr><td colspan="4" style="text-align:center; color:var(--text-muted);">No interactive windows detected. User may be on Lock Screen.</td></tr>';
          } else {
              data.ActiveWindows.forEach(w => {
                  const tr = document.createElement('tr');
                  tr.innerHTML = "<td><b>" + w.Name + "</b></td><td>" + w.PID + "</td><td style='color:var(--accent);'>" + w.Title + "</td>" +
                                 "<td><button class='action-btn danger' onclick=\"killProc('" + w.PID + "','" + w.Name + "')\">Close Window</button></td>";
                  t1.appendChild(tr);
              });
          }

          const t2 = document.querySelector('#tbl-recentprocs tbody');
          t2.innerHTML = '';
          data.RecentProcesses.forEach(p => {
              const tr = document.createElement('tr');
              tr.innerHTML = "<td>" + p.Name + "</td><td>" + p.PID + "</td><td style='color:var(--good);'>" + p.Time + "</td>";
              t2.appendChild(tr);
          });
      } catch (e) {}
  }

  async function loadProcesses() {
      document.querySelector('#tbl-procs tbody').innerHTML = '<tr class="loader"><td colspan="5">Scanning Active Processes...</td></tr>';
      try {
          const res = await fetch('/api/processes');
          const data = await res.json();
          const tbody = document.querySelector('#tbl-procs tbody');
          tbody.innerHTML = '';
          data.forEach(p => {
              const tr = document.createElement('tr');
              tr.innerHTML = "<td>" + p.Name + "</td><td>" + p.PID + "</td><td style='color:var(--accent); font-weight:bold;'>" + p.CPU + "%</td><td>" + p.RAM + "</td>" +
                             "<td><button class='action-btn danger' onclick=\"killProc('" + p.PID + "','" + p.Name + "')\">Kill</button></td>";
              tbody.appendChild(tr);
          });
      } catch (e) {}
  }

  async function loadServices() {
      document.querySelector('#tbl-services tbody').innerHTML = '<tr class="loader"><td colspan="5">Fetching Services...</td></tr>';
      try {
          const res = await fetch('/api/services');
          const data = await res.json();
          const tbody = document.querySelector('#tbl-services tbody');
          tbody.innerHTML = '';
          data.forEach(s => {
              const badgeClass = s.Status === 'Running' ? 'good' : (s.Status === 'Stopped' ? 'bad' : 'warn');
              const tr = document.createElement('tr');
              tr.innerHTML = "<td>" + s.DisplayName + "</td><td>" + s.Name + "</td>" +
                             "<td><span class='badge " + badgeClass + "'>" + s.Status + "</span></td><td>" + s.StartType + "</td>" +
                             "<td><button class='action-btn' onclick=\"svcAction('" + s.Name + "','start')\">Start</button> " +
                             "<button class='action-btn danger' onclick=\"svcAction('" + s.Name + "','stop')\">Stop</button></td>";
              tbody.appendChild(tr);
          });
      } catch (e) {}
  }

  async function loadApps() {
      document.querySelector('#tbl-apps tbody').innerHTML = '<tr class="loader"><td colspan="3">Querying Registry for Installed Software...</td></tr>';
      try {
          const res = await fetch('/api/apps');
          const data = await res.json();
          const tbody = document.querySelector('#tbl-apps tbody');
          tbody.innerHTML = '';
          data.forEach(a => {
              const tr = document.createElement('tr');
              tr.innerHTML = "<td>" + a.Name + "</td><td>" + a.Publisher + "</td><td>" + a.Version + "</td>";
              tbody.appendChild(tr);
          });
      } catch (e) {}
  }

  async function loadHardware() {
      document.querySelector('#tbl-hardware tbody').innerHTML = '<tr class="loader"><td colspan="5">Querying Device Manager...</td></tr>';
      try {
          const res = await fetch('/api/hardware');
          const data = await res.json();
          const tbody = document.querySelector('#tbl-hardware tbody');
          tbody.innerHTML = '';
          data.forEach(h => {
              const badgeClass = h.Status === 'OK' ? 'good' : 'bad';
              const actionBtn = h.Status !== 'OK' ? " <button class='action-btn danger' style='margin-left:10px;' onclick=\"removeDevice('" + encodeURIComponent(h.DeviceID) + "')\">Remove</button>" : "";
              const tr = document.createElement('tr');
              tr.innerHTML = "<td>" + h.Name + "</td><td>" + h.Manufacturer + "</td><td>" + h.DeviceID + "</td>" +
                             "<td><span class='badge " + badgeClass + "'>" + h.Status + "</span>" + actionBtn + "</td>";
              tbody.appendChild(tr);
          });
      } catch (e) {}
  }

  async function loadEvents() {
      document.querySelector('#tbl-events tbody').innerHTML = '<tr class="loader"><td colspan="6">Pulling System & Application Error Logs (' + telemetryDays + ' days)...</td></tr>';
      try {
          const res = await fetch('/api/events?days=' + telemetryDays);
          const data = await res.json();
          const tbody = document.querySelector('#tbl-events tbody');
          tbody.innerHTML = '';
          data.forEach(e => {
              const badgeClass = e.Level.includes('Error') || e.Level.includes('Critical') ? 'bad' : 'warn';
              const tr = document.createElement('tr');
              tr.className = 'clickable-row';
              const rawMsg = encodeURIComponent(e.RawMessage);
              tr.onclick = () => showEventDetails(e.Provider + " (ID: " + e.Id + ")", decodeURIComponent(rawMsg));
              tr.innerHTML = "<td>" + e.Time + "</td><td>" + e.Log + "</td><td>" + e.Provider + "</td>" +
                             "<td style='max-width:300px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;'>" + e.ShortDesc + "</td>" +
                             "<td>" + e.Id + "</td><td><span class='badge " + badgeClass + "'>" + e.Level + "</span></td>";
              tbody.appendChild(tr);
          });
      } catch (e) {}
  }

  async function loadDeviceEvents() {
      document.querySelector('#tbl-deviceevents tbody').innerHTML = '<tr class="loader"><td colspan="5">Pulling Kernel-PnP Logs (' + telemetryDays + ' days)...</td></tr>';
      try {
          const res = await fetch('/api/deviceevents?days=' + telemetryDays);
          const data = await res.json();
          const tbody = document.querySelector('#tbl-deviceevents tbody');
          tbody.innerHTML = '';
          data.forEach(e => {
              const badgeClass = e.Level.includes('Error') ? 'bad' : (e.Level.includes('Warning') ? 'warn' : 'good');
              const tr = document.createElement('tr');
              tr.className = 'clickable-row';
              const rawMsg = encodeURIComponent(e.RawMessage);
              tr.onclick = () => showEventDetails(e.Provider + " (ID: " + e.Id + ")", decodeURIComponent(rawMsg));
              tr.innerHTML = "<td>" + e.Time + "</td><td>" + e.Provider + "</td>" +
                             "<td style='max-width:400px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;'>" + e.ShortDesc + "</td>" +
                             "<td>" + e.Id + "</td><td><span class='badge " + badgeClass + "'>" + e.Level + "</span></td>";
              tbody.appendChild(tr);
          });
      } catch (e) {}
  }

  async function loadPowerEvents() {
      document.querySelector('#tbl-powerevents tbody').innerHTML = '<tr class="loader"><td colspan="5">Pulling Power & Shutdown Logs (' + telemetryDays + ' days)...</td></tr>';
      try {
          const res = await fetch('/api/powerevents?days=' + telemetryDays);
          const data = await res.json();
          const tbody = document.querySelector('#tbl-powerevents tbody');
          tbody.innerHTML = '';
          data.forEach(e => {
              const badgeClass = e.Level.includes('Error') || e.Level.includes('Critical') ? 'bad' : 'warn';
              const tr = document.createElement('tr');
              tr.className = 'clickable-row';
              const rawMsg = encodeURIComponent(e.RawMessage);
              tr.onclick = () => showEventDetails(e.Provider + " (ID: " + e.Id + ")", decodeURIComponent(rawMsg));
              tr.innerHTML = "<td>" + e.Time + "</td><td>" + e.Provider + "</td>" +
                             "<td style='max-width:400px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;'>" + e.ShortDesc + "</td>" +
                             "<td>" + e.Id + "</td><td><span class='badge " + badgeClass + "'>" + e.Level + "</span></td>";
              tbody.appendChild(tr);
          });
      } catch (e) {}
  }

  // Initial Boot Sequence
  fetchOverview();
  overviewInterval = setInterval(fetchOverview, 3000);
</script>
</body>
</html>
"@

# ==========================================
# START LOCAL SERVER (DYNAMIC PORT & URL ACL)
# ==========================================
Add-Type -AssemblyName System

Write-Host "[Remote] Clearing orphaned dashboard processes..." -ForegroundColor Cyan
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match "IT_HealthCheck.ps1" -and $_.ProcessId -ne $PID } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

$listener = $null
try {
    $listener = [System.Net.HttpListener]::new()
} catch {
    Write-Host "`n[WARNING] HTTP Service locked. Attempting native recovery..." -ForegroundColor Yellow
    cmd.exe /c "net start http" | Out-Null
    Start-Sleep -Seconds 2
    try { $listener = [System.Net.HttpListener]::new() } catch {}
}

if ($null -eq $listener) {
    Write-Host "`nCRITICAL SERVER ERROR: The remote Windows HTTP.sys service is deadlocked.`nPlease reboot the remote machine ($env:COMPUTERNAME)." -ForegroundColor Red
    exit
}

$assignedPort = 0
$aclUrl = ""; $browserUrl = ""

foreach ($p in 15500..15999) {
    $testWildcardUrl = "http://+:$p/"
    cmd.exe /c "netsh http add urlacl url=$testWildcardUrl user=`"Everyone`"" | Out-Null
    try {
        $listener.Prefixes.Clear()
        $listener.Prefixes.Add($testWildcardUrl)
        $listener.Start()
        $assignedPort = $p; $aclUrl = $testWildcardUrl; $browserUrl = "http://127.0.0.1:$p/"
        break
    } catch { 
        cmd.exe /c "netsh http delete urlacl url=$testWildcardUrl" | Out-Null 
    }
}

if (-not $listener.IsListening) { 
    Write-Host "`nCRITICAL SERVER ERROR: All ports blocked." -ForegroundColor Red
    exit 
}

Write-Host "=========================================================" -ForegroundColor Green
Write-Host " MANAGE AND MONITOR SPA SERVER RUNNING ON PORT $assignedPort" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green

if ($activeUser = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName) {
    Invoke-Interactive -Execute "cmd.exe" -Argument "/c start `"`" `"$browserUrl`"" | Out-Null
}

$cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

if ($isLocal) {
    Write-Host " [i] Press 'Q' in this console at any time to locally terminate the session and pull logs." -ForegroundColor DarkGray
} else {
    Write-Host " [i] Press 'Ctrl + C' in this console at any time to safely drop the remote connection and pull logs." -ForegroundColor DarkGray
}

# --- GLOBAL SESSION CACHE ---
$sessionCache = @{
    Processes = $null
    Services = $null
    Apps = $null
    Hardware = $null
}

try {
    $stopReq = $false
    while ($listener.IsListening) {
        
        $asyncResult = $listener.BeginGetContext($null, $null)
        
        while (-not $asyncResult.AsyncWaitHandle.WaitOne(200)) {
            try {
                if ([System.Console]::KeyAvailable) {
                    $key = [System.Console]::ReadKey($true)
                    if ($key.Key -eq 'Q' -or $key.Key -eq 'q') { $stopReq = $true }
                }
            } catch { } 

            if ($stopReq) { break }
        }

        if ($stopReq) {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] Local termination key ('Q') pressed. Initiating shutdown sequence..." -ForegroundColor Yellow
            $listener.Stop()
            break
        }

        if (-not $listener.IsListening) { break }

        $context = $null
        try { $context = $listener.EndGetContext($asyncResult) } catch { continue }

        $request = $context.Request
        $response = $context.Response
        $buffer = $null

        if ($request.Url.AbsolutePath -notmatch "/api/overview|/api/activity") {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] API Request Received: $($request.Url.AbsolutePath)" -ForegroundColor DarkGray
        }

        $pendingAction = $null
        $pendingPid = $null
        $pendingName = $null

        try {
            if ($request.Url.AbsolutePath -eq "/") {
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlPayload)
                $response.ContentType = "text/html"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/overview") {
                
                $cpuLoad = [math]::Round((Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property LoadPercentage -Average).Average, 0)
                $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                
                $totRamGb = if ($cs.TotalPhysicalMemory -gt 0) { [math]::Round(($cs.TotalPhysicalMemory / 1GB), 1) } else { 0 }
                $ramPct = if ($cs.TotalPhysicalMemory -gt 0) { [math]::Round((($cs.TotalPhysicalMemory - $osInfo.FreePhysicalMemory*1024) / $cs.TotalPhysicalMemory) * 100, 0) } else { 0 }
                
                $cDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
                $diskPct = if ($cDrive.Size -gt 0) { [math]::Round((($cDrive.Size - $cDrive.FreeSpace) / $cDrive.Size) * 100, 0) } else { 0 }
                $diskFree = "$([math]::Round($cDrive.FreeSpace / 1GB, 1)) GB"
                
                $gpuLoad = 0; $npuLoad = 0
                try { $gpuWmi = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction SilentlyContinue
                      if ($gpuWmi) { $gpuLoad = [math]::Round(($gpuWmi | Measure-Object -Property UtilizationPercentage -Average).Average, 0) } } catch {}
                try { $npuWmi = Get-CimInstance Win32_PerfFormattedData_NeuralProcessingUnit_NPUUtilization -ErrorAction SilentlyContinue
                      if ($npuWmi) { $npuLoad = [math]::Round(($npuWmi | Measure-Object -Property UtilizationPercentage -Average).Average, 0) } } catch {}

                $netStats = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | Select-Object -First 1
                $netStr = "Disconnected"
                $ipAddr = "Unknown"
                
                if ($netStats) {
                    $ipAddr = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $netStats.Name -ErrorAction SilentlyContinue).IPAddress -join ", "
                    $speed = $netStats.LinkSpeed
                    if ($netStats.MediaType -match "802.11|WiFi|Wi-Fi") {
                        $wlanData = netsh wlan show interfaces | Out-String
                        if ($wlanData -match 'SSID\s+:\s+([^\r\n]+)') { 
                            $netStr = "$($netStats.InterfaceDescription) (SSID: $($matches[1].Trim()) | Speed: $speed)" 
                        } else { $netStr = "$($netStats.InterfaceDescription) (Speed: $speed)" }
                    } else { $netStr = "$($netStats.InterfaceDescription) (Speed: $speed)" }
                }

                $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
                $biosDate = if ($null -ne $bios.ReleaseDate) { $bios.ReleaseDate.ToString("M/d/yyyy") } else { "" }
                $biosName = if ($bios.Name) { $bios.Name } else { "Unknown" }
                $biosStr = if ($biosDate) { "$biosName, $biosDate" } else { "$biosName" }

                $dg = Get-CimInstance -Namespace "root\Microsoft\Windows\DeviceGuard" -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
                $vbsStat = "Disabled/Unsupported"
                if ($dg) {
                    if ($dg.VirtualizationBasedSecurityStatus -eq 2) { $vbsStat = "Running" }
                    elseif ($dg.VirtualizationBasedSecurityStatus -eq 1) { $vbsStat = "Enabled (Not Running)" }
                }
                
                $hvStat = if ($cs.HypervisorPresent) { "Hypervisor Detected" } else { "Not Detected" }
                $bootStr = if ($osInfo.LastBootUpTime) { $osInfo.LastBootUpTime.ToString("M/d/yyyy, h:mm:ss tt") } else { "Unknown" }
                $modelStr = if ($cs.Model) { $cs.Model } else { "Unknown" }

                $hiberReg = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Power' -Name 'HibernateEnabled' -ErrorAction SilentlyContinue).HibernateEnabled
                $hiberStat = if ($hiberReg -eq 1) { "Enabled" } else { "Disabled" }

                $payload = [PSCustomObject]@{
                    Sys = @{ Host = $env:COMPUTERNAME; Brand = $cs.Manufacturer; Model = $modelStr; CPUName = $cpu.Name; TotRAM = "$totRamGb GB"; BIOS = $biosStr; BootTime = $bootStr; Hibernate = $hiberStat; VBS = $vbsStat; HyperV = $hvStat; Net = $netStr; IP = $ipAddr }
                    Perf = @{ CPU = $cpuLoad; RAM = $ramPct; GPU = $gpuLoad; NPU = $npuLoad; DiskPct = $diskPct; DiskFree = $diskFree }
                }
                
                $json = $payload | ConvertTo-Json -Depth 4 -Compress
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/gpupdate" -and $request.HttpMethod -eq "GET") {
                $timeLimit = (Get-Date).AddDays(-30)
                $gpEvent = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-GroupPolicy'; Id=@(1500,1501,1502,1503); StartTime=$timeLimit} -MaxEvents 1 -ErrorAction SilentlyContinue
                $lastGp = if ($gpEvent) { $gpEvent.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown (Not in last 30d)" }
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("{ `"LastGP`": `"$lastGp`" }")
                $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/activity") {
                $activeWindows = Get-InteractiveWindows
                $recentProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $null -ne $_.StartTime } | Sort-Object StartTime -Descending | Select-Object Name, Id, StartTime -First 20

                Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] === ACTIVE FOREGROUND WINDOWS FETCHED ===" -ForegroundColor Cyan
                if ($activeWindows.Count -gt 0) {
                    foreach ($win in $activeWindows) {
                        Write-Host " -> PID: $($win.PID) | App: $($win.Name) | Title: $($win.Title)" -ForegroundColor DarkCyan
                    }
                } else {
                    Write-Host " -> No interactive windows detected." -ForegroundColor DarkGray
                }
                Write-Host "====================================================`n" -ForegroundColor Cyan

                $payload = [pscustomobject]@{
                    ActiveWindows = @($activeWindows | ForEach-Object { [pscustomobject]@{ Name = $_.Name; PID = $_.PID; Title = $_.Title } })
                    RecentProcesses = @($recentProcs | ForEach-Object { [pscustomobject]@{ Name = $_.Name; PID = $_.Id; Time = $_.StartTime.ToString("MM/dd HH:mm:ss") } })
                }
                $json = $payload | ConvertTo-Json -Depth 3 -Compress
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/processes") {
                $perfProcs = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "_Total|Idle" -and $_.IDProcess -gt 0 }
                $procs = $perfProcs | Sort-Object -Property @{Expression={[int]$_.PercentProcessorTime};Descending=$true} | Select-Object -First 50 | ForEach-Object {
                    $memMb = [math]::Round(([long]$_.WorkingSet / 1MB), 1)
                    [pscustomobject]@{ PID = $_.IDProcess; Name = ($_.Name -replace '#\d+$', ''); CPU = [int]$_.PercentProcessorTime; RAM = $memMb }
                }
                
                # Update Session Cache
                $sessionCache.Processes = $procs

                $json = @($procs) | ConvertTo-Json -Depth 2 -Compress
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/hardware") {
                $hw = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $null -ne $_.Name } | Select-Object Name, Manufacturer, DeviceID, Status | Sort-Object Status -Descending
                
                # Update Session Cache
                $sessionCache.Hardware = $hw

                $json = @($hw) | ConvertTo-Json -Depth 2 -Compress
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/services") {
                $svcs = Get-Service | Select-Object Name, DisplayName, Status, StartType | Sort-Object DisplayName
                
                # Update Session Cache
                $sessionCache.Services = $svcs

                $json = @($svcs) | ConvertTo-Json -Depth 2 -Compress
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/apps") {
                $keys = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
                $apps = Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $null -ne $_.DisplayName } | Select-Object @{N='Name';E={$_.DisplayName}}, Publisher, @{N='Version';E={$_.DisplayVersion}} | Sort-Object Name -Unique
                
                # Update Session Cache
                $sessionCache.Apps = $apps

                $json = @($apps) | ConvertTo-Json -Depth 2 -Compress
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/events") {
                $days = 2
                if ($request.Url.Query -match "days=(\d+)") { $days = [int]$matches[1] }
                $time = (Get-Date).AddDays(-$days)
                
                $events = Get-WinEvent -FilterHashtable @{LogName='Application','System'; Level=2,3; StartTime=$time} -MaxEvents 50 -ErrorAction SilentlyContinue
                $evList = @()
                if ($null -ne $events) {
                    foreach ($e in $events) {
                        $cleanMsg = ($e.Message -replace "`n|`r", " ")
                        $shortDesc = if ($cleanMsg.Length -gt 100) { $cleanMsg.Substring(0, 97) + "..." } else { $cleanMsg }
                        $evList += [pscustomobject]@{ Time = $e.TimeCreated.ToString("MM/dd/yyyy HH:mm:ss"); Log = $e.LogName; Provider = $e.ProviderName; ShortDesc = $shortDesc; RawMessage = $e.Message; Id = $e.Id; Level = $e.LevelDisplayName }
                    }
                }
                $json = @($evList) | ConvertTo-Json -Depth 3 -Compress
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/deviceevents") {
                $days = 2
                if ($request.Url.Query -match "days=(\d+)") { $days = [int]$matches[1] }
                $time = (Get-Date).AddDays(-$days)
                
                $events = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-PnP'; StartTime=$time} -MaxEvents 50 -ErrorAction SilentlyContinue
                $evList = @()
                if ($null -ne $events) {
                    foreach ($e in $events) {
                        $cleanMsg = ($e.Message -replace "`n|`r", " ")
                        $shortDesc = if ($cleanMsg.Length -gt 100) { $cleanMsg.Substring(0, 97) + "..." } else { $cleanMsg }
                        $evList += [pscustomobject]@{ Time = $e.TimeCreated.ToString("MM/dd/yyyy HH:mm:ss"); Provider = $e.ProviderName; ShortDesc = $shortDesc; RawMessage = $e.Message; Id = $e.Id; Level = $e.LevelDisplayName }
                    }
                }
                $json = @($evList) | ConvertTo-Json -Depth 3 -Compress
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/powerevents") {
                $days = 2
                if ($request.Url.Query -match "days=(\d+)") { $days = [int]$matches[1] }
                $time = (Get-Date).AddDays(-$days)
                
                $events = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName=@('Microsoft-Windows-Kernel-Power','User32'); StartTime=$time} -MaxEvents 50 -ErrorAction SilentlyContinue
                $evList = @()
                if ($null -ne $events) {
                    foreach ($e in $events) {
                        $cleanMsg = ($e.Message -replace "`n|`r", " ")
                        $shortDesc = if ($cleanMsg.Length -gt 100) { $cleanMsg.Substring(0, 97) + "..." } else { $cleanMsg }
                        $evList += [pscustomobject]@{ Time = $e.TimeCreated.ToString("MM/dd/yyyy HH:mm:ss"); Provider = $e.ProviderName; ShortDesc = $shortDesc; RawMessage = $e.Message; Id = $e.Id; Level = $e.LevelDisplayName }
                    }
                }
                $json = @($evList) | ConvertTo-Json -Depth 3 -Compress
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/logs") {
                $logs = Get-ChildItem -Path "C:\Temp\*_capture_log_*.csv","C:\Temp\*_*.html" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "_capture_log_" -or $_.Name -match "^[A-Za-z0-9_.-]+_\d{8}_\d{6}\.html$" } | Select-Object Name | Sort-Object Name -Descending
                $json = @($logs) | ConvertTo-Json -Compress
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/capture" -and $request.HttpMethod -eq "POST") {
                $days = 2
                if ($request.Url.Query -match "days=(\d+)") { $days = [int]$matches[1] }
                
                $activeWindows = Get-InteractiveWindows
                $activeWindowsStr = if ($activeWindows.Count -gt 0) { ($activeWindows | ForEach-Object { "[$($_.PID)] $($_.Name): $($_.Title)" }) -join " || " } else { "None" }

                $recentProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $null -ne $_.StartTime } | Sort-Object StartTime -Descending | Select-Object -First 10
                $recentProcsStr = if ($recentProcs) { ($recentProcs | ForEach-Object { "[$($_.StartTime.ToString('MM/dd HH:mm'))] $($_.Name) ($($_.Id))" }) -join " | " } else { "None" }

                $lookbackTime = (Get-Date).AddDays(-$days)
                
                $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                $lastBoot = $osInfo.LastBootUpTime
                $uptime = (Get-Date) - $lastBoot
                $uptimeStr = "$($uptime.Days) Days, $($uptime.Hours) Hours, $($uptime.Minutes) Mins"
                
                $netStats = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | Select-Object -First 1
                $netStr = "Disconnected"
                if ($netStats) {
                    $speed = $netStats.LinkSpeed
                    if ($netStats.MediaType -match "802.11|WiFi|Wi-Fi") {
                        $wlanData = netsh wlan show interfaces | Out-String
                        if ($wlanData -match 'SSID\s+:\s+([^\r\n]+)') { 
                            $netStr = "$($netStats.InterfaceDescription) (SSID: $($matches[1].Trim()) | Speed: $speed)" 
                        } else {
                            $netStr = "$($netStats.InterfaceDescription) (Speed: $speed)"
                        }
                    } else { 
                        $netStr = "$($netStats.InterfaceDescription) (Speed: $speed)" 
                    }
                }

                $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
                $cpuLoad = [math]::Round(($cpu | Measure-Object -Property LoadPercentage -Average).Average, 0)
                $ramPct = if ($cs.TotalPhysicalMemory -gt 0) { [math]::Round((($cs.TotalPhysicalMemory - $osInfo.FreePhysicalMemory*1024) / $cs.TotalPhysicalMemory) * 100, 0) } else { 0 }
                
                $cDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
                $diskPct = if ($cDrive.Size -gt 0) { [math]::Round((($cDrive.Size - $cDrive.FreeSpace) / $cDrive.Size) * 100, 0) } else { 0 }
                
                $gpuLoad = 0; $npuLoad = 0
                try { $gpuWmi = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction SilentlyContinue
                      if ($gpuWmi) { $gpuLoad = [math]::Round(($gpuWmi | Measure-Object -Property UtilizationPercentage -Average).Average, 0) } } catch {}
                try { $npuWmi = Get-CimInstance Win32_PerfFormattedData_NeuralProcessingUnit_NPUUtilization -ErrorAction SilentlyContinue
                      if ($npuWmi) { $npuLoad = [math]::Round(($npuWmi | Measure-Object -Property UtilizationPercentage -Average).Average, 0) } } catch {}

                $modelStr = if ($cs.Model) { $cs.Model } else { "Unknown" }
                
                $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
                $biosDate = if ($null -ne $bios.ReleaseDate) { $bios.ReleaseDate.ToString("M/d/yyyy") } else { "" }
                $biosName = if ($bios.Name) { $bios.Name } else { "Unknown" }
                $biosStr = if ($biosDate) { "$biosName, $biosDate" } else { "$biosName" }

                $bootStr = if ($osInfo.LastBootUpTime) { $osInfo.LastBootUpTime.ToString("M/d/yyyy, h:mm:ss tt") } else { "Unknown" }
                
                $hiberReg = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Power' -Name 'HibernateEnabled' -ErrorAction SilentlyContinue).HibernateEnabled
                $hiberStat = if ($hiberReg -eq 1) { "Enabled" } else { "Disabled" }

                $dg = Get-CimInstance -Namespace "root\Microsoft\Windows\DeviceGuard" -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
                $vbsStat = "Disabled/Unsupported"
                if ($dg) {
                    if ($dg.VirtualizationBasedSecurityStatus -eq 2) { $vbsStat = "Running" }
                    elseif ($dg.VirtualizationBasedSecurityStatus -eq 1) { $vbsStat = "Enabled (Not Running)" }
                }
                
                $hvStat = if ($cs.HypervisorPresent) { "Hypervisor Detected" } else { "Not Detected" }

                function Get-EventContext ($events, $max = 3) {
                    if (-not $events -or $events.Count -eq 0) { return "None" }
                    return ($events | Select-Object -First $max | ForEach-Object {
                        $cleanLine = ($_.Message -split "`n")[0].Trim() -replace "`r","" -replace ","," "
                        "[$($_.TimeCreated.ToString('HH:mm'))] $cleanLine"
                    }) -join " | "
                }

                function Get-EventDetails ($events, $max = 20) {
                    if (-not $events -or @($events).Count -eq 0) {
                        return "None"
                    }

                    return (@($events) | Select-Object -First $max | ForEach-Object {
                        $msg = ""
                        try {
                            $msg = ($_.Message -replace "`r|`n", " ").Trim()
                        } catch {
                            $msg = ""
                        }

                        if ([string]::IsNullOrWhiteSpace($msg)) {
                            $msg = "No message text available."
                        }

                        if ($msg.Length -gt 700) {
                            $msg = $msg.Substring(0, 700) + "..."
                        }

                        "[{0}] Log={1}; Provider={2}; EventID={3}; Level={4}; Message={5}" -f `
                            $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss"),
                            $_.LogName,
                            $_.ProviderName,
                            $_.Id,
                            $_.LevelDisplayName,
                            $msg
                    }) -join " || "
                }
                $recentUpdates = (Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 5 | ForEach-Object { "$($_.HotFixID) ($($_.InstalledOn.ToString('yyyy-MM-dd')))" }) -join " | "
                $rebootPending = (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -or (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")

                $lookbackTime = (Get-Date).Date.AddDays(-$days)
                
                $sysTargetEvents = Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $lookbackTime } -ErrorAction SilentlyContinue | Where-Object {
                    $_.Id -in @(41, 6008, 1074, 1076, 1001, 2013, 2004, 37) -or
                    ($_.ProviderName -match 'NDIS|WLAN-AutoConfig|Resource-Exhaustion|Kernel-Processor-Power|disk|storahci|storport' -and $_.Level -in @(1,2,3))
                }
                $appTargetEvents = Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = @('Application Error', 'Application Hang'); StartTime = $lookbackTime } -ErrorAction SilentlyContinue
                
                # Format text strings from Session Cache for flat CSV insertion
                $csvProcs = if($sessionCache.Processes) { ($sessionCache.Processes | ForEach-Object { "[$($_.PID)] $($_.Name) CPU:$($_.CPU)% RAM:$($_.RAM)MB" }) -join " || " } else { "Not Fetched" }
                $csvSvcs = if($sessionCache.Services) { ($sessionCache.Services | ForEach-Object { "$($_.Name) [$($_.Status)]" }) -join " || " } else { "Not Fetched" }
                $csvApps = if($sessionCache.Apps) { ($sessionCache.Apps | ForEach-Object { "$($_.Name) [$($_.Version)]" }) -join " || " } else { "Not Fetched" }
                $csvHw = if($sessionCache.Hardware) { ($sessionCache.Hardware | ForEach-Object { "$($_.Name) [$($_.Status)]" }) -join " || " } else { "Not Fetched" }

                $csvRows = @()

                for ($i = 0; $i -lt $days; $i++) {
                    $targetDate = (Get-Date).Date.AddDays(-$i)
                    $dayStart = $targetDate
                    $dayEnd = $targetDate.AddDays(1)

                    $daySys = if ($sysTargetEvents) { $sysTargetEvents | Where-Object { $_.TimeCreated -ge $dayStart -and $_.TimeCreated -lt $dayEnd } } else { @() }
                    $dayApp = if ($appTargetEvents) { $appTargetEvents | Where-Object { $_.TimeCreated -ge $dayStart -and $_.TimeCreated -lt $dayEnd } } else { @() }

                    $rawShutdowns = $daySys | Where-Object { $_.Id -in @(41, 6008) }
                    $rawReboots   = $daySys | Where-Object { $_.Id -in @(1074, 1076) }
                    $rawBSODs     = $daySys | Where-Object { $_.Id -eq 1001 }
                    $rawNetDrops  = $daySys | Where-Object { $_.ProviderName -in @('Microsoft-Windows-NDIS', 'Microsoft-Windows-WLAN-AutoConfig') }
                    $rawAppCrashes = $dayApp | Where-Object { $_.ProviderName -eq 'Application Error' }
                    $rawAppHangs   = $dayApp | Where-Object { $_.ProviderName -eq 'Application Hang' }

                    $rawRamSpikes = $daySys | Where-Object { $_.Id -eq 2004 -or $_.ProviderName -match 'Resource-Exhaustion' }
                    $rawDiskSpikes = $daySys | Where-Object { $_.Id -eq 2013 -or ($_.ProviderName -match 'disk|storahci|storport' -and $_.Level -le 3) }
                    $rawCpuSpikes = $daySys | Where-Object { $_.Id -eq 37 -or ($_.ProviderName -match 'Kernel-Processor-Power' -and $_.Level -le 3) }

                    $csvRows += [pscustomobject]@{
                        Report_Date = $targetDate.ToString("yyyy-MM-dd")
                        Hostname = $env:COMPUTERNAME
                        Manufacturer = $cs.Manufacturer
                        System_Model = $modelStr
                        CPU = $cpu.Name
                        TotalRAM_GB = if ($cs.TotalPhysicalMemory) { [math]::Round(($cs.TotalPhysicalMemory / 1GB), 1) } else { 0 }
                        BIOS_Version = $biosStr
                        System_Boot_Time = $bootStr
                        Hibernate_Status = $hiberStat
                        VBS_Status = $vbsStat
                        HyperV_Status = $hvStat
                        ActiveNetwork = $netStr
                        IPv4_Address = $ipAddr
                        Live_CPU_Usage_Pct = $cpuLoad
                        Live_RAM_Usage_Pct = $ramPct
                        Live_GPU_Usage_Pct = $gpuLoad
                        Live_NPU_Usage_Pct = $npuLoad
                        Live_SystemDrive_Usage_Pct = $diskPct
                        SystemDriveFree_GB = [math]::Round(((Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue).FreeSpace / 1GB), 1)
                        Uptime_Live = $uptimeStr
                        PendingReboot_Live = $rebootPending
                        RecentPatches_Live = if ($recentUpdates) { $recentUpdates } else { "None Found" }
                        Live_Active_Windows = $activeWindowsStr
                        Live_Recent_Processes = $recentProcsStr
                        Events_Shutdowns_Count = if ($rawShutdowns) { @($rawShutdowns).Count } else { 0 }
                        Context_Shutdowns = Get-EventContext $rawShutdowns
                        Events_CleanReboots_Count = if ($rawReboots) { @($rawReboots).Count } else { 0 }
                        Context_CleanReboots = Get-EventContext $rawReboots
                        Events_BlueScreens_Count = if ($rawBSODs) { @($rawBSODs).Count } else { 0 }
                        Context_BlueScreens = Get-EventContext $rawBSODs
                        Events_AppCrashes_Count = if ($rawAppCrashes) { @($rawAppCrashes).Count } else { 0 }
                        Context_AppCrashes = Get-EventContext $rawAppCrashes
                        Events_AppHangs_Count = if ($rawAppHangs) { @($rawAppHangs).Count } else { 0 }
                        Context_AppHangs = Get-EventContext $rawAppHangs
                        Events_NetworkDrops_Count = if ($rawNetDrops) { @($rawNetDrops).Count } else { 0 }
                        Context_NetworkDrops = Get-EventContext $rawNetDrops
                        Details_Shutdowns = Get-EventDetails $rawShutdowns
                        Details_CleanReboots = Get-EventDetails $rawReboots
                        Details_BlueScreens = Get-EventDetails $rawBSODs
                        Details_AppCrashes = Get-EventDetails $rawAppCrashes
                        Details_AppHangs = Get-EventDetails $rawAppHangs
                        Details_NetworkDrops = Get-EventDetails $rawNetDrops
                        Events_RAMSpikes_Count = if ($rawRamSpikes) { @($rawRamSpikes).Count } else { 0 }
                        Context_RAMSpikes = Get-EventContext $rawRamSpikes
                        Details_RAMSpikes = Get-EventDetails $rawRamSpikes
                        Events_DiskSpikes_Count = if ($rawDiskSpikes) { @($rawDiskSpikes).Count } else { 0 }
                        Context_DiskSpikes = Get-EventContext $rawDiskSpikes
                        Details_DiskSpikes = Get-EventDetails $rawDiskSpikes
                        Events_CPUSpikes_Count = if ($rawCpuSpikes) { @($rawCpuSpikes).Count } else { 0 }
                        Context_CPUSpikes = Get-EventContext $rawCpuSpikes
                        Details_CPUSpikes = Get-EventDetails $rawCpuSpikes
                        
                        # --- EXPORT CACHE TO CSV ---
                        Snapshot_Processes = $csvProcs
                        Snapshot_Services = $csvSvcs
                        Snapshot_Apps = $csvApps
                        Snapshot_DeviceManager = $csvHw
                    }
                }
                
                $timestampStr = Get-Date -Format "yyyyMMdd_HHmmss"
                $filePath = "C:\Temp\$env:COMPUTERNAME`_capture_log_$timestampStr.csv"
                $csvRows | Export-Csv -Path $filePath -NoTypeInformation -Force

                $htmlPath = "C:\Temp\$env:COMPUTERNAME`_$timestampStr.html"

                try {
                    New-CaptureHtmlDashboard -Rows $csvRows -OutputPath $htmlPath -Days $days -GeneratedAt (Get-Date) -SessionCache $sessionCache | Out-Null
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] Capture CSV generated: $filePath" -ForegroundColor Green
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] Capture HTML dashboard generated: $htmlPath" -ForegroundColor Green
                } catch {
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] HTML dashboard generation failed: $_" -ForegroundColor Red
                    $htmlPath = ""
                }
                
                $jsonPayload = [pscustomobject]@{ status = "success"; path = $filePath; htmlPath = $htmlPath } | ConvertTo-Json -Compress
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)
                $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/action/openlog" -and $request.HttpMethod -eq "POST") {
                if ($request.Url.Query -match "file=([^&]+)") {
                    $fileName = [System.Uri]::UnescapeDataString($matches[1])
                    if ($fileName -notmatch "\\|/") {
                        $fullPath = "C:\Temp\$fileName"
                        if (Test-Path $fullPath) {
                            $extension = [System.IO.Path]::GetExtension($fullPath)
                            if ($extension -ieq ".html" -or $extension -ieq ".htm") {
                                Invoke-Interactive -Execute "cmd.exe" -Argument "/c start `"`" `"$fullPath`"" | Out-Null
                            } else {
                                Invoke-Interactive -Execute "cmd.exe" -Argument "/c start excel.exe `"$fullPath`"" | Out-Null
                            }
                        }
                    }
                }
                $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok"}'); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/action/kill" -and $request.HttpMethod -eq "POST") {
                if ($request.Url.Query -match "pid=(\d+)&name=([^&]+)") {
                    $targetPid = [int]$matches[1]
                    $pName = [System.Uri]::UnescapeDataString($matches[2])
                    
                    $pendingAction = "KILL"
                    $pendingPid = $targetPid
                    $pendingName = $pName

                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] Queueing interactive kill prompt for $pName (PID: $targetPid)..." -ForegroundColor Yellow

                    $jsonObj = [pscustomobject]@{ status = "ok"; output = "Interactive prompt deployed to remote user screen. Check IT host console for audit logs." }
                    $jsonStr = $jsonObj | ConvertTo-Json -Compress
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($jsonStr)
                } else {
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error"}')
                }
                $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/action/removedevice" -and $request.HttpMethod -eq "POST") {
                if ($request.Url.Query -match "id=([^&]+)") {
                    $devId = [System.Uri]::UnescapeDataString($matches[1])
                    $devId = $devId -replace '"', ''
                    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] Attempting to remove device: $devId..." -ForegroundColor Yellow
                    & pnputil /remove-device "$devId" | Out-Null
                }
                $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok"}'); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/action/hibernate" -and $request.HttpMethod -eq "POST") {
                try {
                    & powercfg.exe /hibernate on | Out-Null
                    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings"
                    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
                    Set-ItemProperty -Path $regPath -Name "ShowHibernateOption" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] Hibernate enabled and added to Power Menu via Dashboard UI." -ForegroundColor Yellow
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok"}')
                } catch {
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error"}')
                }
                $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/action/service" -and $request.HttpMethod -eq "POST") {
                if ($request.Url.Query -match "name=([^&]+)&action=(start|stop)") {
                    $svcName = [System.Uri]::UnescapeDataString($matches[1])
                    $act = $matches[2]
                    if ($act -eq "start") { Start-Service -Name $svcName -ErrorAction SilentlyContinue }
                    if ($act -eq "stop") { Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue }
                }
                $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok"}'); $response.ContentType = "application/json"
            }
            elseif ($request.Url.AbsolutePath -eq "/api/shutdown") {
                $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"shutting down"}'); $response.ContentType = "application/json"
            }
            else { $response.StatusCode = 404 }

            if ($null -ne $buffer) {
                $response.ContentLength64 = $buffer.Length
                try { $response.OutputStream.Write($buffer, 0, $buffer.Length) } catch {}
            }
            try { $response.Close() } catch {}
            
            if ($pendingAction -eq "KILL") {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] Launching interactive kill prompt on remote desktop for $pendingName ($pendingPid)..." -ForegroundColor Red
                
                try {
                    $batContent = "@echo off`r`n" +
                                  "color 0C`r`n" +
                                  "echo ==========================================`r`n" +
                                  "echo WARNING: IT Admin is force killing $pendingName (PID: $pendingPid)`r`n" +
                                  "echo ==========================================`r`n" +
                                  "set /p confirm=`"Are you sure you want to proceed? (Y/N): `"`r`n" +
                                  "if /i `"%confirm%`" NEQ `"Y`" (exit)`r`n" +
                                  "echo.`r`n" +
                                  "echo [1/2] Attempting to kill by PID...`r`n" +
                                  "taskkill /PID $pendingPid /F /T`r`n" +
                                  "echo.`r`n" +
                                  "echo [2/2] Attempting to kill by App Name...`r`n" +
                                  "taskkill /IM `"$pendingName.exe`" /F /T`r`n" +
                                  "echo.`r`n" +
                                  "echo ==========================================`r`n" +
                                  "echo Process complete. Review any errors above.`r`n" +
                                  "echo ==========================================`r`n" +
                                  "pause`r`n" +
                                  "del `"%~f0`" & exit"

                    $batPath = "C:\Temp\KillDebug_$pendingPid.bat"
                    [System.IO.File]::WriteAllText($batPath, $batContent)

                    Invoke-Interactive -Execute "cmd.exe" -Argument "/c start `"`" `"$batPath`"" | Out-Null

                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] Kill sequence completed successfully." -ForegroundColor Green
                } catch {
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [AUDIT] Error during kill sequence: $_" -ForegroundColor Red
                }
            }

        } catch {} 
        
        if ($request.Url.AbsolutePath -eq "/api/shutdown") { break }
    }
} finally {
    cmd.exe /c "netsh http delete urlacl url=$aclUrl" | Out-Null
    if ($null -ne $listener -and $listener.IsListening) { $listener.Stop() }
}
'@

Write-Host "[3/4] Verifying directory structure (C:\IT_Scripts)..." -ForegroundColor Cyan
if ($isLocal) {
    if (-not (Test-Path "C:\IT_Scripts")) { New-Item -ItemType Directory -Path "C:\IT_Scripts" -Force | Out-Null }
    $DashboardPayload | Out-File -FilePath "C:\IT_Scripts\IT_HealthCheck.ps1" -Force -Encoding UTF8
} else {
    Invoke-Command -Session $sess -ArgumentList $DashboardPayload -ScriptBlock {
        param($payloadString)
        if (-not (Test-Path "C:\IT_Scripts")) { New-Item -ItemType Directory -Path "C:\IT_Scripts" -Force | Out-Null }
        $payloadString | Out-File -FilePath "C:\IT_Scripts\IT_HealthCheck.ps1" -Force -Encoding UTF8
    }
}

Write-Host "[4/4] Executing Manage and Monitor SPA & Bridging to User Desktop..." -ForegroundColor Green
try {
    if ($isLocal) {
        powershell.exe -ExecutionPolicy Bypass -NoProfile -File "C:\IT_Scripts\IT_HealthCheck.ps1"
    } else {
        Invoke-Command -Session $sess -ScriptBlock {
            powershell.exe -ExecutionPolicy Bypass -NoProfile -File "C:\IT_Scripts\IT_HealthCheck.ps1"
        }
    }
} finally {
    Write-Host "`nServer Terminated. Checking for newly captured logs..." -ForegroundColor Yellow
    
    if (-not (Test-Path "C:\Temp")) { New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null }
    
    try {
        if ($isLocal) {
            $newLogs = Get-ChildItem -Path "C:\Temp\$env:COMPUTERNAME`_capture_log_*.csv","C:\Temp\$env:COMPUTERNAME`_*.html" -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime -gt (Get-Date).AddMinutes(-60) }
            
            if ($newLogs) {
                Write-Host "[SUCCESS] CSV and HTML reports successfully saved to local IT Machine: C:\Temp\" -ForegroundColor Green
                Invoke-Item "C:\Temp\"
            } else {
                Write-Host "[INFO] No capture logs were generated during this session. Disconnected immediately." -ForegroundColor DarkGray
            }
        } else {
            $newLogs = Invoke-Command -Session $sess -ScriptBlock {
                (Get-ChildItem -Path "C:\Temp\$env:COMPUTERNAME`_capture_log_*.csv","C:\Temp\$env:COMPUTERNAME`_*.html" -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime -gt (Get-Date).AddMinutes(-60) }).FullName
            }
            
            if ($newLogs) {
                Write-Host "Pulling new CSV and HTML reports to local C:\Temp..." -ForegroundColor Cyan
                foreach ($log in $newLogs) {
                    Copy-Item -FromSession $sess -Path $log -Destination "C:\Temp\" -Force -ErrorAction Continue
                }
                Write-Host "[SUCCESS] CSV and HTML reports successfully pulled to local IT Machine: C:\Temp\" -ForegroundColor Green
                Invoke-Item "C:\Temp\"
            } else {
                Write-Host "[INFO] No capture logs were generated during this session. Disconnected immediately." -ForegroundColor DarkGray
            }
        }
    } catch {
        Write-Host "[FAIL] Could not verify logs. $_" -ForegroundColor Red
    }

    if (-not $isLocal) {
        Write-Host "`nCleaning up WinRM Session..." -ForegroundColor DarkGray
        Remove-PSSession -Session $sess
        Write-Host "Session closed successfully. Remote machine is sealed." -ForegroundColor Green
    } else {
        Write-Host "`nLocal session closed successfully." -ForegroundColor Green
    }
}

