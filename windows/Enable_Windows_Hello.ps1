# Run as Administrator

# Enable Biometrics
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics" -Name "Enabled" -Value 1 -Type DWord

# Enable Facial Recognition
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics\FacialFeatures" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics\FacialFeatures" -Name "Enabled" -Value 1 -Type DWord

# Enable Fingerprint Recognition
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics\FingerprintFeatures" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics\FingerprintFeatures" -Name "Enabled" -Value 1 -Type DWord

# Enable PIN Sign-in
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "AllowDomainPINLogon" -Value 1 -Type DWord
# Remove Credential Provider blocks
$providers = @(
    "{8AF662BF-65A0-4D0A-A540-A338A999D36F}",  # Facial
    "{BEC09223-B018-416D-A0AC-523971B639F5}",  # Fingerprint
    "{D6886603-9D2F-4EB2-B667-1971041FA96B}"   # PIN
)

foreach ($guid in $providers) {
    $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\$guid"
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
    }
}
