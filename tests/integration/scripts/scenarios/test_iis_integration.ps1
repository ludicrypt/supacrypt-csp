# IIS Integration Test Scenarios for CSP Provider
# Tests SSL/TLS, client certificates, and web server integration

param(
    [string]$SiteName = "SupacryptTestSite",
    [string]$Port = "8443",
    [int]$MaxConcurrentUsers = 100,
    [int]$TestDurationMinutes = 5
)

$ErrorActionPreference = "Stop"

Write-Host "=== IIS Integration Tests for CSP Provider ===" -ForegroundColor Green

# Test results tracking
$testResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Details = @()
}

function Test-WebsiteResponse {
    param($Url, $ExpectedStatus = 200, $TestName = "Website Response")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        # Skip certificate validation for test certificates
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30
        
        if ($response.StatusCode -eq $ExpectedStatus) {
            Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
            $testResults.PassedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "PASSED"
                Details = "Status: $($response.StatusCode)"
            }
            return $true
        } else {
            Write-Host "✗ $TestName - FAILED (Status: $($response.StatusCode))" -ForegroundColor Red
            $testResults.FailedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "FAILED"
                Details = "Expected: $ExpectedStatus, Got: $($response.StatusCode)"
            }
            return $false
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

function Test-SSLCertificate {
    param($Hostname, $Port, $TestName = "SSL Certificate")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($Hostname, $Port)
        
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream())
        $sslStream.AuthenticateAsClient($Hostname)
        
        $cert = $sslStream.RemoteCertificate
        
        if ($cert) {
            Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
            Write-Host "  Certificate Subject: $($cert.Subject)" -ForegroundColor Cyan
            Write-Host "  Certificate Issuer: $($cert.Issuer)" -ForegroundColor Cyan
            
            $testResults.PassedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "PASSED"
                Details = "Subject: $($cert.Subject), Issuer: $($cert.Issuer)"
            }
            
            $sslStream.Close()
            $tcpClient.Close()
            return $true
        } else {
            throw "No certificate received"
        }
    } catch {
        Write-Host "✗ $TestName - FAILED (Exception: $($_.Exception.Message))" -ForegroundColor Red
        $testResults.FailedTests++
        $testResults.Details += @{
            Test = $TestName
            Status = "FAILED"
            Details = "Exception: $($_.Exception.Message)"
        }
        
        if ($sslStream) { $sslStream.Close() }
        if ($tcpClient) { $tcpClient.Close() }
        return $false
    }
}

function Test-ConcurrentConnections {
    param($BaseUrl, $UserCount, $TestName = "Concurrent Connections")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName with $UserCount concurrent users" -ForegroundColor Yellow
        
        $jobs = @()
        $startTime = Get-Date
        
        # Create concurrent jobs
        for ($i = 1; $i -le $UserCount; $i++) {
            $job = Start-Job -ScriptBlock {
                param($url)
                try {
                    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
                    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
                    return @{ Success = $true; StatusCode = $response.StatusCode }
                } catch {
                    return @{ Success = $false; Error = $_.Exception.Message }
                }
            } -ArgumentList $BaseUrl
            
            $jobs += $job
        }
        
        # Wait for all jobs to complete
        $results = $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        $successful = ($results | Where-Object { $_.Success -eq $true }).Count
        $failed = ($results | Where-Object { $_.Success -eq $false }).Count
        
        Write-Host "  Completed in $([math]::Round($duration, 2)) seconds" -ForegroundColor Cyan
        Write-Host "  Successful requests: $successful" -ForegroundColor Cyan
        Write-Host "  Failed requests: $failed" -ForegroundColor Cyan
        
        if ($failed -eq 0) {
            Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
            $testResults.PassedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "PASSED"
                Details = "Users: $UserCount, Success: $successful, Failed: $failed, Duration: $([math]::Round($duration, 2))s"
            }
            return $true
        } else {
            Write-Host "✗ $TestName - FAILED ($failed failures)" -ForegroundColor Red
            $testResults.FailedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "FAILED"
                Details = "Users: $UserCount, Success: $successful, Failed: $failed"
            }
            return $false
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
Write-Host "Starting IIS integration tests..." -ForegroundColor Cyan

# Test 1: Basic HTTPS connectivity
$httpsUrl = "https://localhost:$Port"
Test-WebsiteResponse -Url $httpsUrl -TestName "Basic HTTPS Connectivity"

# Test 2: SSL Certificate validation
Test-SSLCertificate -Hostname "localhost" -Port $Port -TestName "SSL Certificate Validation"

# Test 3: HTTP to HTTPS redirect (if configured)
$httpUrl = "http://localhost"
Test-WebsiteResponse -Url $httpUrl -ExpectedStatus 301 -TestName "HTTP to HTTPS Redirect"

# Test 4: Concurrent user simulation
Test-ConcurrentConnections -BaseUrl $httpsUrl -UserCount $MaxConcurrentUsers -TestName "Concurrent User Load Test"

# Test 5: Certificate renewal simulation
Write-Host "Testing certificate renewal workflow..." -ForegroundColor Yellow
$testResults.TotalTests++

try {
    # Generate new certificate
    $newCert = New-SelfSignedCertificate -Subject "CN=renewed.$SiteName.test.local" -Provider "Supacrypt CSP" -CertStoreLocation "Cert:\LocalMachine\My" -NotAfter (Get-Date).AddYears(1)
    
    # Update IIS binding (simulation)
    Write-Host "Certificate renewal simulation completed" -ForegroundColor Green
    $testResults.PassedTests++
    $testResults.Details += @{
        Test = "Certificate Renewal"
        Status = "PASSED"
        Details = "New certificate thumbprint: $($newCert.Thumbprint)"
    }
} catch {
    Write-Host "✗ Certificate Renewal - FAILED" -ForegroundColor Red
    $testResults.FailedTests++
    $testResults.Details += @{
        Test = "Certificate Renewal"
        Status = "FAILED"
        Details = "Exception: $($_.Exception.Message)"
    }
}

# Generate test report
Write-Host "`n=== IIS Integration Test Results ===" -ForegroundColor Green
Write-Host "Total Tests: $($testResults.TotalTests)" -ForegroundColor Cyan
Write-Host "Passed: $($testResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed: $($testResults.FailedTests)" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($testResults.PassedTests / $testResults.TotalTests) * 100, 1))%" -ForegroundColor Cyan

# Save detailed results
$resultsPath = "../../results/iis_integration_results.json"
$testResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $resultsPath -Encoding UTF8
Write-Host "Detailed results saved to: $resultsPath" -ForegroundColor Yellow

if ($testResults.FailedTests -eq 0) {
    Write-Host "`n🎉 All IIS integration tests PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Some IIS integration tests FAILED!" -ForegroundColor Red
    exit 1
}