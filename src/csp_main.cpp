/**
 * @file csp_main.cpp
 * @brief Main DLL entry point and CSP exports for Supacrypt Windows CSP
 * 
 * This file implements the DLL main function and provides the required
 * CSP export functions that delegate to the internal implementation.
 * 
 * @copyright Copyright (c) 2025 ludicrypt
 * @license MIT License
 */

#include <windows.h>
#include <wincrypt.h>
#include <cstdint>

#include "csp_provider.h"
#include "error_handling.h"

// Global variables
static HMODULE g_hModule = nullptr;
static bool g_bInitialized = false;

/**
 * @brief DLL entry point
 * 
 * @param hinstDLL Handle to the DLL module
 * @param fdwReason Reason for calling the function
 * @param lpReserved Reserved parameter
 * @return TRUE on success, FALSE on failure
 */
BOOL APIENTRY DllMain(
    HMODULE hinstDLL,
    DWORD fdwReason,
    LPVOID lpReserved
)
{
    UNREFERENCED_PARAMETER(lpReserved);
    
    switch (fdwReason) {
    case DLL_PROCESS_ATTACH:
        // Store module handle
        g_hModule = hinstDLL;
        
        // Disable thread notifications for performance
        DisableThreadLibraryCalls(hinstDLL);
        
        // Initialize the CSP provider
        if (!supacrypt::csp::InitializeProvider()) {
            return FALSE;
        }
        
        g_bInitialized = true;
        break;
        
    case DLL_PROCESS_DETACH:
        if (g_bInitialized) {
            // Cleanup the CSP provider
            supacrypt::csp::CleanupProvider();
            g_bInitialized = false;
        }
        break;
        
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
        // No per-thread initialization needed
        break;
    }
    
    return TRUE;
}

// CSP Export Functions Implementation
// These functions provide the Windows CSP interface and delegate to internal implementation

extern "C" {

/**
 * @brief CPAcquireContext export function
 */
BOOL WINAPI CPAcquireContext(
    OUT HCRYPTPROV *phProv,
    IN LPCSTR pszContainer,
    IN DWORD dwFlags,
    IN PVTableProvStruc pVTable
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    // Delegate to internal implementation
    return supacrypt::csp::Internal_CPAcquireContext(phProv, pszContainer, dwFlags, pVTable);
}

/**
 * @brief CPReleaseContext export function
 */
BOOL WINAPI CPReleaseContext(
    IN HCRYPTPROV hProv,
    IN DWORD dwFlags
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPReleaseContext(hProv, dwFlags);
}

/**
 * @brief CPGenKey export function
 */
BOOL WINAPI CPGenKey(
    IN HCRYPTPROV hProv,
    IN ALG_ID Algid,
    IN DWORD dwFlags,
    OUT HCRYPTKEY *phKey
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPGenKey(hProv, Algid, dwFlags, phKey);
}

/**
 * @brief CPDestroyKey export function
 */
BOOL WINAPI CPDestroyKey(
    IN HCRYPTPROV hProv,
    IN HCRYPTKEY hKey
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPDestroyKey(hProv, hKey);
}

/**
 * @brief CPSetKeyParam export function
 */
BOOL WINAPI CPSetKeyParam(
    IN HCRYPTPROV hProv,
    IN HCRYPTKEY hKey,
    IN DWORD dwParam,
    IN CONST BYTE *pbData,
    IN DWORD dwFlags
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPSetKeyParam(hProv, hKey, dwParam, pbData, dwFlags);
}

/**
 * @brief CPGetKeyParam export function
 */
BOOL WINAPI CPGetKeyParam(
    IN HCRYPTPROV hProv,
    IN HCRYPTKEY hKey,
    IN DWORD dwParam,
    OUT BYTE *pbData,
    IN OUT DWORD *pdwDataLen,
    IN DWORD dwFlags
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPGetKeyParam(hProv, hKey, dwParam, pbData, pdwDataLen, dwFlags);
}

/**
 * @brief CPExportKey export function
 */
BOOL WINAPI CPExportKey(
    IN HCRYPTPROV hProv,
    IN HCRYPTKEY hKey,
    IN HCRYPTKEY hExpKey,
    IN DWORD dwBlobType,
    IN DWORD dwFlags,
    OUT BYTE *pbData,
    IN OUT DWORD *pdwDataLen
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPExportKey(hProv, hKey, hExpKey, dwBlobType, dwFlags, pbData, pdwDataLen);
}

/**
 * @brief CPImportKey export function
 */
BOOL WINAPI CPImportKey(
    IN HCRYPTPROV hProv,
    IN CONST BYTE *pbData,
    IN DWORD dwDataLen,
    IN HCRYPTKEY hImpKey,
    IN DWORD dwFlags,
    OUT HCRYPTKEY *phKey
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPImportKey(hProv, pbData, dwDataLen, hImpKey, dwFlags, phKey);
}

/**
 * @brief CPEncrypt export function
 */
BOOL WINAPI CPEncrypt(
    IN HCRYPTPROV hProv,
    IN HCRYPTKEY hKey,
    IN HCRYPTHASH hHash,
    IN BOOL fFinal,
    IN DWORD dwFlags,
    IN OUT BYTE *pbData,
    IN OUT DWORD *pdwDataLen,
    IN DWORD dwBufLen
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPEncrypt(hProv, hKey, hHash, fFinal, dwFlags, pbData, pdwDataLen, dwBufLen);
}

/**
 * @brief CPDecrypt export function
 */
BOOL WINAPI CPDecrypt(
    IN HCRYPTPROV hProv,
    IN HCRYPTKEY hKey,
    IN HCRYPTHASH hHash,
    IN BOOL fFinal,
    IN DWORD dwFlags,
    IN OUT BYTE *pbData,
    IN OUT DWORD *pdwDataLen
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPDecrypt(hProv, hKey, hHash, fFinal, dwFlags, pbData, pdwDataLen);
}

/**
 * @brief CPCreateHash export function
 */
BOOL WINAPI CPCreateHash(
    IN HCRYPTPROV hProv,
    IN ALG_ID Algid,
    IN HCRYPTKEY hKey,
    IN DWORD dwFlags,
    OUT HCRYPTHASH *phHash
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPCreateHash(hProv, Algid, hKey, dwFlags, phHash);
}

/**
 * @brief CPDestroyHash export function
 */
BOOL WINAPI CPDestroyHash(
    IN HCRYPTPROV hProv,
    IN HCRYPTHASH hHash
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPDestroyHash(hProv, hHash);
}

/**
 * @brief CPSetHashParam export function
 */
BOOL WINAPI CPSetHashParam(
    IN HCRYPTPROV hProv,
    IN HCRYPTHASH hHash,
    IN DWORD dwParam,
    IN CONST BYTE *pbData,
    IN DWORD dwFlags
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPSetHashParam(hProv, hHash, dwParam, pbData, dwFlags);
}

/**
 * @brief CPGetHashParam export function
 */
BOOL WINAPI CPGetHashParam(
    IN HCRYPTPROV hProv,
    IN HCRYPTHASH hHash,
    IN DWORD dwParam,
    OUT BYTE *pbData,
    IN OUT DWORD *pdwDataLen,
    IN DWORD dwFlags
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPGetHashParam(hProv, hHash, dwParam, pbData, pdwDataLen, dwFlags);
}

/**
 * @brief CPHashData export function
 */
BOOL WINAPI CPHashData(
    IN HCRYPTPROV hProv,
    IN HCRYPTHASH hHash,
    IN CONST BYTE *pbData,
    IN DWORD dwDataLen,
    IN DWORD dwFlags
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPHashData(hProv, hHash, pbData, dwDataLen, dwFlags);
}

/**
 * @brief CPHashSessionKey export function
 */
BOOL WINAPI CPHashSessionKey(
    IN HCRYPTPROV hProv,
    IN HCRYPTHASH hHash,
    IN HCRYPTKEY hKey,
    IN DWORD dwFlags
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPHashSessionKey(hProv, hHash, hKey, dwFlags);
}

/**
 * @brief CPSignHash export function
 */
BOOL WINAPI CPSignHash(
    IN HCRYPTPROV hProv,
    IN HCRYPTHASH hHash,
    IN DWORD dwKeySpec,
    IN LPCWSTR sDescription,
    IN DWORD dwFlags,
    OUT BYTE *pbSignature,
    IN OUT DWORD *pdwSigLen
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPSignHash(hProv, hHash, dwKeySpec, sDescription, dwFlags, pbSignature, pdwSigLen);
}

/**
 * @brief CPVerifySignature export function
 */
BOOL WINAPI CPVerifySignature(
    IN HCRYPTPROV hProv,
    IN HCRYPTHASH hHash,
    IN CONST BYTE *pbSignature,
    IN DWORD dwSigLen,
    IN HCRYPTKEY hPubKey,
    IN LPCWSTR sDescription,
    IN DWORD dwFlags
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPVerifySignature(hProv, hHash, pbSignature, dwSigLen, hPubKey, sDescription, dwFlags);
}

/**
 * @brief CPGenRandom export function
 */
BOOL WINAPI CPGenRandom(
    IN HCRYPTPROV hProv,
    IN DWORD dwLen,
    OUT BYTE *pbBuffer
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPGenRandom(hProv, dwLen, pbBuffer);
}

/**
 * @brief CPGetUserKey export function
 */
BOOL WINAPI CPGetUserKey(
    IN HCRYPTPROV hProv,
    IN DWORD dwKeySpec,
    OUT HCRYPTKEY *phUserKey
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPGetUserKey(hProv, dwKeySpec, phUserKey);
}

/**
 * @brief CPSetProvParam export function
 */
BOOL WINAPI CPSetProvParam(
    IN HCRYPTPROV hProv,
    IN DWORD dwParam,
    IN CONST BYTE *pbData,
    IN DWORD dwFlags
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPSetProvParam(hProv, dwParam, pbData, dwFlags);
}

/**
 * @brief CPGetProvParam export function
 */
BOOL WINAPI CPGetProvParam(
    IN HCRYPTPROV hProv,
    IN DWORD dwParam,
    OUT BYTE *pbData,
    IN OUT DWORD *pdwDataLen,
    IN DWORD dwFlags
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPGetProvParam(hProv, dwParam, pbData, pdwDataLen, dwFlags);
}

/**
 * @brief CPDeriveKey export function
 */
BOOL WINAPI CPDeriveKey(
    IN HCRYPTPROV hProv,
    IN ALG_ID Algid,
    IN HCRYPTHASH hBaseData,
    IN DWORD dwFlags,
    OUT HCRYPTKEY *phKey
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPDeriveKey(hProv, Algid, hBaseData, dwFlags, phKey);
}

/**
 * @brief CPDuplicateHash export function
 */
BOOL WINAPI CPDuplicateHash(
    IN HCRYPTPROV hProv,
    IN HCRYPTHASH hHash,
    IN DWORD *pdwReserved,
    IN DWORD dwFlags,
    OUT HCRYPTHASH *phHash
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPDuplicateHash(hProv, hHash, pdwReserved, dwFlags, phHash);
}

/**
 * @brief CPDuplicateKey export function
 */
BOOL WINAPI CPDuplicateKey(
    IN HCRYPTPROV hProv,
    IN HCRYPTKEY hKey,
    IN DWORD *pdwReserved,
    IN DWORD dwFlags,
    OUT HCRYPTKEY *phKey
)
{
    if (!g_bInitialized) {
        supacrypt::csp::SetLastCspError(NTE_PROVIDER_DLL_FAIL);
        return FALSE;
    }
    
    return supacrypt::csp::Internal_CPDuplicateKey(hProv, hKey, pdwReserved, dwFlags, phKey);
}

} // extern "C"