Clear-Host
 
# Function to check if a module is installed
function Check-Module {
    param (
        [string]$ModuleName
    )
    try {
        Get-Module -Name $ModuleName -ListAvailable -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}
 
# Check if the ExchangeOnlineManagement module is installed
$ModuleName = "ExchangeOnlineManagement"
$ModuleInstalled = Check-Module -ModuleName $ModuleName
 
if (-not $ModuleInstalled) {
    # Step 1: Install the ExchangeOnlineManagement module
    Write-Output "Installing ExchangeOnlineManagement module..."
    Install-Module -Name $ModuleName -Force
} else {
    Write-Output "ExchangeOnlineManagement module is already installed."
}
 
# Import the ExchangeOnlineManagement module
Import-Module $ModuleName
 
# Ensure the execution policy is set to RemoteSigned
$CurrentPolicy = Get-ExecutionPolicy
if ($CurrentPolicy -ne "RemoteSigned") {
    Write-Output "Setting execution policy to RemoteSigned..."
    Set-ExecutionPolicy RemoteSigned -Force
} else {
    Write-Output "Execution policy is already set to RemoteSigned."
}
 
# Step 2: Connect to Exchange Online
Connect-ExchangeOnline
 
## Disconnect from Exchange Online
# Disconnect-ExchangeOnline -Confirm:$false
