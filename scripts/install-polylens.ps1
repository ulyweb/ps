<#
.SYNOPSIS
	Installs Poly Lens
.DESCRIPTION
	This PowerShell script installs Poly Lens from the Winget Store.
.EXAMPLE
	PS> ./install-polylens.ps1
.LINK
.NOTES

#>

try {
	"Installing Poly Lens, please wait..."

	& winget install Poly.PolyLens --accept-package-agreements --accept-source-agreements -s
	if ($lastExitCode -ne "0") { throw "'winget install' failed" }

	"Poly Lens installed successfully."
	exit 0 # success
} catch {
	"⚠️ Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
	exit 1
}
