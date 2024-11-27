# Install the QRCodeGenerator module
# Open a new PowerShell console as Administrator.
# Confirm the NuGet provider update if prompted (type "y")
# Next, confirm the installation from the 'PSGallery' repo. Again, enter "y"
Install-Module -Name QRCodeGenerator

# Change PowerShell Execution Policy to 'Unrestricted'. In short, run the command
Set-ExecutionPolicy Unrestricted -Scope Process

# Load the module with the next command:
Import-Module QRCodeGenerator

# You can generate a QR code for your wireless network using the following syntax:
# New-QRCodeWifiAccess -SSID $wifi -Password $pwd -OutPath $path

# Generate a vCard QR code: New-QRCodeVCard -FirstName $first -LastName $last -Company $company -Email$email -OutPath $path
# Generate a Geolocation QR code: New-QRCodeGeolocation -Address $address -OutPath
# PS C:\reports> New-QRCodeText -Text "Hello" -Show

# PS C:\reports> New-QRCodeGeolocation -Latitude 1 -Longitude 3 -Show
# PS C:\reports> New-QRCodeTwitter -ProfileName -Show
# PS C:\reports> New-QRCodeURI -URI http://google.com -Show
# PS C:\reports> New-QRCodeVCard -FirstName -LastName -Company -Show
# 
# more info at https://winaero.com/generate-qr-code-powershell-windows-10/
