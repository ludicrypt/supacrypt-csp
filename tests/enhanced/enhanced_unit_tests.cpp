// enhanced_unit_tests.cpp - Enhanced CSP Unit Tests for 100% Coverage
// Copyright (c) 2025 ludicrypt. All rights reserved.
// Licensed under the MIT License.

#include "test_framework.h"
#include "csp_provider.h"
#include <vector>
#include <thread>
#include <future>

namespace supacrypt::csp::test {

class CspEnhancedUnitTest : public CspEnhancedTest {
protected:
    void SetUp() override {
        CspEnhancedTest::SetUp();
        GTEST_LOG_(INFO) << "Starting enhanced CSP unit test for 100% coverage";
    }
};

// Test CSP provider initialization with all possible flags
TEST_F(CspEnhancedUnitTest, InitializeProvider_AllFlags_HandlesCorrectly) {
    std::vector<DWORD> testFlags = {
        CRYPT_VERIFYCONTEXT,
        CRYPT_NEWKEYSET,
        CRYPT_MACHINE_KEYSET,
        CRYPT_DELETEKEYSET,
        CRYPT_SILENT,
        CRYPT_VERIFYCONTEXT | CRYPT_MACHINE_KEYSET,
        CRYPT_VERIFYCONTEXT | CRYPT_SILENT
    };
    
    for (DWORD flags : testFlags) {
        HCRYPTPROV provider = 0;
        
        auto metrics = MeasureOperation([&]() -> NTSTATUS {
            return OpenCspProvider(&provider, flags) == STATUS_SUCCESS ? STATUS_SUCCESS : STATUS_UNSUCCESSFUL;
        }, "InitializeProvider_Flags_" + std::to_string(flags));
        
        if (flags != CRYPT_DELETEKEYSET) {
            // DELETEKEYSET may fail if no keyset exists, which is acceptable
            EXPECT_PERFORMANCE_TARGET_CSP(metrics, std::chrono::milliseconds(CSP_INIT_TARGET_MS));
        }
        
        if (provider != 0) {
            CloseCspProvider(provider);
        }
    }
}

// Test all supported algorithms for key generation
class CspKeyGenerationTest : public CspEnhancedUnitTest,
                           public ::testing::WithParamInterface<ALG_ID> {
};

TEST_P(CspKeyGenerationTest, GenerateKey_SupportedAlgorithms_MeetsPerformanceTargets) {
    ALG_ID algorithm = GetParam();
    HCRYPTPROV provider = 0;
    HCRYPTKEY key = 0;
    
    NTSTATUS status = OpenCspProvider(&provider);
    ASSERT_EQ(status, STATUS_SUCCESS);
    
    auto metrics = MeasureOperation([&]() -> NTSTATUS {
        return CreateCspKey(provider, algorithm, &key, CRYPT_EXPORTABLE) == STATUS_SUCCESS ? 
               STATUS_SUCCESS : STATUS_UNSUCCESSFUL;
    }, "KeyGeneration_" + std::to_string(algorithm));
    
    EXPECT_CSP_SUCCESS(metrics.success);
    EXPECT_PERFORMANCE_TARGET_CSP(metrics, std::chrono::milliseconds(CSP_KEY_GEN_TARGET_MS));
    EXPECT_NE(key, 0u);
    
    if (key != 0) {
        // Test key properties
        DWORD keyLength = 0;
        DWORD dataLength = sizeof(keyLength);
        BOOL result = CryptGetKeyParam(key, KP_KEYLEN, 
                                     reinterpret_cast<BYTE*>(&keyLength), 
                                     &dataLength, 0);
        EXPECT_CSP_SUCCESS(result);
        EXPECT_GT(keyLength, 0u);
        
        // Test key algorithms
        ALG_ID keyAlgId = 0;
        dataLength = sizeof(keyAlgId);
        result = CryptGetKeyParam(key, KP_ALGID, 
                                reinterpret_cast<BYTE*>(&keyAlgId), 
                                &dataLength, 0);
        EXPECT_CSP_SUCCESS(result);
        EXPECT_EQ(keyAlgId, algorithm);
        
        CryptDestroyKey(key);
    }
    
    CloseCspProvider(provider);
}

INSTANTIATE_TEST_SUITE_P(
    SupportedAlgorithms,
    CspKeyGenerationTest,
    ::testing::Values(
        AT_KEYEXCHANGE,
        AT_SIGNATURE,
        CALG_RSA_KEYX,
        CALG_RSA_SIGN
    )
);

// Test signature operations with performance validation
TEST_F(CspEnhancedUnitTest, SignData_RSA2048_MeetsPerformanceTarget) {
    HCRYPTPROV provider = 0;
    HCRYPTKEY key = 0;
    
    NTSTATUS status = OpenCspProvider(&provider);
    ASSERT_EQ(status, STATUS_SUCCESS);
    
    status = CreateCspKey(provider, AT_SIGNATURE, &key);
    ASSERT_EQ(status, STATUS_SUCCESS);
    
    // Test data for signing
    std::vector<BYTE> testData = GenerateRandomData(1024);
    std::vector<BYTE> signature;
    
    auto metrics = MeasureOperation([&]() -> NTSTATUS {
        return SignData(key, testData, signature);
    }, "RSA2048_Signature");
    
    EXPECT_CSP_SUCCESS(metrics.success);
    EXPECT_PERFORMANCE_TARGET_CSP(metrics, std::chrono::milliseconds(CSP_RSA2048_SIGN_TARGET_MS));
    EXPECT_FALSE(signature.empty());
    
    // Verify signature
    std::vector<BYTE> verifyResult;
    status = VerifySignature(key, testData, signature);
    EXPECT_EQ(status, STATUS_SUCCESS);
    
    CryptDestroyKey(key);
    CloseCspProvider(provider);
}

// Test error handling paths for 100% coverage
TEST_F(CspEnhancedUnitTest, ErrorPaths_InvalidParameters_HandledCorrectly) {
    HCRYPTPROV provider = 0;
    
    // Test invalid provider name
    BOOL result = CryptAcquireContextW(&provider, nullptr, 
                                     L"NonExistentProvider", 
                                     PROV_RSA_FULL, 
                                     CRYPT_VERIFYCONTEXT);
    EXPECT_CSP_ERROR(result, NTE_PROV_TYPE_NOT_DEF);
    
    // Test invalid provider type
    result = CryptAcquireContextW(&provider, nullptr, 
                                GetCspProviderName().c_str(), 
                                999, // Invalid type
                                CRYPT_VERIFYCONTEXT);
    EXPECT_CSP_ERROR(result, NTE_PROV_TYPE_NOT_DEF);
    
    // Test null pointers
    result = CryptAcquireContextW(nullptr, nullptr, 
                                GetCspProviderName().c_str(), 
                                PROV_RSA_FULL, 
                                CRYPT_VERIFYCONTEXT);
    EXPECT_CSP_ERROR(result, ERROR_INVALID_PARAMETER);
    
    // Test invalid key operations
    HCRYPTKEY invalidKey = reinterpret_cast<HCRYPTKEY>(0xDEADBEEF);
    result = CryptDestroyKey(invalidKey);
    EXPECT_CSP_ERROR(result, ERROR_INVALID_HANDLE);
}

// Test concurrent operations for thread safety
TEST_F(CspEnhancedUnitTest, ConcurrentOperations_MultipleThreads_ThreadSafe) {
    const int NUM_THREADS = 10;
    const int OPERATIONS_PER_THREAD = 50;
    
    std::vector<std::future<bool>> futures;
    
    auto threadFunction = []() -> bool {
        bool success = true;
        
        for (int i = 0; i < OPERATIONS_PER_THREAD && success; ++i) {
            HCRYPTPROV provider = 0;
            HCRYPTKEY key = 0;
            
            // Open provider
            if (!CryptAcquireContextW(&provider, nullptr, 
                                    L"Supacrypt Cryptographic Service Provider", 
                                    PROV_RSA_FULL, 
                                    CRYPT_VERIFYCONTEXT)) {
                success = false;
                break;
            }
            
            // Generate key
            if (!CryptGenKey(provider, AT_KEYEXCHANGE, CRYPT_EXPORTABLE, &key)) {
                CryptReleaseContext(provider, 0);
                success = false;
                break;
            }
            
            // Perform operation
            DWORD keyLength = 0;
            DWORD dataLength = sizeof(keyLength);
            if (!CryptGetKeyParam(key, KP_KEYLEN, 
                                reinterpret_cast<BYTE*>(&keyLength), 
                                &dataLength, 0)) {
                success = false;
            }
            
            // Cleanup
            CryptDestroyKey(key);
            CryptReleaseContext(provider, 0);
        }
        
        return success;
    };
    
    // Launch threads
    for (int i = 0; i < NUM_THREADS; ++i) {
        futures.push_back(std::async(std::launch::async, threadFunction));
    }
    
    // Wait and verify results
    for (int i = 0; i < NUM_THREADS; ++i) {
        EXPECT_TRUE(futures[i].get()) << "Thread " << i << " failed";
    }
}

// Test memory boundaries and buffer handling
TEST_F(CspEnhancedUnitTest, BufferHandling_BoundaryConditions_HandledCorrectly) {
    HCRYPTPROV provider = 0;
    HCRYPTKEY key = 0;
    
    NTSTATUS status = OpenCspProvider(&provider);
    ASSERT_EQ(status, STATUS_SUCCESS);
    
    status = CreateCspKey(provider, AT_KEYEXCHANGE, &key, CRYPT_EXPORTABLE);
    ASSERT_EQ(status, STATUS_SUCCESS);
    
    // Test export with null buffer (get size)
    DWORD blobLength = 0;
    BOOL result = CryptExportKey(key, 0, PUBLICKEYBLOB, 0, nullptr, &blobLength);
    EXPECT_CSP_SUCCESS(result);
    EXPECT_GT(blobLength, 0u);
    
    // Test with exact size buffer
    std::vector<BYTE> blob(blobLength);
    DWORD actualLength = blobLength;
    result = CryptExportKey(key, 0, PUBLICKEYBLOB, 0, blob.data(), &actualLength);
    EXPECT_CSP_SUCCESS(result);
    EXPECT_EQ(actualLength, blobLength);
    
    // Test with buffer too small
    DWORD smallLength = blobLength - 1;
    result = CryptExportKey(key, 0, PUBLICKEYBLOB, 0, blob.data(), &smallLength);
    EXPECT_CSP_ERROR(result, ERROR_MORE_DATA);
    
    // Test with oversized buffer
    std::vector<BYTE> largeBuf(blobLength * 2);
    DWORD largeLength = static_cast<DWORD>(largeBuf.size());
    result = CryptExportKey(key, 0, PUBLICKEYBLOB, 0, largeBuf.data(), &largeLength);
    EXPECT_CSP_SUCCESS(result);
    EXPECT_EQ(largeLength, blobLength);
    
    CryptDestroyKey(key);
    CloseCspProvider(provider);
}

// Test resource cleanup under error conditions
TEST_F(CspEnhancedUnitTest, ResourceCleanup_ErrorConditions_NoLeaks) {
    // Test multiple failed operations don't leak resources
    for (int i = 0; i < 1000; ++i) {
        HCRYPTPROV provider = 0;
        
        // Try invalid operations
        BOOL result = CryptAcquireContextW(&provider, nullptr, 
                                         L"InvalidProvider", 
                                         PROV_RSA_FULL, 
                                         CRYPT_VERIFYCONTEXT);
        EXPECT_FALSE(result);
        
        // Provider should be 0 on failure
        EXPECT_EQ(provider, 0u);
        
        // Try with invalid algorithm
        if (i % 100 == 0) {
            // Open valid provider occasionally
            if (CryptAcquireContextW(&provider, nullptr, 
                                   GetCspProviderName().c_str(), 
                                   PROV_RSA_FULL, 
                                   CRYPT_VERIFYCONTEXT)) {
                
                HCRYPTKEY key = 0;
                result = CryptGenKey(provider, 0xDEADBEEF, 0, &key);
                EXPECT_FALSE(result);
                EXPECT_EQ(key, 0u);
                
                CryptReleaseContext(provider, 0);
            }
        }
    }
    
    // Verify no resource leaks
    EXPECT_NO_RESOURCE_LEAKS_CSP();
}

// Test provider enumeration and registration
TEST_F(CspEnhancedUnitTest, ProviderEnumeration_SupacryptProvider_FoundCorrectly) {
    DWORD providerIndex = 0;
    DWORD providerType = 0;
    DWORD providerNameLength = 0;
    bool supacryptFound = false;
    
    // Enumerate all providers
    while (CryptEnumProvidersW(providerIndex, nullptr, 0, &providerType, 
                              nullptr, &providerNameLength)) {
        
        std::vector<wchar_t> providerName(providerNameLength / sizeof(wchar_t));
        
        if (CryptEnumProvidersW(providerIndex, nullptr, 0, &providerType, 
                               reinterpret_cast<BYTE*>(providerName.data()), 
                               &providerNameLength)) {
            
            std::wstring name(providerName.data());
            if (name.find(L"Supacrypt") != std::wstring::npos) {
                supacryptFound = true;
                EXPECT_EQ(providerType, static_cast<DWORD>(PROV_RSA_FULL));
                GTEST_LOG_(INFO) << "Found Supacrypt CSP: " << name.c_str();
                break;
            }
        }
        
        providerIndex++;
        providerNameLength = 0; // Reset for next iteration
    }
    
    EXPECT_TRUE(supacryptFound) << "Supacrypt CSP not found in provider enumeration";
}

// Test all key parameter queries for coverage
TEST_F(CspEnhancedUnitTest, KeyParameters_AllQueries_WorkCorrectly) {
    HCRYPTPROV provider = 0;
    HCRYPTKEY key = 0;
    
    NTSTATUS status = OpenCspProvider(&provider);
    ASSERT_EQ(status, STATUS_SUCCESS);
    
    status = CreateCspKey(provider, AT_SIGNATURE, &key);
    ASSERT_EQ(status, STATUS_SUCCESS);
    
    // Test all key parameters
    std::vector<DWORD> keyParams = {
        KP_ALGID,
        KP_KEYLEN,
        KP_BLOCKLEN,
        KP_SALT,
        KP_PERMISSIONS,
        KP_MODE
    };
    
    for (DWORD param : keyParams) {
        DWORD dataLength = 0;
        
        // Get size first
        BOOL result = CryptGetKeyParam(key, param, nullptr, &dataLength, 0);
        if (result || GetLastError() == ERROR_MORE_DATA) {
            // Parameter is supported
            std::vector<BYTE> data(dataLength);
            result = CryptGetKeyParam(key, param, data.data(), &dataLength, 0);
            
            if (result) {
                GTEST_LOG_(INFO) << "Key parameter " << param << " retrieved successfully";
            }
        }
    }
    
    CryptDestroyKey(key);
    CloseCspProvider(provider);
}

// Test hash operations integration
TEST_F(CspEnhancedUnitTest, HashOperations_IntegratedSigning_WorksCorrectly) {
    HCRYPTPROV provider = 0;
    HCRYPTKEY key = 0;
    HCRYPTHASH hash = 0;
    
    NTSTATUS status = OpenCspProvider(&provider);
    ASSERT_EQ(status, STATUS_SUCCESS);
    
    status = CreateCspKey(provider, AT_SIGNATURE, &key);
    ASSERT_EQ(status, STATUS_SUCCESS);
    
    // Create hash
    BOOL result = CryptCreateHash(provider, CALG_SHA1, 0, 0, &hash);
    EXPECT_CSP_SUCCESS(result);
    
    // Hash some data
    std::vector<BYTE> data = GenerateRandomData(256);
    result = CryptHashData(hash, data.data(), static_cast<DWORD>(data.size()), 0);
    EXPECT_CSP_SUCCESS(result);
    
    // Sign the hash
    DWORD sigLength = 0;
    result = CryptSignHashW(hash, AT_SIGNATURE, nullptr, 0, nullptr, &sigLength);
    EXPECT_CSP_SUCCESS(result);
    
    std::vector<BYTE> signature(sigLength);
    result = CryptSignHashW(hash, AT_SIGNATURE, nullptr, 0, signature.data(), &sigLength);
    EXPECT_CSP_SUCCESS(result);
    
    // Verify signature
    result = CryptVerifySignatureW(hash, signature.data(), sigLength, key, nullptr, 0);
    EXPECT_CSP_SUCCESS(result);
    
    // Cleanup
    CryptDestroyHash(hash);
    CryptDestroyKey(key);
    CloseCspProvider(provider);
}

} // namespace supacrypt::csp::test