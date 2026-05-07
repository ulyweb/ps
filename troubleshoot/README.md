# IT Manage & Monitor Dashboard

A standalone, offline-capable PowerShell deployment tool that provisions a rich Single Page Application (SPA) web dashboard for real-time Windows system telemetry, process management, and forensic event capture.

## 🚀 Overview

This tool provides an "All-in-One Embedded Payload" architecture. It requires no third-party web servers (like IIS or Apache) and relies entirely on native Windows Management Instrumentation (WMI/CIM) and a dynamic HTTP listener built directly into the PowerShell script. It is designed for IT Administrators and Security Professionals needing immediate, deep visibility into a Windows machine without leaving permanent agent software behind.

## ✨ Key Features

* **Zero-Install Architecture:** Runs entirely from a single `.ps1` script. The HTML, CSS, and JavaScript payload is embedded directly within the code.
* **Dual Execution Modes:** * **Local (`[L]`):** Runs the dashboard directly on the host machine.
    * **Remote (`[R]`):** Establishes a secure WinRM bridge to a target device, deploying the dashboard in an invisible background worker while tunneling the UI back to the IT administrator.
* **Real-Time Telemetry:** Instant polling for CPU, RAM, GPU, NPU, Disk utilization, Active Network (including SSID and Link Speed), BIOS version, Boot Time, VBS (Virtualization-Based Security), Hyper-V, and Hibernate status.
* **Live User Activity Auditing:** Monitor active foreground windows and recently launched processes, with a simultaneous color-coded audit trail pushed to the IT host's command line.
* **Active System Management:**
    * Force-kill processes (with interactive warning prompts).
    * Start and stop system services.
    * Query and force background Group Policy updates (`gpupdate /force`).
    * Remove ghost/errored hardware from Device Manager.
* **Forensic Capture & Reports:** Compiles a historical Day-by-Day Event Log matrix detailing App Crashes, Unexpected Shutdowns, BSODs, Network Drops, and Resource Exhaustion Spikes (CPU/RAM/Disk). Automatically exports both a `.csv` and a highly styled offline `.html` dashboard artifact.

## 🛠️ Prerequisites

* **Operating System:** Windows 10 / Windows 11 / Windows Server 2016+
* **Privileges:** Must be executed directly from an **Administrator** elevated PowerShell console.
* **Remote Execution:** The target machine must have **WinRM** (Windows Remote Management) enabled and accessible over the network.

## 💻 Usage Instructions

1.  Open PowerShell as an Administrator.
2.  Execute the script:
    ```powershell
    .\IT_HealthCheck.ps1
    ```
3.  When prompted, enter `L` to target your local machine, or `R` to target a remote machine on your network.
4.  If `Remote` is selected, enter the Hostname or IP Address of the target.
5.  The script will securely allocate an available port (typically 15500+), start the embedded HTTP listener, and automatically open the Dashboard UI in your default web browser.

## 🛑 Safe Termination & Log Pulling

To prevent orphaned background processes and ensure captured artifacts are securely retrieved:

* **From the UI:** Click the red **Disconnect & Pull Logs** button in the top right corner.
* **From the Console (Local Mode):** Press the **`Q`** key in the active PowerShell console to intercept the listener and gracefully shut down.
* **From the Console (Remote Mode):** Press **`Ctrl + C`** to drop the WinRM session safely.

*Upon termination, any generated CSV or HTML forensic reports are automatically copied to the IT Host's `C:\Temp` directory for permanent offline review.*

## 🔒 Security & Antivirus Considerations

Because this tool dynamically invokes invisible PowerShell environments, bypasses standard execution policies (`-ExecutionPolicy Bypass`), and manipulates WMI/Event Logs, it may trigger heuristic flags from enterprise Endpoint Detection and Response (EDR) platforms. It is highly recommended to run this as a raw `.ps1` script rather than compiling it to a `.exe` to maintain transparency and avoid automated malware quarantine protocols.
