Here's package the function command called 'AdminSession' in module (`.psm1`)**.

---

## ✅ Step 1: Create the Module Folder and File

1. Open PowerShell.

2. Decide on a module name. Let's call it: `AdminSession`.

3. Run these commands to create the module folder and file:

```powershell
$moduleName = "AdminSession"
$modulePath = "$HOME\Documents\PowerShell\Modules\$moduleName"
New-Item -Path $modulePath -ItemType Directory -Force
New-Item -Path "$modulePath\$moduleName.psm1" -ItemType File -Force
```

---

## ✅ Step 2: Add the Function to the `.psm1` File

Open the module file in a text editor:

```powershell
notepad "$modulePath\$moduleName.psm1"
```

Paste the following into the file:

```powershell
function Start-ElevatedAdminSession {
    <#
    .SYNOPSIS
        Starts an elevated PowerShell session using an alternate admin account.

    .DESCRIPTION
        Constructs a username of the form "DOMAIN\a-username", prompts for credentials,
        then launches a new elevated PowerShell session under that account using PowerShell 7+.

    .NOTES
        Requires PowerShell 7.5.1+ and admin privileges.
    #>

    Clear-Host

    # Construct admin-style username
    $adminUser = "$($env:USERDOMAIN)\a-$($env:USERNAME)"

    # Prompt for credentials
    try {
        $secureCred = Get-Credential -UserName $adminUser -Message "Enter credentials for $adminUser"
    } catch {
        Write-Warning "Credential prompt was canceled or failed."
        return
    }

    # Launch a new elevated PowerShell session under provided credentials
    try {
        Start-Process pwsh -Credential $secureCred -ArgumentList '-NoProfile -Command &{ Start-Process pwsh -Verb RunAs }'
    } catch {
        Write-Error "Failed to start elevated session: $_"
    }
}
```

Save and close the file.

---

## ✅ Step 3: Import the Module

You only need to do this once per session (unless you add it to your profile).

```powershell
Import-Module AdminSession
```

If the module doesn't load, check:

```powershell
Get-Module -ListAvailable
```

And make sure the folder is under:

```powershell
$env:PSModulePath -split ';'
```

---

## ✅ Step 4: Use the Function

Now just run:

```powershell
Start-ElevatedAdminSession
```

---

## ✅ Optional: Auto-Import via Profile

To auto-load it every time you open PowerShell, add this to your PowerShell profile:

```powershell
'Import-Module AdminSession' | Add-Content $PROFILE
```

---

