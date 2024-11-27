# Region: Module Management & Execution Policy

# Check if QRCodeGenerator module is installed. If not, install it.
if (-not (Get-Module QRCodeGenerator -ListAvailable)) {
    Write-Host "Installing QRCodeGenerator module..." -ForegroundColor Green
    Install-Module -Name QRCodeGenerator -Force
}

# Set execution policy to Unrestricted temporarily for this script's session.
# This allows running scripts downloaded from the internet.
if ((Get-ExecutionPolicy -Scope Process) -ne 'Unrestricted') {
    Write-Host "Setting execution policy to Unrestricted for this session..." -ForegroundColor Yellow
    Set-ExecutionPolicy Unrestricted -Scope Process -Force
}

# Import the QRCodeGenerator module to access its cmdlets.
Import-Module QRCodeGenerator

# EndRegion

# Region: Main Menu & Input Validation

# Function to display the main menu.
function Show-Menu {
    Clear-Host
    Write-Host "QR Code Generator Menu" -ForegroundColor Cyan
    Write-Host "----------------------"
    Write-Host "1. Generate WiFi QR Code"
    Write-Host "2. Generate Text QR Code"
    Write-Host "3. Generate vCard QR Code"
    Write-Host "4. Generate URL QR Code"
    Write-Host "Q. Quit"
}

# Function to get valid user input for the menu.
function Get-MenuChoice {
    $choice = Read-Host "Enter your choice"

    while (($choice -notin 1..4) -and ($choice.ToUpper() -ne 'Q')) {
        Write-Host "Invalid choice. Please try again." -ForegroundColor Red
        $choice = Read-Host "Enter your choice"
    }

    return $choice
}

# EndRegion

# Region: QR Code Generation Functions

# Function to generate a WiFi QR code.
function Generate-WifiQRCode {
    $ssid = Read-Host "Enter SSID"
    $password = Read-Host -AsSecureString "Enter password" | ConvertFrom-SecureString
    

    New-QRCodeWifiAccess -SSID $ssid -Password $password -Show
}

# Function to generate a text QR code.
function Generate-TextQRCode {
    $text = Read-Host "Enter text"

    New-QRCodeText -Text $text -Show
}

# Function to generate a vCard QR code.
function Generate-VcardQRCode {
    $firstName = Read-Host "Enter first name"
    $lastName = Read-Host "Enter last name"
    $organization = Read-Host "Enter organization"
    $email = Read-Host "Enter email"
    

    # Use the updated cmdlet and parameters 
    New-PSOneQRCodeVCard -FirstName $firstName -LastName $lastName -Company $organization -Email $email -Show
}

# Function to generate a URL QR code.
function Generate-UrlQRCode {
    $url = Read-Host "Enter URL"

    New-QRCodeURI -URI $url -Show
}

# EndRegion

# Main script execution loop.
$continue = $true # Initialize a variable to control the loop

while ($continue) {
    Show-Menu

    $choice = Get-MenuChoice

    switch ($choice) {
        1 { Generate-WifiQRCode }
        2 { Generate-TextQRCode }
        3 { Generate-VcardQRCode }
        4 { Generate-UrlQRCode }
        'Q' { 
            Write-Host "Exiting..." -ForegroundColor Green
            $continue = $false # Set the variable to false to exit the loop
        }
    }

    if ($continue) { # Only prompt if the loop will continue
        Read-Host "Press Enter to continue..." 
    }
}

# Reset execution policy back to its original state for this session.
if ((Get-ExecutionPolicy -Scope Process) -ne 'Unrestricted') {
    Set-ExecutionPolicy -ExecutionPolicy (Get-ExecutionPolicy -Scope Process) -Scope Process -Force
}
