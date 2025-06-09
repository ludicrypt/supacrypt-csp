// test_framework.h - CSP Test Framework Header
// Copyright (c) 2025 ludicrypt. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include <gtest/gtest.h>
#include <gmock/gmock.h>
#include <windows.h>
#include <wincrypt.h>
#include <memory>
#include <vector>
#include <string>
#include <chrono>
#include <functional>

namespace supacrypt::csp::test {

// Forward declarations
class PerformanceProfiler;
class SecurityValidator;
class WindowsTestUtils;

// Test configuration constants
constexpr DWORD CSP_TEST_TIMEOUT_MS = 30000;
constexpr DWORD CSP_PERFORMANCE_ITERATIONS = 1000;
constexpr DWORD CSP_LOAD_TEST_CONCURRENT_OPERATIONS = 100;
constexpr size_t CSP_MAX_TEST_DATA_SIZE = 1024 * 1024; // 1MB

// CSP Performance targets from Task 4.3
constexpr DWORD CSP_INIT_TARGET_MS = 100;
constexpr DWORD CSP_RSA2048_SIGN_TARGET_MS = 100;
constexpr DWORD CSP_KEY_GEN_TARGET_MS = 3000;

// Performance metrics structure
struct CspPerformanceMetrics {
    std::chrono::milliseconds initTime;
    std::chrono::milliseconds operationTime;
    std::chrono::milliseconds cleanupTime;
    size_t memoryUsage;
    DWORD handleCount;
    bool success;
    std::string operationName;
};

// Security test results
struct CspSecurityTestResult {
    bool accessControlValid;
    bool handleSecurityValid;
    bool noMemoryLeaks;
    bool noHandleLeaks;
    bool noInformationLeakage;
    std::vector<std::string> vulnerabilities;
};

// Base test fixture for CSP testing
class CspTestBase : public ::testing::Test {
public:
    CspTestBase();
    virtual ~CspTestBase();

protected:
    void SetUp() override;
    void TearDown() override;

    // CSP provider management
    NTSTATUS OpenCspProvider(HCRYPTPROV* phProv, DWORD dwFlags = CRYPT_VERIFYCONTEXT);
    NTSTATUS CloseCspProvider(HCRYPTPROV hProv);
    std::wstring GetCspProviderName() const;

    // Key management
    NTSTATUS CreateCspKey(HCRYPTPROV hProv, ALG_ID algId, HCRYPTKEY* phKey, DWORD dwFlags = 0);
    NTSTATUS ImportCspKey(HCRYPTPROV hProv, BYTE* pbData, DWORD dwDataLen, HCRYPTKEY* phKey);
    NTSTATUS ExportCspKey(HCRYPTKEY hKey, HCRYPTKEY hExpKey, DWORD dwBlobType, BYTE** ppbData, DWORD* pdwDataLen);

    // Cryptographic operations
    NTSTATUS SignData(HCRYPTKEY hKey, const std::vector<BYTE>& data, std::vector<BYTE>& signature);
    NTSTATUS VerifySignature(HCRYPTKEY hKey, const std::vector<BYTE>& data, const std::vector<BYTE>& signature);
    NTSTATUS EncryptData(HCRYPTKEY hKey, const std::vector<BYTE>& plaintext, std::vector<BYTE>& ciphertext);
    NTSTATUS DecryptData(HCRYPTKEY hKey, const std::vector<BYTE>& ciphertext, std::vector<BYTE>& plaintext);

    // Test utilities
    std::vector<BYTE> GenerateRandomData(size_t size);
    std::string GenerateRandomKeyName();
    void ValidateErrorCode(DWORD result, DWORD expected);
    void ValidateSecurityContext();

    // Performance measurement
    CspPerformanceMetrics MeasureOperation(std::function<NTSTATUS()> operation, const std::string& name = "");
    void ValidatePerformanceTarget(const CspPerformanceMetrics& metrics, std::chrono::milliseconds maxTime);

    // Resource tracking
    void StartResourceTracking();
    void StopResourceTracking();
    bool ValidateNoResourceLeaks();

    // Test data and utilities
    std::unique_ptr<PerformanceProfiler> profiler_;
    std::unique_ptr<SecurityValidator> validator_;
    std::unique_ptr<WindowsTestUtils> utils_;

private:
    HCRYPTPROV defaultProvider_;
    size_t initialMemoryUsage_;
    DWORD initialHandleCount_;
    bool resourceTrackingActive_;
};

// Enhanced CSP test fixture with additional validation
class CspEnhancedTest : public CspTestBase {
protected:
    void SetUp() override;
    void TearDown() override;

    // Enhanced validation methods
    void ValidateProviderCapabilities(HCRYPTPROV hProv);
    void ValidateAlgorithmSupport(HCRYPTPROV hProv, ALG_ID algId);
    void ValidateKeyProperties(HCRYPTKEY hKey);
    void ValidateErrorHandling();

    // Stress testing utilities
    void RunConcurrentOperations(DWORD numThreads, DWORD operationsPerThread);
    void RunMemoryStressTest();
    void RunHandleStressTest();
};

// Performance test fixture
class CspPerformanceTest : public CspEnhancedTest {
protected:
    void SetUp() override;

    // Benchmark methods
    CspPerformanceMetrics BenchmarkInitialization(DWORD iterations = CSP_PERFORMANCE_ITERATIONS);
    CspPerformanceMetrics BenchmarkKeyGeneration(ALG_ID algId, DWORD iterations = 100);
    CspPerformanceMetrics BenchmarkSignature(ALG_ID algId, size_t dataSize, DWORD iterations = CSP_PERFORMANCE_ITERATIONS);
    CspPerformanceMetrics BenchmarkEncryption(ALG_ID algId, size_t dataSize, DWORD iterations = CSP_PERFORMANCE_ITERATIONS);

    // Load testing
    CspPerformanceMetrics LoadTest(DWORD concurrentOperations = CSP_LOAD_TEST_CONCURRENT_OPERATIONS);
    CspPerformanceMetrics StressTest(DWORD durationMinutes = 5);

    // Report generation
    void GeneratePerformanceReport(const std::string& filename);

private:
    std::vector<CspPerformanceMetrics> metrics_;
};

// Security test fixture
class CspSecurityTest : public CspEnhancedTest {
protected:
    void SetUp() override;

    // Security validation methods
    CspSecurityTestResult ValidateAccessControl();
    CspSecurityTestResult ValidateHandleSecurity();
    CspSecurityTestResult ValidateMemorySecurity();
    CspSecurityTestResult ValidateErrorHandling();

    // Attack simulation
    CspSecurityTestResult SimulateHandleHijacking();
    CspSecurityTestResult SimulatePrivilegeEscalation();
    CspSecurityTestResult SimulateInformationLeakage();

    // Report generation
    void GenerateSecurityReport(const std::string& filename);

private:
    std::vector<CspSecurityTestResult> results_;
};

// Integration test fixture
class CspIntegrationTest : public CspEnhancedTest {
protected:
    void SetUp() override;
    void TearDown() override;

    // Windows API integration
    bool TestCertificateEnrollment();
    bool TestCertificateManagerIntegration();
    bool TestEventLogIntegration();
    bool TestRegistryIntegration();

    // Application compatibility
    bool TestIISIntegration();
    bool TestSqlServerIntegration();
    bool TestDotNetIntegration();
    bool TestOfficeIntegration();

private:
    HCERTSTORE testCertStore_;
};

// Architecture test fixture
class CspArchitectureTest : public CspEnhancedTest {
protected:
    // Architecture-specific tests
    bool TestX86Compatibility();
    bool TestX64Optimization();
    bool TestWOW64Compatibility();
    bool TestDataStructureAlignment();
    bool TestCallingConventions();

    // Cross-platform validation
    void ValidateArchitectureSpecificBehavior();
    void ValidatePointerSizeCompatibility();
    void ValidateEndianness();
};

// Test macros for enhanced functionality
#define EXPECT_CSP_SUCCESS(result) \
    EXPECT_TRUE(result) << "CSP operation failed with error: 0x" << std::hex << GetLastError()

#define EXPECT_CSP_ERROR(result, expectedError) \
    EXPECT_FALSE(result); \
    EXPECT_EQ(GetLastError(), static_cast<DWORD>(expectedError))

#define EXPECT_PERFORMANCE_TARGET_CSP(metrics, maxTime) \
    EXPECT_LE(metrics.operationTime.count(), maxTime.count()) << \
    "CSP operation '" << metrics.operationName << "' took " << metrics.operationTime.count() << \
    "ms, expected <= " << maxTime.count() << "ms"

#define EXPECT_NO_RESOURCE_LEAKS_CSP() \
    EXPECT_TRUE(ValidateNoResourceLeaks()) << "CSP resource leaks detected"

// Parameterized test helpers
std::vector<ALG_ID> GetSupportedCspAlgorithms();
std::vector<std::string> GetTestCspKeyNames();
std::vector<size_t> GetTestDataSizes();
std::vector<DWORD> GetCspTestFlags();

} // namespace supacrypt::csp::test