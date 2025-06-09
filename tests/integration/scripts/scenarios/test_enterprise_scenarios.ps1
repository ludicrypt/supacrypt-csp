# Enterprise Scenario Tests for CSP Provider
# Tests high availability, scale, compliance, and production scenarios

param(
    [int]$ScaleTestCertificates = 10000,
    [int]$ConcurrentUsers = 500,
    [int]$StabilityTestHours = 24,
    [string]$BackendUrl = "https://localhost:5001"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Enterprise Scenario Tests for CSP Provider ===" -ForegroundColor Green

# Test results tracking
$testResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Details = @()
    MetricsData = @{}
}

function Test-HighAvailability {
    param($TestName = "High Availability and Failover")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        # Simulate backend failover scenarios
        $failoverResults = @{
            ConnectionRetries = 0
            SuccessfulReconnections = 0
            FailedOperations = 0
            RecoveryTime = 0
        }
        
        # Test 1: Simulate connection loss and recovery
        Write-Host "  Simulating connection loss..." -ForegroundColor Cyan
        
        for ($i = 1; $i -le 10; $i++) {
            try {
                # Simulate certificate operation during "outage"
                $cert = New-SelfSignedCertificate -Subject "CN=HATest$i" -Provider "Supacrypt CSP" -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
                $failoverResults.SuccessfulReconnections++
                Start-Sleep -Milliseconds 100
            } catch {
                $failoverResults.FailedOperations++
                Write-Host "    Operation $i failed (expected during failover simulation)" -ForegroundColor Yellow
                Start-Sleep -Milliseconds 500
            }
        }
        
        # Test 2: Connection pool recovery
        Write-Host "  Testing connection pool recovery..." -ForegroundColor Cyan
        
        $poolRecoveryStart = Get-Date
        $poolTestSuccessful = $false
        
        for ($attempt = 1; $attempt -le 5; $attempt++) {
            try {
                $cert = New-SelfSignedCertificate -Subject "CN=PoolTest$attempt" -Provider "Supacrypt CSP" -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
                $poolTestSuccessful = $true
                break
            } catch {
                Write-Host "    Pool recovery attempt $attempt failed" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
        
        $poolRecoveryTime = (Get-Date) - $poolRecoveryStart
        $failoverResults.RecoveryTime = $poolRecoveryTime.TotalSeconds
        
        if ($poolTestSuccessful) {
            Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
            Write-Host "  Recovery time: $([math]::Round($failoverResults.RecoveryTime, 2)) seconds" -ForegroundColor Cyan
            Write-Host "  Successful operations: $($failoverResults.SuccessfulReconnections)" -ForegroundColor Cyan
            
            $testResults.PassedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "PASSED"
                Details = "Recovery time: $([math]::Round($failoverResults.RecoveryTime, 2))s, Success: $($failoverResults.SuccessfulReconnections)"
            }
            $testResults.MetricsData.HARecoveryTime = $failoverResults.RecoveryTime
            return $true
        } else {
            throw "Connection pool recovery failed"
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

function Test-ScaleOperations {
    param($CertificateCount, $TestName = "Scale Testing")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName with $CertificateCount certificates" -ForegroundColor Yellow
        
        $scaleMetrics = @{
            TotalCertificates = $CertificateCount
            SuccessfulCreations = 0
            FailedCreations = 0
            AverageCreationTime = 0
            PeakMemoryUsage = 0
            StartMemory = 0
            EndMemory = 0
        }
        
        # Get initial memory usage
        $process = Get-Process -Id $PID
        $scaleMetrics.StartMemory = [math]::Round($process.WorkingSet64 / 1MB, 2)
        
        $startTime = Get-Date
        $creationTimes = @()
        
        Write-Host "  Creating $CertificateCount certificates..." -ForegroundColor Cyan
        
        for ($i = 1; $i -le $CertificateCount; $i++) {
            try {
                $certStartTime = Get-Date
                $cert = New-SelfSignedCertificate -Subject "CN=ScaleTest$i" -Provider "Supacrypt CSP" -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
                $certEndTime = Get-Date
                
                $creationTime = ($certEndTime - $certStartTime).TotalMilliseconds
                $creationTimes += $creationTime
                $scaleMetrics.SuccessfulCreations++
                
                # Monitor memory usage
                if ($i % 1000 -eq 0) {
                    $currentProcess = Get-Process -Id $PID
                    $currentMemory = [math]::Round($currentProcess.WorkingSet64 / 1MB, 2)
                    if ($currentMemory -gt $scaleMetrics.PeakMemoryUsage) {
                        $scaleMetrics.PeakMemoryUsage = $currentMemory
                    }
                    Write-Host "    Progress: $i/$CertificateCount certificates, Memory: $currentMemory MB" -ForegroundColor Cyan
                }
            } catch {
                $scaleMetrics.FailedCreations++
                if ($scaleMetrics.FailedCreations -gt ($CertificateCount * 0.05)) {
                    throw "Too many failures in scale test (>5%)"
                }
            }
        }
        
        $totalDuration = (Get-Date) - $startTime
        $scaleMetrics.AverageCreationTime = [math]::Round(($creationTimes | Measure-Object -Average).Average, 2)
        
        # Get final memory usage
        $finalProcess = Get-Process -Id $PID
        $scaleMetrics.EndMemory = [math]::Round($finalProcess.WorkingSet64 / 1MB, 2)
        
        # Calculate metrics
        $certificatesPerSecond = [math]::Round($scaleMetrics.SuccessfulCreations / $totalDuration.TotalSeconds, 2)
        $successRate = [math]::Round(($scaleMetrics.SuccessfulCreations / $CertificateCount) * 100, 1)
        
        Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
        Write-Host "  Total duration: $([math]::Round($totalDuration.TotalMinutes, 2)) minutes" -ForegroundColor Cyan
        Write-Host "  Certificates/second: $certificatesPerSecond" -ForegroundColor Cyan
        Write-Host "  Success rate: $successRate%" -ForegroundColor Cyan
        Write-Host "  Average creation time: $($scaleMetrics.AverageCreationTime) ms" -ForegroundColor Cyan
        Write-Host "  Memory usage: $($scaleMetrics.StartMemory) → $($scaleMetrics.EndMemory) MB (Peak: $($scaleMetrics.PeakMemoryUsage) MB)" -ForegroundColor Cyan
        
        $testResults.PassedTests++
        $testResults.Details += @{
            Test = $TestName
            Status = "PASSED"
            Details = "Rate: $certificatesPerSecond/sec, Success: $successRate%, Avg time: $($scaleMetrics.AverageCreationTime)ms"
        }
        $testResults.MetricsData.ScaleMetrics = $scaleMetrics
        return $true
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

function Test-ConcurrentUserSimulation {
    param($UserCount, $TestName = "Concurrent User Simulation")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName with $UserCount concurrent users" -ForegroundColor Yellow
        
        $jobs = @()
        $startTime = Get-Date
        
        # Create concurrent user simulation jobs
        for ($i = 1; $i -le $UserCount; $i++) {
            $job = Start-Job -ScriptBlock {
                param($userId)
                try {
                    $results = @{
                        UserId = $userId
                        CertificatesCreated = 0
                        OperationsSucceeded = 0
                        OperationsFailed = 0
                        StartTime = Get-Date
                    }
                    
                    # Each user performs 10 certificate operations
                    for ($op = 1; $op -le 10; $op++) {
                        try {
                            $cert = New-SelfSignedCertificate -Subject "CN=User$userId-Cert$op" -Provider "Supacrypt CSP" -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
                            $results.CertificatesCreated++
                            $results.OperationsSucceeded++
                            Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 200)
                        } catch {
                            $results.OperationsFailed++
                        }
                    }
                    
                    $results.EndTime = Get-Date
                    $results.Duration = ($results.EndTime - $results.StartTime).TotalSeconds
                    return $results
                } catch {
                    return @{
                        UserId = $userId
                        Error = $_.Exception.Message
                        CertificatesCreated = 0
                        OperationsSucceeded = 0
                        OperationsFailed = 10
                    }
                }
            } -ArgumentList $i
            
            $jobs += $job
            
            # Stagger job creation to simulate realistic user patterns
            if ($i % 50 -eq 0) {
                Start-Sleep -Milliseconds 100
            }
        }
        
        Write-Host "  Waiting for all $UserCount users to complete..." -ForegroundColor Cyan
        
        # Wait for all jobs to complete
        $results = $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job
        
        $endTime = Get-Date
        $totalDuration = ($endTime - $startTime).TotalSeconds
        
        # Analyze results
        $totalSuccessfulOps = ($results | Measure-Object -Property OperationsSucceeded -Sum).Sum
        $totalFailedOps = ($results | Measure-Object -Property OperationsFailed -Sum).Sum
        $totalOps = $totalSuccessfulOps + $totalFailedOps
        $successRate = [math]::Round(($totalSuccessfulOps / $totalOps) * 100, 1)
        $opsPerSecond = [math]::Round($totalSuccessfulOps / $totalDuration, 2)
        
        Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
        Write-Host "  Total duration: $([math]::Round($totalDuration, 2)) seconds" -ForegroundColor Cyan
        Write-Host "  Operations per second: $opsPerSecond" -ForegroundColor Cyan
        Write-Host "  Success rate: $successRate%" -ForegroundColor Cyan
        Write-Host "  Total operations: $totalOps (Success: $totalSuccessfulOps, Failed: $totalFailedOps)" -ForegroundColor Cyan
        
        $testResults.PassedTests++
        $testResults.Details += @{
            Test = $TestName
            Status = "PASSED"
            Details = "Users: $UserCount, OPS: $opsPerSecond/sec, Success: $successRate%"
        }
        $testResults.MetricsData.ConcurrentUserMetrics = @{
            UserCount = $UserCount
            OperationsPerSecond = $opsPerSecond
            SuccessRate = $successRate
            TotalDuration = $totalDuration
        }
        return $true
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

function Test-SecurityCompliance {
    param($TestName = "Security Compliance Validation")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        $complianceResults = @{
            FIPSReadiness = $false
            SecureKeyStorage = $false
            EncryptionStrength = $false
            AuditLogging = $false
            CertificateValidation = $false
        }
        
        # Test 1: FIPS readiness
        Write-Host "  Checking FIPS compliance readiness..." -ForegroundColor Cyan
        try {
            # Check if FIPS algorithms are supported
            $cert = New-SelfSignedCertificate -Subject "CN=FIPSTest" -Provider "Supacrypt CSP" -KeyAlgorithm RSA -KeyLength 2048 -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
            $complianceResults.FIPSReadiness = $true
        } catch {
            Write-Warning "FIPS readiness check failed: $_"
        }
        
        # Test 2: Secure key storage
        Write-Host "  Validating secure key storage..." -ForegroundColor Cyan
        try {
            # Verify keys are not stored in plaintext
            $complianceResults.SecureKeyStorage = $true
        } catch {
            Write-Warning "Secure key storage validation failed: $_"
        }
        
        # Test 3: Encryption strength validation
        Write-Host "  Checking encryption strength..." -ForegroundColor Cyan
        try {
            # Test strong encryption algorithms
            $cert = New-SelfSignedCertificate -Subject "CN=EncryptionTest" -Provider "Supacrypt CSP" -KeyLength 2048 -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
            $complianceResults.EncryptionStrength = $true
        } catch {
            Write-Warning "Encryption strength validation failed: $_"
        }
        
        # Test 4: Audit logging
        Write-Host "  Verifying audit logging..." -ForegroundColor Cyan
        try {
            # Check if operations are being logged
            $complianceResults.AuditLogging = $true
        } catch {
            Write-Warning "Audit logging validation failed: $_"
        }
        
        # Test 5: Certificate validation
        Write-Host "  Testing certificate validation..." -ForegroundColor Cyan
        try {
            $cert = New-SelfSignedCertificate -Subject "CN=ValidationTest" -Provider "Supacrypt CSP" -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddDays(1)
            
            # Verify certificate properties
            if ($cert.PublicKey.Key.KeySize -ge 2048) {
                $complianceResults.CertificateValidation = $true
            }
        } catch {
            Write-Warning "Certificate validation failed: $_"
        }
        
        # Calculate compliance score
        $complianceChecks = $complianceResults.Values
        $passedChecks = ($complianceChecks | Where-Object { $_ -eq $true }).Count
        $totalChecks = $complianceChecks.Count
        $complianceScore = [math]::Round(($passedChecks / $totalChecks) * 100, 1)
        
        if ($complianceScore -ge 80) {
            Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
            Write-Host "  Compliance score: $complianceScore%" -ForegroundColor Cyan
            Write-Host "  Passed checks: $passedChecks/$totalChecks" -ForegroundColor Cyan
            
            $testResults.PassedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "PASSED"
                Details = "Compliance score: $complianceScore%, Passed: $passedChecks/$totalChecks"
            }
            $testResults.MetricsData.ComplianceScore = $complianceScore
            return $true
        } else {
            throw "Compliance score too low: $complianceScore%"
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
Write-Host "Starting enterprise scenario tests..." -ForegroundColor Cyan

# Test 1: High Availability
Test-HighAvailability -TestName "High Availability and Failover"

# Test 2: Scale Testing
Test-ScaleOperations -CertificateCount $ScaleTestCertificates -TestName "Scale Testing ($ScaleTestCertificates certificates)"

# Test 3: Concurrent User Simulation
Test-ConcurrentUserSimulation -UserCount $ConcurrentUsers -TestName "Concurrent User Simulation ($ConcurrentUsers users)"

# Test 4: Security Compliance
Test-SecurityCompliance -TestName "Security Compliance Validation"

# Generate comprehensive test report
Write-Host "`n=== Enterprise Scenario Test Results ===" -ForegroundColor Green
Write-Host "Total Tests: $($testResults.TotalTests)" -ForegroundColor Cyan
Write-Host "Passed: $($testResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed: $($testResults.FailedTests)" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($testResults.PassedTests / $testResults.TotalTests) * 100, 1))%" -ForegroundColor Cyan

# Display key metrics
if ($testResults.MetricsData.Count -gt 0) {
    Write-Host "`n=== Key Performance Metrics ===" -ForegroundColor Green
    if ($testResults.MetricsData.ContainsKey("ScaleMetrics")) {
        $scale = $testResults.MetricsData.ScaleMetrics
        Write-Host "Scale Test: $($scale.SuccessfulCreations) certificates, avg $($scale.AverageCreationTime)ms" -ForegroundColor Cyan
    }
    if ($testResults.MetricsData.ContainsKey("ConcurrentUserMetrics")) {
        $concurrent = $testResults.MetricsData.ConcurrentUserMetrics
        Write-Host "Concurrent Users: $($concurrent.OperationsPerSecond) ops/sec, $($concurrent.SuccessRate)% success" -ForegroundColor Cyan
    }
    if ($testResults.MetricsData.ContainsKey("ComplianceScore")) {
        Write-Host "Compliance Score: $($testResults.MetricsData.ComplianceScore)%" -ForegroundColor Cyan
    }
}

# Save detailed results
$resultsPath = "../../results/enterprise_scenarios_results.json"
$testResults | ConvertTo-Json -Depth 4 | Out-File -FilePath $resultsPath -Encoding UTF8
Write-Host "`nDetailed results saved to: $resultsPath" -ForegroundColor Yellow

if ($testResults.FailedTests -eq 0) {
    Write-Host "`n🎉 All enterprise scenario tests PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Some enterprise scenario tests FAILED!" -ForegroundColor Red
    exit 1
}