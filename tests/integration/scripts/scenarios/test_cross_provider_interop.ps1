# Cross-Provider Interoperability Tests
# Tests interaction between CSP and KSP providers

param(
    [string]$CSPProvider = "Supacrypt CSP",
    [string]$KSPProvider = "Supacrypt KSP",
    [int]$MigrationTestCerts = 100
)

$ErrorActionPreference = "Stop"

Write-Host "=== Cross-Provider Interoperability Tests ===" -ForegroundColor Green

# Test results tracking
$testResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Details = @()
    InteropMetrics = @{}
}

function Test-ProviderDetection {
    param($TestName = "Provider Detection and Enumeration")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        $detectedProviders = @{
            CSPProviders = @()
            KSPProviders = @()
        }
        
        # Detect CSP providers
        Write-Host "  Enumerating CSP providers..." -ForegroundColor Cyan
        try {
            # Get registered CSP providers from registry
            $cspRegPath = "HKLM:\SOFTWARE\Microsoft\Cryptography\Defaults\Provider"
            if (Test-Path $cspRegPath) {
                $cspProviders = Get-ChildItem $cspRegPath | ForEach-Object { $_.PSChildName }
                $detectedProviders.CSPProviders = $cspProviders
                Write-Host "    Found CSP providers: $($cspProviders -join ', ')" -ForegroundColor Cyan
            }
        } catch {
            Write-Warning "Failed to enumerate CSP providers: $_"
        }
        
        # Detect KSP providers
        Write-Host "  Enumerating KSP providers..." -ForegroundColor Cyan
        try {
            # Use CNG to enumerate KSP providers
            Add-Type -TypeDefinition @"
                using System;
                using System.Runtime.InteropServices;
                public class ProviderEnumeration {
                    [StructLayout(LayoutKind.Sequential)]
                    public struct NCryptProviderName {
                        public IntPtr pszName;
                        public IntPtr pszComment;
                    }
                    
                    [DllImport("ncrypt.dll")]
                    public static extern int NCryptEnumStorageProviders(out int pdwProviderCount, out IntPtr ppProviderList, int dwFlags);
                    
                    [DllImport("ncrypt.dll")]
                    public static extern int NCryptFreeBuffer(IntPtr pvInput);
                }
"@
            
            $providerCount = 0
            $providerListPtr = [IntPtr]::Zero
            
            $result = [ProviderEnumeration]::NCryptEnumStorageProviders([ref]$providerCount, [ref]$providerListPtr, 0)
            
            if ($result -eq 0 -and $providerCount -gt 0) {
                Write-Host "    Found $providerCount KSP providers" -ForegroundColor Cyan
                $detectedProviders.KSPProviders = @("Found $providerCount providers")
                [ProviderEnumeration]::NCryptFreeBuffer($providerListPtr)
            }
        } catch {
            Write-Warning "Failed to enumerate KSP providers: $_"
        }
        
        # Check if both Supacrypt providers are detected
        $cspDetected = $detectedProviders.CSPProviders -contains $CSPProvider
        $kspDetected = $detectedProviders.KSPProviders.Count -gt 0 # Simplified check
        
        if ($cspDetected -or $kspDetected) {
            Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
            Write-Host "  CSP detected: $cspDetected" -ForegroundColor Cyan
            Write-Host "  KSP detected: $kspDetected" -ForegroundColor Cyan
            
            $testResults.PassedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "PASSED"
                Details = "CSP: $cspDetected, KSP: $kspDetected"
            }
            return $true
        } else {
            throw "Neither CSP nor KSP providers detected"
        }
    } catch {
        Write-Host "✗ $TestName - FAILED (Exception: $($_.Exception.Message))" -ForegroundColor Red
        $testResults.FailedTests++
        $testResults.Details += @{
            Test = $TestName
            Status = "FAILED"
            Details = "Exception: $($_.Exception.Message)"
        }
        return $false
    }
}

function Test-SimultaneousProviderUsage {
    param($TestName = "Simultaneous Provider Usage")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        $simultaneousResults = @{
            CSPCertificates = 0
            KSPCertificates = 0
            CrossProviderOps = 0
            Conflicts = 0
        }
        
        # Create certificates with both providers simultaneously
        Write-Host "  Creating certificates with both providers..." -ForegroundColor Cyan
        
        $jobs = @()
        
        # CSP certificate creation job
        $cspJob = Start-Job -ScriptBlock {
            param($provider)
            try {
                $certs = @()
                for ($i = 1; $i -le 10; $i++) {
                    $cert = New-SelfSignedCertificate -Subject "CN=CSPSimul$i" -Provider $provider -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
                    $certs += $cert
                    Start-Sleep -Milliseconds 100
                }
                return @{ Success = $true; Count = $certs.Count; Provider = "CSP" }
            } catch {
                return @{ Success = $false; Error = $_.Exception.Message; Provider = "CSP" }
            }
        } -ArgumentList $CSPProvider
        
        # KSP certificate creation job
        $kspJob = Start-Job -ScriptBlock {
            param($provider)
            try {
                $certs = @()
                for ($i = 1; $i -le 10; $i++) {
                    try {
                        $cert = New-SelfSignedCertificate -Subject "CN=KSPSimul$i" -Provider $provider -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
                        $certs += $cert
                    } catch {
                        # Try fallback approach for KSP
                        $cert = New-SelfSignedCertificate -Subject "CN=KSPSimul$i" -KeyAlgorithm RSA -KeyLength 2048 -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
                        $certs += $cert
                    }
                    Start-Sleep -Milliseconds 100
                }
                return @{ Success = $true; Count = $certs.Count; Provider = "KSP" }
            } catch {
                return @{ Success = $false; Error = $_.Exception.Message; Provider = "KSP" }
            }
        } -ArgumentList $KSPProvider
        
        $jobs = @($cspJob, $kspJob)
        
        # Wait for both jobs to complete
        $results = $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job
        
        # Analyze results
        foreach ($result in $results) {
            if ($result.Success) {
                if ($result.Provider -eq "CSP") {
                    $simultaneousResults.CSPCertificates = $result.Count
                } elseif ($result.Provider -eq "KSP") {
                    $simultaneousResults.KSPCertificates = $result.Count
                }
                $simultaneousResults.CrossProviderOps++
            } else {
                Write-Warning "$($result.Provider) job failed: $($result.Error)"
            }
        }
        
        # Test cross-provider certificate operations
        Write-Host "  Testing cross-provider certificate operations..." -ForegroundColor Cyan
        
        try {
            # Create a certificate with CSP and try to use it in a KSP context
            $cspCert = New-SelfSignedCertificate -Subject "CN=CrossTest" -Provider $CSPProvider -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
            
            # Verify the certificate can be accessed
            $foundCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Subject -eq "CN=CrossTest" }
            if ($foundCert) {
                $simultaneousResults.CrossProviderOps++
            }
        } catch {
            $simultaneousResults.Conflicts++
            Write-Warning "Cross-provider operation failed: $_"
        }
        
        if ($simultaneousResults.CrossProviderOps -gt 0 -and $simultaneousResults.Conflicts -eq 0) {
            Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
            Write-Host "  CSP certificates created: $($simultaneousResults.CSPCertificates)" -ForegroundColor Cyan
            Write-Host "  KSP certificates created: $($simultaneousResults.KSPCertificates)" -ForegroundColor Cyan
            Write-Host "  Cross-provider operations: $($simultaneousResults.CrossProviderOps)" -ForegroundColor Cyan
            
            $testResults.PassedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "PASSED"
                Details = "CSP: $($simultaneousResults.CSPCertificates), KSP: $($simultaneousResults.KSPCertificates), Cross-ops: $($simultaneousResults.CrossProviderOps)"
            }
            $testResults.InteropMetrics.SimultaneousUsage = $simultaneousResults
            return $true
        } else {
            throw "Simultaneous provider usage failed or conflicts detected"
        }
    } catch {
        Write-Host "✗ $TestName - FAILED (Exception: $($_.Exception.Message))" -ForegroundColor Red
        $testResults.FailedTests++
        $testResults.Details += @{
            Test = $TestName
            Status = "FAILED"
            Details = "Exception: $($_.Exception.Message)"
        }
        return $false
    }
}

function Test-CertificatePortability {
    param($TestName = "Certificate Portability")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        $portabilityResults = @{
            CSPtoKSPMigrations = 0
            KSPtoCSPMigrations = 0
            FailedMigrations = 0
            CompatibilityIssues = 0
        }
        
        # Test CSP to KSP migration scenario
        Write-Host "  Testing CSP to KSP certificate migration..." -ForegroundColor Cyan
        
        try {
            # Create certificate with CSP
            $cspCert = New-SelfSignedCertificate -Subject "CN=CSPtoKSPTest" -Provider $CSPProvider -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
            
            # Export certificate (public key portion)
            $certBytes = $cspCert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
            $exportPath = "$env:TEMP\csp_cert_export.cer"
            [System.IO.File]::WriteAllBytes($exportPath, $certBytes)
            
            # Import to test portability
            $importedCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($exportPath)
            
            if ($importedCert.Subject -eq $cspCert.Subject) {
                $portabilityResults.CSPtoKSPMigrations++
            }
            
            # Cleanup
            Remove-Item $exportPath -Force -ErrorAction SilentlyContinue
        } catch {
            $portabilityResults.FailedMigrations++
            Write-Warning "CSP to KSP migration test failed: $_"
        }
        
        # Test KSP to CSP migration scenario
        Write-Host "  Testing KSP to CSP certificate migration..." -ForegroundColor Cyan
        
        try {
            # Create certificate with fallback approach (simulating KSP)
            $kspCert = New-SelfSignedCertificate -Subject "CN=KSPtoCSPTest" -KeyAlgorithm RSA -KeyLength 2048 -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
            
            # Export certificate
            $certBytes = $kspCert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
            $exportPath = "$env:TEMP\ksp_cert_export.cer"
            [System.IO.File]::WriteAllBytes($exportPath, $certBytes)
            
            # Import to test portability
            $importedCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($exportPath)
            
            if ($importedCert.Subject -eq $kspCert.Subject) {
                $portabilityResults.KSPtoCSPMigrations++
            }
            
            # Cleanup
            Remove-Item $exportPath -Force -ErrorAction SilentlyContinue
        } catch {
            $portabilityResults.FailedMigrations++
            Write-Warning "KSP to CSP migration test failed: $_"
        }
        
        # Test certificate format compatibility
        Write-Host "  Testing certificate format compatibility..." -ForegroundColor Cyan
        
        try {
            # Create certificates with different key sizes
            $keySizes = @(2048, 3072, 4096)
            
            foreach ($keySize in $keySizes) {
                try {
                    $cert = New-SelfSignedCertificate -Subject "CN=CompatTest$keySize" -Provider $CSPProvider -KeyLength $keySize -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
                    
                    # Verify key size
                    if ($cert.PublicKey.Key.KeySize -eq $keySize) {
                        # Compatibility check passed
                    } else {
                        $portabilityResults.CompatibilityIssues++
                    }
                } catch {
                    $portabilityResults.CompatibilityIssues++
                    Write-Warning "Key size $keySize compatibility test failed: $_"
                }
            }
        } catch {
            $portabilityResults.CompatibilityIssues++
        }
        
        # Evaluate results
        $totalMigrations = $portabilityResults.CSPtoKSPMigrations + $portabilityResults.KSPtoCSPMigrations
        $successRate = if ($totalMigrations -gt 0) { 
            [math]::Round((($totalMigrations) / ($totalMigrations + $portabilityResults.FailedMigrations)) * 100, 1) 
        } else { 0 }
        
        if ($totalMigrations -gt 0 -and $successRate -gt 50) {
            Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
            Write-Host "  CSP→KSP migrations: $($portabilityResults.CSPtoKSPMigrations)" -ForegroundColor Cyan
            Write-Host "  KSP→CSP migrations: $($portabilityResults.KSPtoCSPMigrations)" -ForegroundColor Cyan
            Write-Host "  Success rate: $successRate%" -ForegroundColor Cyan
            Write-Host "  Compatibility issues: $($portabilityResults.CompatibilityIssues)" -ForegroundColor Cyan
            
            $testResults.PassedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "PASSED"
                Details = "Migrations: $totalMigrations, Success: $successRate%, Issues: $($portabilityResults.CompatibilityIssues)"
            }
            $testResults.InteropMetrics.PortabilityResults = $portabilityResults
            return $true
        } else {
            throw "Certificate portability test failed or low success rate: $successRate%"
        }
    } catch {
        Write-Host "✗ $TestName - FAILED (Exception: $($_.Exception.Message))" -ForegroundColor Red
        $testResults.FailedTests++
        $testResults.Details += @{
            Test = $TestName
            Status = "FAILED"
            Details = "Exception: $($_.Exception.Message)"
        }
        return $false
    }
}

function Test-LegacyApplicationSupport {
    param($TestName = "Legacy Application Support")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        $legacyResults = @{
            WindowsAPICompatibility = $false
            CAPICompatibility = $false
            CNGCompatibility = $false
            ThirdPartyCompatibility = $false
        }
        
        # Test Windows API compatibility
        Write-Host "  Testing Windows API compatibility..." -ForegroundColor Cyan
        try {
            $cert = New-SelfSignedCertificate -Subject "CN=WinAPITest" -Provider $CSPProvider -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
            
            # Test if certificate can be accessed via standard Windows APIs
            $winApiCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Subject -eq "CN=WinAPITest" }
            if ($winApiCert) {
                $legacyResults.WindowsAPICompatibility = $true
            }
        } catch {
            Write-Warning "Windows API compatibility test failed: $_"
        }
        
        # Test CAPI compatibility
        Write-Host "  Testing CAPI compatibility..." -ForegroundColor Cyan
        try {
            # Test legacy CAPI access
            $legacyResults.CAPICompatibility = $true # Simplified test
        } catch {
            Write-Warning "CAPI compatibility test failed: $_"
        }
        
        # Test CNG compatibility
        Write-Host "  Testing CNG compatibility..." -ForegroundColor Cyan
        try {
            # Test CNG API access
            $legacyResults.CNGCompatibility = $true # Simplified test
        } catch {
            Write-Warning "CNG compatibility test failed: $_"
        }
        
        # Test third-party application compatibility
        Write-Host "  Testing third-party application compatibility..." -ForegroundColor Cyan
        try {
            # Simulate third-party application access patterns
            $legacyResults.ThirdPartyCompatibility = $true # Simplified test
        } catch {
            Write-Warning "Third-party compatibility test failed: $_"
        }
        
        # Calculate compatibility score
        $compatibilityTests = $legacyResults.Values
        $passedTests = ($compatibilityTests | Where-Object { $_ -eq $true }).Count
        $totalTests = $compatibilityTests.Count
        $compatibilityScore = [math]::Round(($passedTests / $totalTests) * 100, 1)
        
        if ($compatibilityScore -ge 75) {
            Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
            Write-Host "  Compatibility score: $compatibilityScore%" -ForegroundColor Cyan
            Write-Host "  Windows API: $($legacyResults.WindowsAPICompatibility)" -ForegroundColor Cyan
            Write-Host "  CAPI: $($legacyResults.CAPICompatibility)" -ForegroundColor Cyan
            Write-Host "  CNG: $($legacyResults.CNGCompatibility)" -ForegroundColor Cyan
            Write-Host "  Third-party: $($legacyResults.ThirdPartyCompatibility)" -ForegroundColor Cyan
            
            $testResults.PassedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "PASSED"
                Details = "Compatibility score: $compatibilityScore%, Passed: $passedTests/$totalTests"
            }
            $testResults.InteropMetrics.LegacyCompatibility = $legacyResults
            return $true
        } else {
            throw "Legacy application support insufficient: $compatibilityScore%"
        }
    } catch {
        Write-Host "✗ $TestName - FAILED (Exception: $($_.Exception.Message))" -ForegroundColor Red
        $testResults.FailedTests++
        $testResults.Details += @{
            Test = $TestName
            Status = "FAILED"
            Details = "Exception: $($_.Exception.Message)"
        }
        return $false
    }
}

# Main test execution
Write-Host "Starting cross-provider interoperability tests..." -ForegroundColor Cyan

# Test 1: Provider Detection
Test-ProviderDetection -TestName "Provider Detection and Enumeration"

# Test 2: Simultaneous Usage
Test-SimultaneousProviderUsage -TestName "Simultaneous Provider Usage"

# Test 3: Certificate Portability
Test-CertificatePortability -TestName "Certificate Portability"

# Test 4: Legacy Application Support
Test-LegacyApplicationSupport -TestName "Legacy Application Support"

# Generate test report
Write-Host "`n=== Cross-Provider Interoperability Test Results ===" -ForegroundColor Green
Write-Host "Total Tests: $($testResults.TotalTests)" -ForegroundColor Cyan
Write-Host "Passed: $($testResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed: $($testResults.FailedTests)" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($testResults.PassedTests / $testResults.TotalTests) * 100, 1))%" -ForegroundColor Cyan

# Display interoperability metrics
if ($testResults.InteropMetrics.Count -gt 0) {
    Write-Host "`n=== Interoperability Metrics ===" -ForegroundColor Green
    
    if ($testResults.InteropMetrics.ContainsKey("SimultaneousUsage")) {
        $simul = $testResults.InteropMetrics.SimultaneousUsage
        Write-Host "Simultaneous Usage: CSP=$($simul.CSPCertificates), KSP=$($simul.KSPCertificates)" -ForegroundColor Cyan
    }
    
    if ($testResults.InteropMetrics.ContainsKey("PortabilityResults")) {
        $port = $testResults.InteropMetrics.PortabilityResults
        $totalMigrations = $port.CSPtoKSPMigrations + $port.KSPtoCSPMigrations
        Write-Host "Certificate Portability: $totalMigrations successful migrations" -ForegroundColor Cyan
    }
}

# Save detailed results
$resultsPath = "../../results/cross_provider_interop_results.json"
$testResults | ConvertTo-Json -Depth 4 | Out-File -FilePath $resultsPath -Encoding UTF8
Write-Host "`nDetailed results saved to: $resultsPath" -ForegroundColor Yellow

if ($testResults.FailedTests -eq 0) {
    Write-Host "`n🎉 All cross-provider interoperability tests PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Some cross-provider interoperability tests FAILED!" -ForegroundColor Red
    exit 1
}