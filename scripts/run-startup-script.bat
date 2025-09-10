@echo off
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ulyweb/ps/refs/heads/main/scripts/remove-startup-apps.ps1' -OutFile '$env:TEMP\remove-startup-apps.ps1'; Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\remove-startup-apps.ps1"' -Verb RunAs"
