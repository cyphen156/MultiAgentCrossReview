$ErrorActionPreference = "Continue"

Write-Host "== CyphenEngine WSL setup =="
Write-Host "Enabling Windows optional features..."

dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
$wslFeatureExitCode = $LASTEXITCODE

dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
$vmPlatformExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "WSL feature exit code: $wslFeatureExitCode"
Write-Host "VirtualMachinePlatform exit code: $vmPlatformExitCode"
Write-Host ""

Write-Host "Installing Ubuntu through wsl.exe..."
wsl.exe --install -d Ubuntu
$wslInstallExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "wsl --install exit code: $wslInstallExitCode"
Write-Host ""
Write-Host "Current WSL status:"
wsl.exe --status
Write-Host ""
Write-Host "Installed distributions:"
wsl.exe -l -v

Write-Host ""
Write-Host "If Windows reports that a reboot is required, reboot before continuing the Linux build test."
Read-Host "Press Enter to close"
