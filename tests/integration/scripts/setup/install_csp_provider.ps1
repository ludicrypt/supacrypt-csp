# CSP Provider Installation Script
# Installs and registers the Supacrypt CSP provider

param(
    [string]$BackendUrl = "https://localhost:5001",
    [string]$ProviderPath = "../../../../build/Release/supacrypt-csp.dll",
    [string]$ConfigPath = "../../test_data/configurations/csp_config.json"
)

$ErrorActionPreference = "Stop"

Write-Host "Installing Supacrypt CSP Provider..." -ForegroundColor Yellow

# Check if provider DLL exists
if (-not (Test-Path $ProviderPath)) {
    throw "CSP provider DLL not found at: $ProviderPath. Please build the project first."
}

# Copy provider to system directory
$systemPath = "C:\Windows\System32\supacrypt-csp.dll"
Write-Host "Copying provider to system directory..." -ForegroundColor Cyan
Copy-Item $ProviderPath $systemPath -Force

# Register CSP provider in registry
Write-Host "Registering CSP provider..." -ForegroundColor Cyan
$regPath = "HKLM:\SOFTWARE\Microsoft\Cryptography\Defaults\Provider\Supacrypt CSP"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "Image Path" -Value $systemPath
Set-ItemProperty -Path $regPath -Name "Type" -Value 1
Set-ItemProperty -Path $regPath -Name "SigInFile" -Value 0

# Configure provider settings
Write-Host "Configuring provider settings..." -ForegroundColor Cyan
$configRegPath = "HKLM:\SOFTWARE\Supacrypt\CSP"
New-Item -Path $configRegPath -Force | Out-Null
Set-ItemProperty -Path $configRegPath -Name "BackendUrl" -Value $BackendUrl
Set-ItemProperty -Path $configRegPath -Name "EnableLogging" -Value 1
Set-ItemProperty -Path $configRegPath -Name "LogLevel" -Value "INFO"

# Test provider registration
Write-Host "Testing provider registration..." -ForegroundColor Cyan
try {
    $providers = certlm -store -v
    if ($providers -match "Supacrypt CSP") {
        Write-Host "CSP provider successfully registered!" -ForegroundColor Green
    } else {
        Write-Warning "Provider registration may not be complete"
    }
} catch {
    Write-Warning "Could not verify provider registration: $_"
}

Write-Host "CSP provider installation complete." -ForegroundColor Green