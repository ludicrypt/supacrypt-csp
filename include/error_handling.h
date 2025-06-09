/**
 * @file error_handling.h
 * @brief Error handling and mapping for Supacrypt Windows CSP
 * 
 * This file defines error handling utilities for mapping between
 * Windows CSP error codes, gRPC status codes, and backend errors.
 * 
 * @copyright Copyright (c) 2025 ludicrypt
 * @license MIT License
 */

#ifndef SUPACRYPT_CSP_ERROR_HANDLING_H
#define SUPACRYPT_CSP_ERROR_HANDLING_H

#include <windows.h>
#include <wincrypt.h>
#include <string>
#include <map>

#ifdef ENABLE_GRPC
#include <grpcpp/grpcpp.h>
#include "supacrypt.grpc.pb.h"
#endif

namespace supacrypt::csp {

/**
 * @brief CSP error codes mapping
 */
enum class CspErrorCode : DWORD {
    Success = ERROR_SUCCESS,
    InvalidParameter = NTE_BAD_PROV_TYPE,
    ProviderDllFail = NTE_PROVIDER_DLL_FAIL,
    KeyNotFound = NTE_NO_KEY,
    BadKeySpec = NTE_BAD_KEY,
    BadAlgorithm = NTE_BAD_ALGID,
    BadFlags = NTE_BAD_FLAGS,
    BadKeyContainer = NTE_BAD_KEYSET,
    BadSignature = NTE_BAD_SIGNATURE,
    BadHash = NTE_BAD_HASH,
    BadData = NTE_BAD_DATA,
    BadLength = NTE_BAD_LEN,
    InsufficientBuffer = ERROR_MORE_DATA,
    NotSupported = NTE_NOT_SUPPORTED,
    InternalError = NTE_FAIL,
    NetworkError = NTE_FAIL,
    AuthenticationFailed = NTE_BAD_KEY,
    AuthorizationFailed = NTE_PERM,
    KeyExists = NTE_EXISTS,
    InvalidHandle = NTE_BAD_KEY_STATE
};

/**
 * @brief Set the last CSP error code
 * @param errorCode Windows error code to set
 */
void SetLastCspError(DWORD errorCode);

/**
 * @brief Get a human-readable description of a CSP error
 * @param errorCode Error code to describe
 * @return Error description string
 */
std::string GetCspErrorDescription(DWORD errorCode);

#ifdef ENABLE_GRPC

/**
 * @brief Map gRPC status to Windows CSP error code
 * @param status gRPC status
 * @return Corresponding Windows error code
 */
DWORD MapGrpcStatusToCspError(const grpc::Status& status);

/**
 * @brief Map backend error code to Windows CSP error code
 * @param backendError Backend error code from protobuf
 * @return Corresponding Windows error code
 */
DWORD MapBackendErrorToCspError(supacrypt::v1::ErrorCode backendError);

/**
 * @brief Map Windows CSP error to backend error code
 * @param cspError Windows CSP error code
 * @return Corresponding backend error code
 */
supacrypt::v1::ErrorCode MapCspErrorToBackendError(DWORD cspError);

#endif // ENABLE_GRPC

/**
 * @brief Error context for detailed error reporting
 */
struct ErrorContext {
    DWORD errorCode = ERROR_SUCCESS;
    std::string message;
    std::string details;
    std::string function;
    int line = 0;
    
    ErrorContext() = default;
    ErrorContext(DWORD code, const std::string& msg) 
        : errorCode(code), message(msg) {}
    ErrorContext(DWORD code, const std::string& msg, const std::string& det)
        : errorCode(code), message(msg), details(det) {}
    
    bool IsSuccess() const { return errorCode == ERROR_SUCCESS; }
    std::string ToString() const;
};

/**
 * @brief Thread-local error context storage
 */
class ErrorManager {
public:
    /**
     * @brief Get the singleton instance
     */
    static ErrorManager& Instance();
    
    /**
     * @brief Set the last error context
     * @param context Error context to set
     */
    void SetLastError(const ErrorContext& context);
    
    /**
     * @brief Get the last error context
     * @return Last error context
     */
    ErrorContext GetLastError() const;
    
    /**
     * @brief Clear the last error
     */
    void ClearLastError();
    
    /**
     * @brief Set error with formatting
     * @param errorCode Error code
     * @param format Format string
     * @param ... Format arguments
     */
    void SetErrorFormatted(DWORD errorCode, const char* format, ...);

private:
    ErrorManager() = default;
    ~ErrorManager() = default;
    
    // Disable copy and move
    ErrorManager(const ErrorManager&) = delete;
    ErrorManager& operator=(const ErrorManager&) = delete;
    ErrorManager(ErrorManager&&) = delete;
    ErrorManager& operator=(ErrorManager&&) = delete;
    
    thread_local static ErrorContext lastError_;
};

// Convenience macros for error handling
#define CSP_SET_ERROR(code, msg) \
    do { \
        supacrypt::csp::ErrorContext ctx(code, msg); \
        ctx.function = __FUNCTION__; \
        ctx.line = __LINE__; \
        supacrypt::csp::ErrorManager::Instance().SetLastError(ctx); \
        supacrypt::csp::SetLastCspError(code); \
    } while(0)

#define CSP_SET_ERROR_DETAILED(code, msg, details) \
    do { \
        supacrypt::csp::ErrorContext ctx(code, msg, details); \
        ctx.function = __FUNCTION__; \
        ctx.line = __LINE__; \
        supacrypt::csp::ErrorManager::Instance().SetLastError(ctx); \
        supacrypt::csp::SetLastCspError(code); \
    } while(0)

#define CSP_SET_ERROR_FORMATTED(code, format, ...) \
    do { \
        supacrypt::csp::ErrorManager::Instance().SetErrorFormatted(code, format, __VA_ARGS__); \
        supacrypt::csp::SetLastCspError(code); \
    } while(0)

#define CSP_RETURN_ERROR(code, msg) \
    do { \
        CSP_SET_ERROR(code, msg); \
        return FALSE; \
    } while(0)

#define CSP_RETURN_ERROR_DETAILED(code, msg, details) \
    do { \
        CSP_SET_ERROR_DETAILED(code, msg, details); \
        return FALSE; \
    } while(0)

// Validation macros
#define CSP_VALIDATE_PARAM(condition, errorCode, msg) \
    if (!(condition)) { \
        CSP_RETURN_ERROR(errorCode, msg); \
    }

#define CSP_VALIDATE_HANDLE(handle, errorCode, msg) \
    if ((handle) == nullptr || (handle) == INVALID_HANDLE_VALUE) { \
        CSP_RETURN_ERROR(errorCode, msg); \
    }

#define CSP_VALIDATE_BUFFER(buffer, length, errorCode, msg) \
    if ((buffer) == nullptr && (length) > 0) { \
        CSP_RETURN_ERROR(errorCode, msg); \
    }

// Internal function declarations for CSP operations
// These are the actual implementations called by the export functions

namespace supacrypt::csp {

// Provider management
BOOL Internal_CPAcquireContext(HCRYPTPROV* phProv, LPCSTR pszContainer, DWORD dwFlags, PVTableProvStruc pVTable);
BOOL Internal_CPReleaseContext(HCRYPTPROV hProv, DWORD dwFlags);
BOOL Internal_CPSetProvParam(HCRYPTPROV hProv, DWORD dwParam, const BYTE* pbData, DWORD dwFlags);
BOOL Internal_CPGetProvParam(HCRYPTPROV hProv, DWORD dwParam, BYTE* pbData, DWORD* pdwDataLen, DWORD dwFlags);

// Key management
BOOL Internal_CPGenKey(HCRYPTPROV hProv, ALG_ID Algid, DWORD dwFlags, HCRYPTKEY* phKey);
BOOL Internal_CPDestroyKey(HCRYPTPROV hProv, HCRYPTKEY hKey);
BOOL Internal_CPSetKeyParam(HCRYPTPROV hProv, HCRYPTKEY hKey, DWORD dwParam, const BYTE* pbData, DWORD dwFlags);
BOOL Internal_CPGetKeyParam(HCRYPTPROV hProv, HCRYPTKEY hKey, DWORD dwParam, BYTE* pbData, DWORD* pdwDataLen, DWORD dwFlags);
BOOL Internal_CPExportKey(HCRYPTPROV hProv, HCRYPTKEY hKey, HCRYPTKEY hExpKey, DWORD dwBlobType, DWORD dwFlags, BYTE* pbData, DWORD* pdwDataLen);
BOOL Internal_CPImportKey(HCRYPTPROV hProv, const BYTE* pbData, DWORD dwDataLen, HCRYPTKEY hImpKey, DWORD dwFlags, HCRYPTKEY* phKey);
BOOL Internal_CPGetUserKey(HCRYPTPROV hProv, DWORD dwKeySpec, HCRYPTKEY* phUserKey);
BOOL Internal_CPDuplicateKey(HCRYPTPROV hProv, HCRYPTKEY hKey, DWORD* pdwReserved, DWORD dwFlags, HCRYPTKEY* phKey);

// Cryptographic operations
BOOL Internal_CPEncrypt(HCRYPTPROV hProv, HCRYPTKEY hKey, HCRYPTHASH hHash, BOOL fFinal, DWORD dwFlags, BYTE* pbData, DWORD* pdwDataLen, DWORD dwBufLen);
BOOL Internal_CPDecrypt(HCRYPTPROV hProv, HCRYPTKEY hKey, HCRYPTHASH hHash, BOOL fFinal, DWORD dwFlags, BYTE* pbData, DWORD* pdwDataLen);
BOOL Internal_CPSignHash(HCRYPTPROV hProv, HCRYPTHASH hHash, DWORD dwKeySpec, LPCWSTR sDescription, DWORD dwFlags, BYTE* pbSignature, DWORD* pdwSigLen);
BOOL Internal_CPVerifySignature(HCRYPTPROV hProv, HCRYPTHASH hHash, const BYTE* pbSignature, DWORD dwSigLen, HCRYPTKEY hPubKey, LPCWSTR sDescription, DWORD dwFlags);

// Hash operations
BOOL Internal_CPCreateHash(HCRYPTPROV hProv, ALG_ID Algid, HCRYPTKEY hKey, DWORD dwFlags, HCRYPTHASH* phHash);
BOOL Internal_CPDestroyHash(HCRYPTPROV hProv, HCRYPTHASH hHash);
BOOL Internal_CPSetHashParam(HCRYPTPROV hProv, HCRYPTHASH hHash, DWORD dwParam, const BYTE* pbData, DWORD dwFlags);
BOOL Internal_CPGetHashParam(HCRYPTPROV hProv, HCRYPTHASH hHash, DWORD dwParam, BYTE* pbData, DWORD* pdwDataLen, DWORD dwFlags);
BOOL Internal_CPHashData(HCRYPTPROV hProv, HCRYPTHASH hHash, const BYTE* pbData, DWORD dwDataLen, DWORD dwFlags);
BOOL Internal_CPHashSessionKey(HCRYPTPROV hProv, HCRYPTHASH hHash, HCRYPTKEY hKey, DWORD dwFlags);
BOOL Internal_CPDuplicateHash(HCRYPTPROV hProv, HCRYPTHASH hHash, DWORD* pdwReserved, DWORD dwFlags, HCRYPTHASH* phHash);

// Utility operations
BOOL Internal_CPGenRandom(HCRYPTPROV hProv, DWORD dwLen, BYTE* pbBuffer);
BOOL Internal_CPDeriveKey(HCRYPTPROV hProv, ALG_ID Algid, HCRYPTHASH hBaseData, DWORD dwFlags, HCRYPTKEY* phKey);

} // namespace supacrypt::csp

} // namespace supacrypt::csp

#endif // SUPACRYPT_CSP_ERROR_HANDLING_H