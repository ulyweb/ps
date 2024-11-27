# Prompt for the domain and username
$credential = (Get-Credential)

# Define the command to update the prompt
$updatePromptCommand = @"
function prompt {
    "https://raw.githubusercontent.com/francisuadm/ps/main/scripts/RemovePCUserFolder.ps1 and paste"
}
"@

# Run the command with the specified user
Start-Process -FilePath "powershell.exe" -ArgumentList "-Command `"Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command `"& { $updatePromptCommand; powershell }`"' -Verb RunAs`"" -Credential $credential
