# SQL Server Integration Test Scenarios for CSP Provider
# Tests TDE, Always Encrypted, and database encryption scenarios

param(
    [string]$ServerName = "localhost",
    [string]$DatabaseName = "SupacryptTestDB",
    [string]$InstanceName = "MSSQLSERVER",
    [int]$PerformanceTestRows = 10000
)

$ErrorActionPreference = "Stop"

Write-Host "=== SQL Server Integration Tests for CSP Provider ===" -ForegroundColor Green

# Test results tracking
$testResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Details = @()
}

function Test-SqlConnection {
    param($ServerInstance, $TestName = "SQL Server Connection")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        $query = "SELECT @@VERSION as SQLVersion, GETDATE() as CurrentTime"
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $query -TrustServerCertificate -ErrorAction Stop
        
        Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
        Write-Host "  SQL Version: $($result.SQLVersion.Split([Environment]::NewLine)[0])" -ForegroundColor Cyan
        
        $testResults.PassedTests++
        $testResults.Details += @{
            Test = $TestName
            Status = "PASSED"
            Details = "Connected successfully to $ServerInstance"
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

function Test-TDESetup {
    param($ServerInstance, $DatabaseName, $TestName = "TDE Setup and Configuration")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        # Read and execute TDE setup script
        $scriptPath = "../../test_data/sql_scripts/tde_setup.sql"
        if (Test-Path $scriptPath) {
            $script = Get-Content $scriptPath -Raw
            $script = $script -replace '\$DatabaseName', $DatabaseName
            
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $script -TrustServerCertificate -QueryTimeout 300
            
            # Verify TDE is enabled
            $verifyQuery = @"
SELECT 
    db_name(database_id) as DatabaseName,
    encryption_state,
    encryption_state_desc,
    percent_complete
FROM sys.dm_database_encryption_keys
WHERE database_id = DB_ID('$DatabaseName')
"@
            
            $tdeStatus = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $verifyQuery -TrustServerCertificate
            
            if ($tdeStatus -and $tdeStatus.encryption_state -ge 2) {
                Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
                Write-Host "  TDE State: $($tdeStatus.encryption_state_desc)" -ForegroundColor Cyan
                Write-Host "  Completion: $($tdeStatus.percent_complete)%" -ForegroundColor Cyan
                
                $testResults.PassedTests++
                $testResults.Details += @{
                    Test = $TestName
                    Status = "PASSED"
                    Details = "TDE enabled, state: $($tdeStatus.encryption_state_desc)"
                }
                return $true
            } else {
                throw "TDE not properly enabled"
            }
        } else {
            throw "TDE setup script not found at $scriptPath"
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

function Test-AlwaysEncrypted {
    param($ServerInstance, $DatabaseName, $TestName = "Always Encrypted Setup")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        # Read and execute Always Encrypted setup script
        $scriptPath = "../../test_data/sql_scripts/always_encrypted_setup.sql"
        if (Test-Path $scriptPath) {
            $script = Get-Content $scriptPath -Raw
            $script = $script -replace '\$DatabaseName', $DatabaseName
            
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $script -Database $DatabaseName -TrustServerCertificate -QueryTimeout 300
            
            # Verify Always Encrypted objects
            $verifyQuery = @"
SELECT 
    (SELECT COUNT(*) FROM sys.column_master_keys) as MasterKeys,
    (SELECT COUNT(*) FROM sys.column_encryption_keys) as EncryptionKeys,
    (SELECT COUNT(*) FROM sys.tables WHERE name = 'EncryptedTestData') as EncryptedTables
"@
            
            $aeStatus = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $verifyQuery -Database $DatabaseName -TrustServerCertificate
            
            if ($aeStatus.MasterKeys -gt 0 -and $aeStatus.EncryptionKeys -gt 0 -and $aeStatus.EncryptedTables -gt 0) {
                Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
                Write-Host "  Master Keys: $($aeStatus.MasterKeys)" -ForegroundColor Cyan
                Write-Host "  Encryption Keys: $($aeStatus.EncryptionKeys)" -ForegroundColor Cyan
                Write-Host "  Encrypted Tables: $($aeStatus.EncryptedTables)" -ForegroundColor Cyan
                
                $testResults.PassedTests++
                $testResults.Details += @{
                    Test = $TestName
                    Status = "PASSED"
                    Details = "Always Encrypted configured successfully"
                }
                return $true
            } else {
                throw "Always Encrypted objects not created properly"
            }
        } else {
            throw "Always Encrypted setup script not found at $scriptPath"
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

function Test-EncryptedDataOperations {
    param($ServerInstance, $DatabaseName, $RowCount, $TestName = "Encrypted Data Operations")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName with $RowCount rows" -ForegroundColor Yellow
        
        # Insert test data
        $insertQuery = @"
DECLARE @i int = 1;
WHILE @i <= $RowCount
BEGIN
    INSERT INTO EncryptedTestData (PlainTextData, EncryptedData, RandomEncryptedData)
    VALUES (
        'Plain text data ' + CAST(@i as nvarchar(10)),
        'Encrypted data ' + CAST(@i as nvarchar(10)),
        'Random encrypted data ' + CAST(@i as nvarchar(10))
    );
    SET @i = @i + 1;
END
"@
        
        $startTime = Get-Date
        Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $insertQuery -Database $DatabaseName -TrustServerCertificate -QueryTimeout 600
        $insertDuration = (Get-Date) - $startTime
        
        # Query encrypted data
        $queryStart = Get-Date
        $selectQuery = "SELECT COUNT(*) as RecordCount FROM EncryptedTestData"
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $selectQuery -Database $DatabaseName -TrustServerCertificate
        $queryDuration = (Get-Date) - $queryStart
        
        # Performance metrics
        $insertRate = [math]::Round($RowCount / $insertDuration.TotalSeconds, 2)
        
        Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
        Write-Host "  Records inserted: $($result.RecordCount)" -ForegroundColor Cyan
        Write-Host "  Insert duration: $([math]::Round($insertDuration.TotalSeconds, 2)) seconds" -ForegroundColor Cyan
        Write-Host "  Insert rate: $insertRate records/second" -ForegroundColor Cyan
        Write-Host "  Query duration: $([math]::Round($queryDuration.TotalMilliseconds, 2)) ms" -ForegroundColor Cyan
        
        $testResults.PassedTests++
        $testResults.Details += @{
            Test = $TestName
            Status = "PASSED"
            Details = "Rows: $($result.RecordCount), Insert rate: $insertRate/sec, Query time: $([math]::Round($queryDuration.TotalMilliseconds, 2))ms"
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

function Test-EncryptedBackup {
    param($ServerInstance, $DatabaseName, $TestName = "Encrypted Backup Operations")
    
    $testResults.TotalTests++
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        
        $backupPath = "C:\Temp\SupacryptTestBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
        
        # Execute backup test procedure
        $backupQuery = @"
DECLARE @BackupPath nvarchar(500) = '$backupPath';

-- Perform encrypted backup
BACKUP DATABASE [$DatabaseName]
TO DISK = @BackupPath
WITH ENCRYPTION (
    ALGORITHM = AES_256,
    SERVER_CERTIFICATE = SupacryptTDECert
), COMPRESSION, INIT;

-- Verify backup
RESTORE VERIFYONLY FROM DISK = @BackupPath;

SELECT @BackupPath as BackupPath;
"@
        
        $startTime = Get-Date
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $backupQuery -TrustServerCertificate -QueryTimeout 600
        $backupDuration = (Get-Date) - $startTime
        
        # Check if backup file exists and get size
        if (Test-Path $backupPath) {
            $backupFile = Get-Item $backupPath
            $backupSizeMB = [math]::Round($backupFile.Length / 1MB, 2)
            
            Write-Host "✓ $TestName - PASSED" -ForegroundColor Green
            Write-Host "  Backup path: $backupPath" -ForegroundColor Cyan
            Write-Host "  Backup size: $backupSizeMB MB" -ForegroundColor Cyan
            Write-Host "  Backup duration: $([math]::Round($backupDuration.TotalSeconds, 2)) seconds" -ForegroundColor Cyan
            
            $testResults.PassedTests++
            $testResults.Details += @{
                Test = $TestName
                Status = "PASSED"
                Details = "Size: $backupSizeMB MB, Duration: $([math]::Round($backupDuration.TotalSeconds, 2))s"
            }
            
            # Cleanup backup file
            Remove-Item $backupPath -Force
            return $true
        } else {
            throw "Backup file not created at expected location"
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
Write-Host "Starting SQL Server integration tests..." -ForegroundColor Cyan

# Test 1: Basic SQL Server connectivity
Test-SqlConnection -ServerInstance $ServerName -TestName "SQL Server Connectivity"

# Test 2: TDE setup and configuration
Test-TDESetup -ServerInstance $ServerName -DatabaseName $DatabaseName -TestName "TDE Configuration"

# Test 3: Always Encrypted setup
Test-AlwaysEncrypted -ServerInstance $ServerName -DatabaseName $DatabaseName -TestName "Always Encrypted Setup"

# Test 4: Encrypted data operations
Test-EncryptedDataOperations -ServerInstance $ServerName -DatabaseName $DatabaseName -RowCount $PerformanceTestRows -TestName "Encrypted Data Operations"

# Test 5: Encrypted backup operations
Test-EncryptedBackup -ServerInstance $ServerName -DatabaseName $DatabaseName -TestName "Encrypted Backup Operations"

# Generate test report
Write-Host "`n=== SQL Server Integration Test Results ===" -ForegroundColor Green
Write-Host "Total Tests: $($testResults.TotalTests)" -ForegroundColor Cyan
Write-Host "Passed: $($testResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed: $($testResults.FailedTests)" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($testResults.PassedTests / $testResults.TotalTests) * 100, 1))%" -ForegroundColor Cyan

# Save detailed results
$resultsPath = "../../results/sql_server_integration_results.json"
$testResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $resultsPath -Encoding UTF8
Write-Host "Detailed results saved to: $resultsPath" -ForegroundColor Yellow

if ($testResults.FailedTests -eq 0) {
    Write-Host "`n🎉 All SQL Server integration tests PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Some SQL Server integration tests FAILED!" -ForegroundColor Red
    exit 1
}