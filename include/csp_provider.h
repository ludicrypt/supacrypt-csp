/**
 * @file csp_provider.h
 * @brief Main CSP provider interface for Supacrypt Windows CSP
 * 
 * This file defines the core CSP provider interface that implements
 * the Windows Cryptographic Service Provider APIs. All cryptographic
 * operations are delegated to the Supacrypt gRPC backend service.
 * 
 * @copyright Copyright (c) 2025 ludicrypt
 * @license MIT License
 */

#ifndef SUPACRYPT_CSP_PROVIDER_H
#define SUPACRYPT_CSP_PROVIDER_H

#include <windows.h>
#include <wincrypt.h>
#include <cstdint>
#include <memory>
#include <string>

// Forward declarations
namespace supacrypt::csp {
    class GrpcClient;
    class KeyContainer;
}

/**
 * @brief CSP Provider context structure
 * 
 * This structure maintains the state for a CSP provider context,
 * including the connection to the backend service and key containers.
 */
typedef struct CSP_PROVIDER_CONTEXT {
    DWORD dwVersion;                    // CSP version
    DWORD dwProvType;                   // Provider type (PROV_RSA_FULL)
    LPSTR pszContainer;                 // Key container name (can be NULL)
    DWORD dwFlags;                      // Provider flags
    std::shared_ptr<supacrypt::csp::GrpcClient> grpcClient;     // Backend client
    std::shared_ptr<supacrypt::csp::KeyContainer> keyContainer; // Key management
    
    CSP_PROVIDER_CONTEXT() 
        : dwVersion(0), dwProvType(0), pszContainer(nullptr), dwFlags(0) {}
        
    ~CSP_PROVIDER_CONTEXT() {
        if (pszContainer) {
            LocalFree(pszContainer);
        }
    }
} CSP_PROVIDER_CONTEXT, *PCSP_PROVIDER_CONTEXT;

/**
 * @brief CSP Key handle structure
 * 
 * Represents a cryptographic key handle within the CSP.
 */
typedef struct CSP_KEY_HANDLE {
    DWORD dwKeySpec;                    // Key specification (AT_KEYEXCHANGE, AT_SIGNATURE)
    DWORD dwAlgorithm;                  // Algorithm identifier (CALG_RSA_SIGN, etc.)
    DWORD dwKeySize;                    // Key size in bits
    std::string keyId;                  // Backend key identifier
    PCSP_PROVIDER_CONTEXT pContext;     // Parent context
    
    CSP_KEY_HANDLE() 
        : dwKeySpec(0), dwAlgorithm(0), dwKeySize(0), pContext(nullptr) {}
} CSP_KEY_HANDLE, *PCSP_KEY_HANDLE;

/**
 * @brief CSP Hash handle structure
 * 
 * Represents a hash object within the CSP.
 */
typedef struct CSP_HASH_HANDLE {
    DWORD dwAlgorithm;                  // Hash algorithm (CALG_SHA1, CALG_SHA_256, etc.)
    std::vector<BYTE> hashData;         // Accumulated hash data
    bool bFinalized;                    // Whether hash computation is finalized
    PCSP_PROVIDER_CONTEXT pContext;     // Parent context
    
    CSP_HASH_HANDLE() 
        : dwAlgorithm(0), bFinalized(false), pContext(nullptr) {}
} CSP_HASH_HANDLE, *PCSP_HASH_HANDLE;

// CSP Provider interface functions
extern "C" {

/**
 * @brief Acquire a handle to a CSP provider
 * 
 * @param phProv Pointer to receive the provider handle
 * @param pszContainer Key container name (can be NULL for default)
 * @param dwFlags Provider acquisition flags
 * @param pVTable Reserved, must be NULL
 * @return TRUE on success, FALSE on failure
 */
BOOL WINAPI CPAcquireContext(
    OUT HCRYPTPROV *phProv,
    IN LPCSTR pszContainer,
    IN DWORD dwFlags,
    IN PVTableProvStruc pVTable
);

/**
 * @brief Release a CSP provider handle
 * 
 * @param hProv Provider handle to release
 * @param dwFlags Reserved, must be 0
 * @return TRUE on success, FALSE on failure
 */
BOOL WINAPI CPReleaseContext(
    IN HCRYPTPROV hProv,
    IN DWORD dwFlags
);

/**
 * @brief Generate a cryptographic key
 * 
 * @param hProv Provider handle
 * @param Algid Algorithm identifier
 * @param dwFlags Key generation flags
 * @param phKey Pointer to receive the key handle
 * @return TRUE on success, FALSE on failure
 */
BOOL WINAPI CPGenKey(
    IN HCRYPTPROV hProv,
    IN ALG_ID Algid,
    IN DWORD dwFlags,
    OUT HCRYPTKEY *phKey
);

/**
 * @brief Destroy a cryptographic key
 * 
 * @param hProv Provider handle
 * @param hKey Key handle to destroy
 * @return TRUE on success, FALSE on failure
 */
BOOL WINAPI CPDestroyKey(
    IN HCRYPTPROV hProv,
    IN HCRYPTKEY hKey
);

/**
 * @brief Get a user key handle
 * 
 * @param hProv Provider handle
 * @param dwKeySpec Key specification (AT_KEYEXCHANGE or AT_SIGNATURE)
 * @param phUserKey Pointer to receive the key handle
 * @return TRUE on success, FALSE on failure
 */
BOOL WINAPI CPGetUserKey(
    IN HCRYPTPROV hProv,
    IN DWORD dwKeySpec,
    OUT HCRYPTKEY *phUserKey
);

/**
 * @brief Create a hash object
 * 
 * @param hProv Provider handle
 * @param Algid Hash algorithm identifier
 * @param hKey Key for keyed hashes (can be 0)
 * @param dwFlags Hash creation flags
 * @param phHash Pointer to receive the hash handle
 * @return TRUE on success, FALSE on failure
 */
BOOL WINAPI CPCreateHash(
    IN HCRYPTPROV hProv,
    IN ALG_ID Algid,
    IN HCRYPTKEY hKey,
    IN DWORD dwFlags,
    OUT HCRYPTHASH *phHash
);

/**
 * @brief Add data to a hash object
 * 
 * @param hProv Provider handle
 * @param hHash Hash handle
 * @param pbData Data to hash
 * @param dwDataLen Length of data
 * @param dwFlags Reserved, must be 0
 * @return TRUE on success, FALSE on failure
 */
BOOL WINAPI CPHashData(
    IN HCRYPTPROV hProv,
    IN HCRYPTHASH hHash,
    IN CONST BYTE *pbData,
    IN DWORD dwDataLen,
    IN DWORD dwFlags
);

/**
 * @brief Sign a hash
 * 
 * @param hProv Provider handle
 * @param hHash Hash handle
 * @param dwKeySpec Key specification for signing
 * @param sDescription Signature description (can be NULL)
 * @param dwFlags Signing flags
 * @param pbSignature Buffer to receive signature (can be NULL for size query)
 * @param pdwSigLen Pointer to signature length
 * @return TRUE on success, FALSE on failure
 */
BOOL WINAPI CPSignHash(
    IN HCRYPTPROV hProv,
    IN HCRYPTHASH hHash,
    IN DWORD dwKeySpec,
    IN LPCWSTR sDescription,
    IN DWORD dwFlags,
    OUT BYTE *pbSignature,
    IN OUT DWORD *pdwSigLen
);

/**
 * @brief Verify a signature
 * 
 * @param hProv Provider handle
 * @param hHash Hash handle
 * @param pbSignature Signature to verify
 * @param dwSigLen Signature length
 * @param hPubKey Public key for verification
 * @param sDescription Signature description (can be NULL)
 * @param dwFlags Verification flags
 * @return TRUE if signature is valid, FALSE otherwise
 */
BOOL WINAPI CPVerifySignature(
    IN HCRYPTPROV hProv,
    IN HCRYPTHASH hHash,
    IN CONST BYTE *pbSignature,
    IN DWORD dwSigLen,
    IN HCRYPTKEY hPubKey,
    IN LPCWSTR sDescription,
    IN DWORD dwFlags
);

/**
 * @brief Get provider parameters
 * 
 * @param hProv Provider handle
 * @param dwParam Parameter type
 * @param pbData Buffer to receive parameter data
 * @param pdwDataLen Pointer to data length
 * @param dwFlags Parameter flags
 * @return TRUE on success, FALSE on failure
 */
BOOL WINAPI CPGetProvParam(
    IN HCRYPTPROV hProv,
    IN DWORD dwParam,
    OUT BYTE *pbData,
    IN OUT DWORD *pdwDataLen,
    IN DWORD dwFlags
);

/**
 * @brief Set provider parameters
 * 
 * @param hProv Provider handle
 * @param dwParam Parameter type
 * @param pbData Parameter data
 * @param dwFlags Parameter flags
 * @return TRUE on success, FALSE on failure
 */
BOOL WINAPI CPSetProvParam(
    IN HCRYPTPROV hProv,
    IN DWORD dwParam,
    IN CONST BYTE *pbData,
    IN DWORD dwFlags
);

} // extern "C"

// Internal helper functions (C++ interface)
namespace supacrypt::csp {

/**
 * @brief Initialize the CSP provider system
 * @return true on success, false on failure
 */
bool InitializeProvider();

/**
 * @brief Cleanup the CSP provider system
 */
void CleanupProvider();

/**
 * @brief Validate provider handle
 * @param hProv Provider handle to validate
 * @return Pointer to provider context or nullptr if invalid
 */
PCSP_PROVIDER_CONTEXT ValidateProviderHandle(HCRYPTPROV hProv);

/**
 * @brief Validate key handle
 * @param hKey Key handle to validate
 * @return Pointer to key handle structure or nullptr if invalid
 */
PCSP_KEY_HANDLE ValidateKeyHandle(HCRYPTKEY hKey);

/**
 * @brief Validate hash handle
 * @param hHash Hash handle to validate
 * @return Pointer to hash handle structure or nullptr if invalid
 */
PCSP_HASH_HANDLE ValidateHashHandle(HCRYPTHASH hHash);

} // namespace supacrypt::csp

#endif // SUPACRYPT_CSP_PROVIDER_H