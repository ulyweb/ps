<# 
Installs Microsoft Chart Controls for .NET Framework 3.5 using a local winget manifest,
with forced admin elevation, process ExecutionPolicy Bypass, and post-install cleanup.

Usage (from admin PowerShell or normal PowerShell; script will self-elevate):
  .\Install-MSChartWithWinget.ps1
  .\Install-MSChartWithWinget.ps1 -NoCleanup   # keep files after install
#>

[CmdletBinding()]
param(
  # Direct download of MSChart.exe (the binary behind the Download Center page you provided)
  [string]$DownloadUrl = "https://download.microsoft.com/download/0/D/7/0D7A44E0-7A88-4F84-90B1-84A1941B1D7E/MSChart.exe",
  [string]$InstallerPath = "C:\Installers\MSChart.exe",
  [string]$PackageVersion = "3.5.0",
  [string]$LogPath = "$env:TEMP\Install-MSChart.log",
  [switch]$NoCleanup
)

# ------------------------ Helpers ------------------------
function Write-Log {
  param([string]$Message)
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $line = "[$ts] $Message"
  Write-Host $line
  Add-Content -Path $LogPath -Value $line
}

function Ensure-Admin-And-Bypass {
  # If not admin, relaunch elevated, carrying current params and forcing ExecutionPolicy Bypass
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Rebuild original args
    $argList = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"")
    foreach ($bp in $MyInvocation.BoundParameters.GetEnumerator()) {
      if ($bp.Value -is [switch]) {
        if ($bp.Value.IsPresent) { $argList += "-$($bp.Key)" }
      } else {
        $argList += "-$($bp.Key)"
        $argList += "`"$($bp.Value)`""
      }
    }
    Write-Host "Re-launching with administrative privileges…"
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs -PassThru
    $proc.WaitForExit()
    exit $proc.ExitCode
  }

  # Already admin: ensure ExecutionPolicy Bypass for this process
  try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force | Out-Null
  } catch { }
}
Ensure-Admin-And-Bypass

# Start log
"--- $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') : Install-MSChartWithWinget start ---" | Out-File -FilePath $LogPath -Encoding UTF8 -Force

function Ensure-Winget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Log "❌ winget not found. Please install Windows Package Manager (App Installer) from Microsoft Store and retry."
    exit 1
  }
}
Ensure-Winget

function Test-NetFx35 {
  try {
    $out = & DISM /Online /Get-Features /Format:Table 2>&1
    if ($out -match 'NetFx3\s+\|\s+Enabled') { return $true }
  } catch { }
  return $false
}

function Enable-NetFx35 {
  if (Test-NetFx35) {
    Write-Log ".NET Framework 3.5 already enabled."
    return
  }
  Write-Log "Enabling .NET Framework 3.5 (NetFx3)…"
  $p = Start-Process -FilePath "dism.exe" -ArgumentList "/Online","/Enable-Feature","/FeatureName:NetFx3","/All","/NoRestart" -PassThru -Wait
  if ($p.ExitCode -eq 0) {
    Write-Log "✅ NetFx3 enabled (or already present)."
  } else {
    Write-Log "⚠️ DISM exit code $($p.ExitCode). You may need internet or SxS media."
  }
}
Enable-NetFx35

# Ensure destination directory
$destDir = Split-Path -Path $InstallerPath -Parent
if (-not (Test-Path $destDir)) {
  New-Item -ItemType Directory -Path $destDir -Force | Out-Null
  Write-Log "Created $destDir"
}

# Download installer if missing
if (-not (Test-Path $InstallerPath)) {
  Write-Log "Downloading MSChart.exe from: $DownloadUrl"
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  } catch { }
  try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing
    Write-Log "✅ Downloaded to $InstallerPath"
  } catch {
    Write-Log "❌ Download failed: $($_.Exception.Message)"
    exit 1
  }
} else {
  Write-Log "✅ Using existing installer: $InstallerPath"
}

# Compute SHA-256 for manifest
try {
  $sha = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash
  Write-Log "SHA256: $sha"
} catch {
  Write-Log "❌ Failed to compute SHA256: $($_.Exception.Message)"
  exit 1
}

# Build manifest
$manifestDir  = Join-Path $env:TEMP "winget-mschart35"
$manifestPath = Join-Path $manifestDir "mschart35.yaml"
if (-not (Test-Path $manifestDir)) { New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null }

$installerUri = "file:///" + ($InstallerPath -replace '\\','/')
$yaml = @"
# yaml-language-server: \$schema=https://aka.ms/winget-manifest.singleton.1.6.0.json
PackageIdentifier: Local.MicrosoftChartControls35
PackageVersion: $PackageVersion
PackageName: Microsoft Chart Controls for .NET Framework 3.5
Publisher: Microsoft Corporation
License: Microsoft EULA
ShortDescription: Chart controls for .NET Framework 3.5 SP1
Moniker: mschart35

Installers:
  - Architecture: neutral
    InstallerType: exe
    InstallerUrl: $installerUri
    InstallerSha256: $sha
    InstallerSwitches:
      Silent: "/quiet /norestart"
      SilentWithProgress: "/passive /norestart"
    Scope: machine

AppsAndFeaturesEntries:
  - DisplayName: Microsoft Chart Controls for Microsoft .NET Framework 3.5
"@
$yaml | Out-File -FilePath $manifestPath -Encoding UTF8 -Force
Write-Log "Manifest saved: $manifestPath"

# Validate manifest (non-fatal)
Write-Log "Validating manifest with winget…"
$val = Start-Process -FilePath "winget" -ArgumentList @("validate",$manifestPath) -NoNewWindow -PassThru -Wait
if ($val.ExitCode -ne 0) {
  Write-Log "⚠️ winget validate exit code $($val.ExitCode). Proceeding anyway…"
} else {
  Write-Log "✅ Manifest validated."
}

# Install via winget
$installSucceeded = $false
Write-Log "Installing via winget…"
$inst = Start-Process -FilePath "winget" -ArgumentList @(
  "install","--manifest",$manifestPath,"--silent",
  "--accept-package-agreements","--accept-source-agreements"
) -NoNewWindow -PassThru -Wait

if ($inst.ExitCode -eq 0) {
  $installSucceeded = $true
  Write-Log "✅ winget install completed."
} else {
  Write-Log "⚠️ winget install exit code $($inst.ExitCode). Trying direct silent install fallback…"
  $p = Start-Process -FilePath $InstallerPath -ArgumentList "/quiet","/norestart" -PassThru -Wait
  if ($p.ExitCode -eq 0) {
    $installSucceeded = $true
    Write-Log "✅ Fallback direct install succeeded."
  } else {
    Write-Log "❌ Fallback direct install failed (exit $($p.ExitCode))."
  }
}

# Cleanup (default ON; skip with -NoCleanup)
function Try-Delete([string]$PathToDelete) {
  try {
    if (Test-Path $PathToDelete) {
      Remove-Item -Path $PathToDelete -Force -Recurse -ErrorAction Stop
      Write-Log "🧹 Removed: $PathToDelete"
    }
  } catch {
    Write-Log "⚠️ Cleanup warning for $PathToDelete : $($_.Exception.Message)"
  }
}

if (-not $NoCleanup) {
  Write-Log "Starting cleanup…"
  Try-Delete $manifestDir
  Try-Delete $InstallerPath
} else {
  Write-Log "Cleanup disabled by -NoCleanup. Files retained."
}

if ($installSucceeded) {
  Write-Log "✅ Completed successfully. Log: $LogPath"
  exit 0
} else {
  Write-Log "❌ Installation did not succeed. See log: $LogPath"
  exit 1
}
