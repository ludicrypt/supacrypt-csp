# Supacrypt CSP Troubleshooting Guide

## Overview

This comprehensive troubleshooting guide provides solutions for common issues encountered when deploying and using the Supacrypt CSP provider in enterprise environments.

## Table of Contents

1. [Diagnostic Tools](#diagnostic-tools)
2. [Installation Issues](#installation-issues)
3. [Configuration Problems](#configuration-problems)
4. [Runtime Errors](#runtime-errors)
5. [Performance Issues](#performance-issues)
6. [Integration Problems](#integration-problems)
7. [Security Issues](#security-issues)
8. [Log Analysis](#log-analysis)
9. [Advanced Diagnostics](#advanced-diagnostics)

## Diagnostic Tools

### Built-in Diagnostics

```powershell
# Provider registration check
function Test-CSPProviderRegistration {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Cryptography\Defaults\Provider\Supacrypt CSP"
    if (Test-Path $regPath) {
        Write-Host "✅ CSP provider is registered" -ForegroundColor Green
        Get-ItemProperty $regPath | Format-List
        return $true
    } else {
        Write-Host "❌ CSP provider is NOT registered" -ForegroundColor Red
        return $false
    }
}

# Connectivity test
function Test-BackendConnectivity {
    param([string]$BackendUrl)
    
    try {
        $response = Invoke-WebRequest -Uri $BackendUrl -Method HEAD -TimeoutSec 10 -UseBasicParsing
        Write-Host "✅ Backend is reachable (Status: $($response.StatusCode))" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Backend is NOT reachable: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Certificate generation test
function Test-CertificateGeneration {
    try {
        $testCert = New-SelfSignedCertificate -Subject "CN=DiagnosticTest" -Provider "Supacrypt CSP" -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddMinutes(5)
        Write-Host "✅ Certificate generation successful" -ForegroundColor Green
        
        # Cleanup
        Remove-Item "Cert:\CurrentUser\My\$($testCert.Thumbprint)" -Force
        return $true
    } catch {
        Write-Host "❌ Certificate generation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}
```

### System Information Collection

```powershell
# Comprehensive system diagnostic
function Get-SystemDiagnostics {
    $diagnostics = @{
        Timestamp = Get-Date
        OSVersion = (Get-WmiObject Win32_OperatingSystem).Caption
        PowerShellVersion = $PSVersionTable.PSVersion
        Architecture = $env:PROCESSOR_ARCHITECTURE
        UserContext = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        DotNetVersions = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP" -Recurse | Get-ItemProperty -Name Version -ErrorAction SilentlyContinue | Select-Object Version
        CSPRegistration = Test-Path "HKLM:\SOFTWARE\Microsoft\Cryptography\Defaults\Provider\Supacrypt CSP"
        SupacryptConfig = Test-Path "HKLM:\SOFTWARE\Supacrypt\CSP"
    }
    
    return $diagnostics
}
```

## Installation Issues

### Issue: Provider DLL Not Found

**Symptoms:**
- Error: "The specified provider could not be found"
- Certificate generation fails immediately

**Diagnosis:**
```powershell
# Check if DLL exists in system directory
Test-Path "C:\Windows\System32\supacrypt-csp.dll"

# Check DLL architecture
[System.Reflection.AssemblyName]::GetAssemblyName("C:\Windows\System32\supacrypt-csp.dll").ProcessorArchitecture
```

**Solutions:**
1. **Verify DLL Location:**
   ```powershell
   # Copy DLL to correct location
   Copy-Item ".\supacrypt-csp.dll" "C:\Windows\System32\" -Force
   ```

2. **Check Architecture Match:**
   ```powershell
   # Ensure 64-bit DLL on 64-bit system
   # Rebuild if necessary with correct target architecture
   ```

3. **Verify Dependencies:**
   ```powershell
   # Check for missing dependencies
   dumpbin /dependents "C:\Windows\System32\supacrypt-csp.dll"
   ```

### Issue: Registry Registration Fails

**Symptoms:**
- Provider not visible in certificate management tools
- "Provider not found" errors

**Diagnosis:**
```powershell
# Check registry keys
$regPath = "HKLM:\SOFTWARE\Microsoft\Cryptography\Defaults\Provider\Supacrypt CSP"
Get-ItemProperty $regPath -ErrorAction SilentlyContinue
```

**Solutions:**
1. **Manual Registry Fix:**
   ```powershell
   # Re-register provider
   New-Item -Path $regPath -Force
   Set-ItemProperty -Path $regPath -Name "Image Path" -Value "C:\Windows\System32\supacrypt-csp.dll"
   Set-ItemProperty -Path $regPath -Name "Type" -Value 1
   Set-ItemProperty -Path $regPath -Name "SigInFile" -Value 0
   ```

2. **Run as Administrator:**
   - Ensure PowerShell is running as Administrator
   - Check UAC settings

### Issue: Permission Denied During Installation

**Symptoms:**
- "Access denied" errors during file copy
- Registry modification failures

**Solutions:**
1. **Elevate Privileges:**
   ```powershell
   # Run as Administrator
   if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
       Start-Process PowerShell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
       exit
   }
   ```

2. **Check File Permissions:**
   ```powershell
   # Set correct permissions
   icacls "C:\Windows\System32\supacrypt-csp.dll" /grant "Everyone:R"
   ```

## Configuration Problems

### Issue: Backend Connection Timeout

**Symptoms:**
- Certificate operations take too long
- Timeout errors in logs
- "Connection timeout" exceptions

**Diagnosis:**
```powershell
# Test network connectivity
Test-NetConnection -ComputerName "supacrypt-backend.company.com" -Port 443

# Check DNS resolution
Resolve-DnsName "supacrypt-backend.company.com"

# Test with different timeout values
Measure-Command { Invoke-WebRequest -Uri "https://supacrypt-backend.company.com" -TimeoutSec 30 }
```

**Solutions:**
1. **Increase Timeout Values:**
   ```powershell
   $configPath = "HKLM:\SOFTWARE\Supacrypt\CSP"
   Set-ItemProperty -Path $configPath -Name "Timeout" -Value 60000  # 60 seconds
   Set-ItemProperty -Path $configPath -Name "RetryAttempts" -Value 5
   ```

2. **Check Network Path:**
   ```powershell
   # Trace network route
   tracert supacrypt-backend.company.com
   
   # Check for proxy settings
   netsh winhttp show proxy
   ```

3. **Firewall Configuration:**
   ```powershell
   # Check Windows Firewall
   Get-NetFirewallRule -DisplayName "*Supacrypt*"
   
   # Add firewall rule if needed
   New-NetFirewallRule -DisplayName "Supacrypt CSP" -Direction Outbound -Protocol TCP -RemotePort 443 -Action Allow
   ```

### Issue: Invalid Backend URL

**Symptoms:**
- "Invalid URL" errors
- Certificate operations fail immediately
- DNS resolution failures

**Diagnosis:**
```powershell
# Check configured URL
$configPath = "HKLM:\SOFTWARE\Supacrypt\CSP"
$backendUrl = Get-ItemProperty $configPath -Name "BackendUrl" -ErrorAction SilentlyContinue
Write-Host "Configured URL: $($backendUrl.BackendUrl)"

# Validate URL format
try {
    $uri = [System.Uri]$backendUrl.BackendUrl
    Write-Host "URL is valid: $($uri.AbsoluteUri)"
} catch {
    Write-Host "Invalid URL format: $($_.Exception.Message)"
}
```

**Solutions:**
1. **Fix URL Format:**
   ```powershell
   # Correct URL format
   Set-ItemProperty -Path $configPath -Name "BackendUrl" -Value "https://supacrypt-backend.company.com:443"
   ```

2. **Verify SSL Certificate:**
   ```powershell
   # Test SSL certificate
   $cert = [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
   try {
       Invoke-WebRequest -Uri $backendUrl.BackendUrl -UseBasicParsing
   } catch {
       Write-Host "SSL/TLS error: $($_.Exception.Message)"
   }
   ```

## Runtime Errors

### Issue: Certificate Generation Fails

**Symptoms:**
- "Certificate generation failed" errors
- Empty certificate stores
- Application errors during certificate operations

**Diagnosis:**
```powershell
# Test with verbose logging
$configPath = "HKLM:\SOFTWARE\Supacrypt\CSP"
Set-ItemProperty -Path $configPath -Name "LogLevel" -Value "DEBUG"

# Attempt certificate generation with error handling
try {
    $cert = New-SelfSignedCertificate -Subject "CN=TestCert" -Provider "Supacrypt CSP" -CertStoreLocation "Cert:\CurrentUser\My" -ErrorAction Stop
    Write-Host "Success: Certificate created with thumbprint $($cert.Thumbprint)"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host "Inner Exception: $($_.Exception.InnerException.Message)"
}
```

**Solutions:**
1. **Check Backend Status:**
   ```powershell
   # Verify backend health
   $healthUrl = "$($backendUrl.BackendUrl)/health"
   try {
       $health = Invoke-RestMethod -Uri $healthUrl
       Write-Host "Backend health: $($health.status)"
   } catch {
       Write-Host "Backend health check failed: $($_.Exception.Message)"
   }
   ```

2. **Verify Certificate Parameters:**
   ```powershell
   # Try with different parameters
   $cert = New-SelfSignedCertificate -Subject "CN=TestCert" -Provider "Supacrypt CSP" -KeyLength 2048 -KeyAlgorithm RSA -CertStoreLocation "Cert:\CurrentUser\My"
   ```

3. **Check Certificate Store Permissions:**
   ```powershell
   # Verify store access
   try {
       $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "CurrentUser")
       $store.Open("ReadWrite")
       Write-Host "Certificate store is accessible"
       $store.Close()
   } catch {
       Write-Host "Certificate store access denied: $($_.Exception.Message)"
   }
   ```

### Issue: Memory Leaks

**Symptoms:**
- Increasing memory usage over time
- Application slowdowns
- Out of memory errors

**Diagnosis:**
```powershell
# Monitor memory usage
$process = Get-Process -Name "explorer" | Where-Object { $_.ProcessName -eq "explorer" }
while ($true) {
    $memory = [math]::Round($process.WorkingSet64 / 1MB, 2)
    Write-Host "Memory usage: $memory MB" -ForegroundColor Cyan
    Start-Sleep -Seconds 10
}
```

**Solutions:**
1. **Enable Memory Monitoring:**
   ```powershell
   # Configure memory limits
   $configPath = "HKLM:\SOFTWARE\Supacrypt\CSP"
   Set-ItemProperty -Path $configPath -Name "MaxMemoryUsage" -Value 512  # 512 MB
   Set-ItemProperty -Path $configPath -Name "EnableMemoryMonitoring" -Value 1
   ```

2. **Implement Connection Pooling:**
   ```powershell
   # Configure connection pool
   Set-ItemProperty -Path $configPath -Name "MaxConnections" -Value 50
   Set-ItemProperty -Path $configPath -Name "MinConnections" -Value 5
   Set-ItemProperty -Path $configPath -Name "ConnectionTimeout" -Value 30000
   ```

## Performance Issues

### Issue: Slow Certificate Operations

**Symptoms:**
- Certificate generation takes > 30 seconds
- Application timeouts
- Poor user experience

**Diagnosis:**
```powershell
# Benchmark certificate operations
function Measure-CertificatePerformance {
    $times = @()
    for ($i = 1; $i -le 10; $i++) {
        $start = Get-Date
        try {
            $cert = New-SelfSignedCertificate -Subject "CN=PerfTest$i" -Provider "Supacrypt CSP" -CertStoreLocation "Cert:\CurrentUser\My"
            $end = Get-Date
            $duration = ($end - $start).TotalMilliseconds
            $times += $duration
            Write-Host "Iteration $i: $([math]::Round($duration, 2)) ms"
            
            # Cleanup
            Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
        } catch {
            Write-Host "Iteration $i failed: $($_.Exception.Message)"
        }
    }
    
    $average = ($times | Measure-Object -Average).Average
    Write-Host "Average time: $([math]::Round($average, 2)) ms"
}

Measure-CertificatePerformance
```

**Solutions:**
1. **Enable Caching:**
   ```powershell
   # Configure caching
   $configPath = "HKLM:\SOFTWARE\Supacrypt\CSP"
   Set-ItemProperty -Path $configPath -Name "EnableCaching" -Value 1
   Set-ItemProperty -Path $configPath -Name "CacheSize" -Value 1000
   Set-ItemProperty -Path $configPath -Name "CacheTTL" -Value 3600  # 1 hour
   ```

2. **Optimize Connection Pool:**
   ```powershell
   # Tune connection pool
   Set-ItemProperty -Path $configPath -Name "MaxConnections" -Value 100
   Set-ItemProperty -Path $configPath -Name "ConnectionKeepalive" -Value 300  # 5 minutes
   ```

3. **Network Optimization:**
   ```powershell
   # Enable compression
   Set-ItemProperty -Path $configPath -Name "EnableCompression" -Value 1
   
   # Adjust timeouts
   Set-ItemProperty -Path $configPath -Name "ConnectTimeout" -Value 5000   # 5 seconds
   Set-ItemProperty -Path $configPath -Name "ReadTimeout" -Value 15000      # 15 seconds
   ```

### Issue: High CPU Usage

**Symptoms:**
- CPU usage > 80% during certificate operations
- System responsiveness issues
- Thermal throttling

**Diagnosis:**
```powershell
# Monitor CPU usage
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, WorkingSet

# Check for runaway processes
Get-WmiObject Win32_Process | Where-Object { $_.Name -like "*supacrypt*" } | Select-Object Name, ProcessId, PageFileUsage, WorkingSetSize
```

**Solutions:**
1. **CPU Affinity:**
   ```powershell
   # Set CPU affinity for CSP operations
   $process = Get-Process -Name "your-app"
   $process.ProcessorAffinity = 0x0F  # Use first 4 cores
   ```

2. **Thread Pool Tuning:**
   ```powershell
   # Configure thread limits
   Set-ItemProperty -Path $configPath -Name "MaxWorkerThreads" -Value 25
   Set-ItemProperty -Path $configPath -Name "MaxIOThreads" -Value 25
   ```

## Integration Problems

### Issue: IIS SSL Certificate Binding Fails

**Symptoms:**
- HTTPS sites don't start
- "Certificate not found" errors in IIS
- SSL/TLS handshake failures

**Diagnosis:**
```powershell
# Check certificate in store
Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Issuer -like "*Supacrypt*" }

# Verify certificate binding
netsh http show sslcert

# Test SSL handshake
Test-NetConnection -ComputerName "localhost" -Port 443 -InformationLevel Detailed
```

**Solutions:**
1. **Re-bind Certificate:**
   ```powershell
   # Remove old binding
   Remove-WebBinding -Name "Default Web Site" -Protocol https -Port 443
   
   # Create new binding with CSP certificate
   $cert = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Subject -eq "CN=your-site.com" }
   New-WebBinding -Name "Default Web Site" -Protocol https -Port 443
   $binding = Get-WebBinding -Name "Default Web Site" -Protocol https
   $binding.AddSslCertificate($cert.Thumbprint, "my")
   ```

2. **Check Certificate Properties:**
   ```powershell
   # Verify certificate has private key
   $cert = Get-ChildItem -Path "Cert:\LocalMachine\My\$thumbprint"
   Write-Host "Has private key: $($cert.HasPrivateKey)"
   Write-Host "Key algorithm: $($cert.PublicKey.Oid.FriendlyName)"
   Write-Host "Key size: $($cert.PublicKey.Key.KeySize)"
   ```

### Issue: SQL Server TDE Configuration Fails

**Symptoms:**
- TDE encryption fails to enable
- Certificate errors in SQL Server logs
- Database encryption stuck at 0%

**Diagnosis:**
```sql
-- Check TDE status
SELECT 
    db_name(database_id) as database_name,
    encryption_state,
    encryption_state_desc,
    percent_complete,
    key_algorithm,
    key_length
FROM sys.dm_database_encryption_keys;

-- Check certificates
SELECT name, subject, start_date, expiry_date, thumbprint
FROM sys.certificates;
```

**Solutions:**
1. **Recreate TDE Certificate:**
   ```sql
   -- Drop existing certificate (if safe)
   DROP CERTIFICATE SupacryptTDECert;
   
   -- Create new certificate using CSP
   CREATE CERTIFICATE SupacryptTDECert
   WITH SUBJECT = 'Supacrypt TDE Certificate';
   
   -- Recreate database encryption key
   CREATE DATABASE ENCRYPTION KEY
   WITH ALGORITHM = AES_256
   ENCRYPTION BY SERVER CERTIFICATE SupacryptTDECert;
   
   -- Enable TDE
   ALTER DATABASE [YourDatabase] SET ENCRYPTION ON;
   ```

2. **Check SQL Server Service Account:**
   ```powershell
   # Verify service account has certificate access
   $service = Get-WmiObject Win32_Service | Where-Object { $_.Name -eq "MSSQLSERVER" }
   Write-Host "SQL Server service account: $($service.StartName)"
   
   # Grant certificate permissions if needed
   # Use certlm.msc to grant private key access
   ```

## Security Issues

### Issue: Certificate Validation Failures

**Symptoms:**
- "Certificate chain validation failed" errors
- SSL/TLS connection errors
- Application security warnings

**Diagnosis:**
```powershell
# Test certificate chain
$cert = Get-ChildItem -Path "Cert:\LocalMachine\My\$thumbprint"
$chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
$result = $chain.Build($cert)
Write-Host "Chain builds: $result"

if (-not $result) {
    foreach ($status in $chain.ChainStatus) {
        Write-Host "Chain error: $($status.Status) - $($status.StatusInformation)"
    }
}
```

**Solutions:**
1. **Install Root Certificate:**
   ```powershell
   # Install root CA certificate
   $rootCert = Get-Content "root-ca.cer" -Encoding Byte
   $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
   $cert.Import($rootCert)
   
   $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
   $store.Open("ReadWrite")
   $store.Add($cert)
   $store.Close()
   ```

2. **Update Certificate Revocation Lists:**
   ```powershell
   # Update CRL
   certlm -crl -update
   
   # Disable CRL checking for testing (not recommended for production)
   [System.Net.ServicePointManager]::CheckCertificateRevocationList = $false
   ```

### Issue: Access Denied Errors

**Symptoms:**
- "Access denied" when accessing certificates
- Private key access failures
- Permission errors in event logs

**Diagnosis:**
```powershell
# Check certificate permissions
$cert = Get-ChildItem -Path "Cert:\LocalMachine\My\$thumbprint"
$key = $cert.PrivateKey
if ($key) {
    Write-Host "Private key is accessible"
} else {
    Write-Host "Cannot access private key"
}

# Check effective permissions
whoami /priv
```

**Solutions:**
1. **Grant Certificate Permissions:**
   ```powershell
   # Use certlm.msc GUI or:
   # 1. Right-click certificate → Manage Private Keys
   # 2. Add user/service account
   # 3. Grant "Full control" or "Read" as needed
   ```

2. **Service Account Configuration:**
   ```powershell
   # For IIS Application Pool
   $pool = Get-IISAppPool -Name "YourAppPool"
   $pool.ProcessModel.IdentityType = "SpecificUser"
   $pool.ProcessModel.UserName = "DOMAIN\ServiceAccount"
   $pool.ProcessModel.Password = "Password"
   $pool | Set-IISAppPool
   ```

## Log Analysis

### Enable Comprehensive Logging

```powershell
# Configure detailed logging
$configPath = "HKLM:\SOFTWARE\Supacrypt\CSP"
Set-ItemProperty -Path $configPath -Name "LogLevel" -Value "DEBUG"
Set-ItemProperty -Path $configPath -Name "LogPath" -Value "C:\Logs\Supacrypt\"
Set-ItemProperty -Path $configPath -Name "MaxLogSize" -Value 100MB
Set-ItemProperty -Path $configPath -Name "MaxLogFiles" -Value 10
```

### Common Log Patterns

**Error Patterns to Look For:**

```powershell
# Search for common error patterns
$logPath = "C:\Logs\Supacrypt\csp.log"

# Connection errors
Select-String -Path $logPath -Pattern "connection|timeout|refused" -Context 2

# Certificate errors
Select-String -Path $logPath -Pattern "certificate|cert|x509" -Context 2

# Authentication errors
Select-String -Path $logPath -Pattern "auth|authentication|credential" -Context 2

# Performance issues
Select-String -Path $logPath -Pattern "slow|timeout|performance" -Context 2
```

### Log Analysis Script

```powershell
function Analyze-SupacryptLogs {
    param([string]$LogPath = "C:\Logs\Supacrypt\csp.log")
    
    if (-not (Test-Path $LogPath)) {
        Write-Host "Log file not found: $LogPath" -ForegroundColor Red
        return
    }
    
    $content = Get-Content $LogPath
    $errors = $content | Where-Object { $_ -match "ERROR|FATAL" }
    $warnings = $content | Where-Object { $_ -match "WARN" }
    $performance = $content | Where-Object { $_ -match "slow|timeout|latency" }
    
    Write-Host "=== Log Analysis Summary ===" -ForegroundColor Green
    Write-Host "Total lines: $($content.Count)" -ForegroundColor Cyan
    Write-Host "Errors: $($errors.Count)" -ForegroundColor Red
    Write-Host "Warnings: $($warnings.Count)" -ForegroundColor Yellow
    Write-Host "Performance issues: $($performance.Count)" -ForegroundColor Yellow
    
    if ($errors.Count -gt 0) {
        Write-Host "`n=== Recent Errors ===" -ForegroundColor Red
        $errors | Select-Object -Last 5 | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    }
    
    if ($warnings.Count -gt 0) {
        Write-Host "`n=== Recent Warnings ===" -ForegroundColor Yellow
        $warnings | Select-Object -Last 5 | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    }
}

Analyze-SupacryptLogs
```

## Advanced Diagnostics

### Network Tracing

```powershell
# Capture network traffic for backend communication
netsh trace start capture=yes provider=Microsoft-Windows-TCPIP level=5 keywords=0x1 tracefile=C:\temp\supacrypt-network.etl

# Perform certificate operation that fails
# ... certificate operation here ...

# Stop tracing
netsh trace stop

# Analyze with Network Monitor or Message Analyzer
```

### Process Monitoring

```powershell
# Monitor file/registry access
# Use Process Monitor (ProcMon) to trace:
# - File system access
# - Registry access
# - Network activity
# - Process and thread activity

# Filter by process name containing "supacrypt" or application using CSP
```

### Memory Dump Analysis

```powershell
# Create memory dump for analysis
# Use Task Manager or:
$process = Get-Process -Name "your-application"
$dumpPath = "C:\temp\supacrypt-dump.dmp"

# Use debugging tools to analyze memory dump
# Visual Studio, WinDbg, or DebugDiag
```

### Event Log Analysis

```powershell
# Check Windows Event Logs
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Supacrypt*'} -MaxEvents 50 | Format-Table TimeCreated, Id, LevelDisplayName, Message -Wrap

Get-WinEvent -FilterHashtable @{LogName='System'; Keywords=36028797018963968} -MaxEvents 50 | Where-Object { $_.Message -like "*certificate*" -or $_.Message -like "*crypto*" }

# Security event log for authentication
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625,4624,4648} -MaxEvents 20 | Format-Table TimeCreated, Id, Message -Wrap
```

## Support Escalation

### Information to Collect

When escalating issues to support, collect the following:

1. **System Information:**
   ```powershell
   Get-SystemDiagnostics | ConvertTo-Json -Depth 3 | Out-File "system-info.json"
   ```

2. **Configuration Export:**
   ```powershell
   Export-RegistryKey -Path "HKLM:\SOFTWARE\Supacrypt" -OutputFile "supacrypt-config.reg"
   ```

3. **Log Files:**
   - CSP provider logs
   - Application logs
   - Windows Event Logs
   - IIS logs (if applicable)

4. **Network Information:**
   ```powershell
   Test-NetConnection -ComputerName "your-backend" -Port 443 -InformationLevel Detailed | Out-File "network-test.txt"
   nslookup your-backend.com | Out-File "dns-lookup.txt" -Append
   ```

5. **Certificate Information:**
   ```powershell
   Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Issuer -like "*Supacrypt*" } | Select-Object Subject, Thumbprint, NotAfter, HasPrivateKey | ConvertTo-Json | Out-File "certificates.json"
   ```

### Reproduction Steps

Document exact steps to reproduce the issue:

1. **Environment Setup:**
   - OS version and patches
   - Application versions
   - Configuration settings

2. **Step-by-Step Reproduction:**
   - Exact commands or actions
   - Expected vs actual results
   - Error messages

3. **Timing Information:**
   - When did the issue first occur?
   - Is it consistent or intermittent?
   - Any pattern or correlation?

---

*For additional support, contact: support@supacrypt.com*  
*Include system diagnostics and reproduction steps for faster resolution*