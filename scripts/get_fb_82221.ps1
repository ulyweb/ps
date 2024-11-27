# Requires -RunAsAdministrator 
#
#           File Browser Installer Script
#
#   GitHub: https://github.com/filebrowser/filebrowser
#   Issues: https://github.com/filebrowser/filebrowser/issues
#
#   Usage:
#
#   	iwr -useb https://raw.githubusercontent.com/filebrowser/get/master/get.ps1 | iex
#
#	You should run it as administrator so it can add filemanager to 
#	the PATH.
#

function Install-FileManager {
	$ErrorActionPreference = "Stop"

	$resource = "https://api.github.com/repos/filebrowser/filebrowser/releases/latest"
	$tag = Invoke-RestMethod -Method Get -Uri $resource | select -Expand tag_name
	$arch = "386"

	If ((Get-WmiObject Win32_OperatingSystem).OSArchitecture -eq "64-bit") {
		$arch = "amd64"
	}

	$file = "windows-$arch-filebrowser.zip"
	$url = "https://github.com/filebrowser/filebrowser/releases/download/$tag/$file"
	$temp =  New-TemporaryFile
	$folder = "C:\IT_Folder\filebrowser"

	# Check if the folder exists and delete it
	if (Test-Path $folder) {
		Write-Host "Removing existing folder $folder"
		Remove-Item -Force -Recurse $folder
	}

	Write-Host "Downloading" $url
		$WebClient = New-Object System.Net.WebClient 
		$WebClient.DownloadFile( $url, $temp ) 
	
	Write-Host "Extracting $temp.zip"
		Move-Item $temp "$temp.zip"
		Expand-Archive "$temp.zip" -DestinationPath $temp

	Write-Host "Installing filebrowser on $folder"
		If (-not (Test-Path $folder)) {
			New-Item -ItemType "directory" -Path $folder | Out-Null
		}
		Move-Item "$temp\filebrowser.exe" "$folder\filebrowser.exe"

	Write-Host "Cleaning temporary files"
		Remove-Item -Force "$temp.zip"
		Remove-Item -Force -Recurse "$temp"

	Write-Host "Adding filemanager to the PATH"
		if ((Get-Command "filebrowser.exe" -ErrorAction SilentlyContinue) -eq $null) { 
			$path = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
			$path = $path + ";$folder"
			Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value "$path"
		}

	Write-Host "filemanager successfully installed!" -ForegroundColor Green 

	# Check and add firewall rule for port 8080
	$port = 8080
	$rule = Get-NetFirewallRule -DisplayName "Allow Port $port" -ErrorAction SilentlyContinue
	if ($null -eq $rule) {
		Write-Host "Adding firewall rule for port $port"
		New-NetFirewallRule -DisplayName "Allow Port $port" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow
	} else {
		Write-Host "Firewall rule for port $port already exists"
	}
}

Install-FileManager

# Change directory to C:\IT_Folder\filebrowser and run filebrowser
Set-Location -Path "C:\IT_Folder\filebrowser"
filebrowser -a 0.0.0.0 -p 8080 -r "C:\IT_Folder"
