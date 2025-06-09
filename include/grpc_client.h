/**
 * @file grpc_client.h
 * @brief gRPC client for Supacrypt backend communication
 * 
 * This file defines the gRPC client class that handles communication
 * with the Supacrypt backend service, including connection pooling,
 * circuit breaker pattern, and error handling.
 * 
 * @copyright Copyright (c) 2025 ludicrypt
 * @license MIT License
 */

#ifndef SUPACRYPT_CSP_GRPC_CLIENT_H
#define SUPACRYPT_CSP_GRPC_CLIENT_H

#ifdef ENABLE_GRPC

#include <memory>
#include <string>
#include <vector>
#include <chrono>
#include <mutex>
#include <atomic>
#include <map>

// gRPC and protobuf includes
#include <grpcpp/grpcpp.h>
#include "supacrypt.grpc.pb.h"

namespace supacrypt::csp {

/**
 * @brief Circuit breaker states
 */
enum class CircuitBreakerState {
    CLOSED,     // Normal operation
    OPEN,       // Circuit is open, rejecting requests
    HALF_OPEN   // Testing if service is back up
};

/**
 * @brief Connection pool configuration
 */
struct ConnectionPoolConfig {
    size_t maxConnections = 10;         // Maximum number of connections
    std::chrono::seconds idleTimeout{30}; // Idle connection timeout
    std::chrono::seconds connectTimeout{5}; // Connection timeout
    std::chrono::seconds requestTimeout{10}; // Request timeout
    bool enableTls = true;              // Enable TLS/mTLS
    std::string serverAddress = "localhost:50051"; // Backend server address
    std::string clientCertPath;         // Client certificate path
    std::string clientKeyPath;          // Client private key path
    std::string caCertPath;             // CA certificate path
};

/**
 * @brief Circuit breaker configuration
 */
struct CircuitBreakerConfig {
    size_t failureThreshold = 5;       // Failures before opening circuit
    std::chrono::seconds timeout{60};   // Time before trying half-open
    size_t halfOpenMaxCalls = 3;       // Max calls in half-open state
    double successThreshold = 0.6;     // Success rate to close circuit
};

/**
 * @brief gRPC operation result
 */
template<typename T>
struct GrpcResult {
    bool success = false;
    grpc::Status status;
    T response;
    std::string errorMessage;
    
    bool IsSuccess() const { return success && status.ok(); }
    std::string GetErrorMessage() const {
        if (!errorMessage.empty()) return errorMessage;
        if (!status.ok()) return status.error_message();
        return "Unknown error";
    }
};

/**
 * @brief Connection pool entry
 */
struct PooledConnection {
    std::shared_ptr<grpc::Channel> channel;
    std::unique_ptr<supacrypt::v1::SupacryptService::Stub> stub;
    std::chrono::steady_clock::time_point lastUsed;
    std::atomic<bool> inUse{false};
    
    PooledConnection(std::shared_ptr<grpc::Channel> ch);
    bool IsIdle(const std::chrono::seconds& timeout) const;
};

/**
 * @brief gRPC client with connection pooling and circuit breaker
 */
class GrpcClient {
public:
    /**
     * @brief Constructor
     * @param poolConfig Connection pool configuration
     * @param cbConfig Circuit breaker configuration
     */
    explicit GrpcClient(
        const ConnectionPoolConfig& poolConfig = ConnectionPoolConfig{},
        const CircuitBreakerConfig& cbConfig = CircuitBreakerConfig{}
    );
    
    /**
     * @brief Destructor
     */
    ~GrpcClient();
    
    // Disable copy constructor and assignment
    GrpcClient(const GrpcClient&) = delete;
    GrpcClient& operator=(const GrpcClient&) = delete;
    
    // Enable move constructor and assignment
    GrpcClient(GrpcClient&&) = default;
    GrpcClient& operator=(GrpcClient&&) = default;
    
    /**
     * @brief Initialize the client
     * @return true on success, false on failure
     */
    bool Initialize();
    
    /**
     * @brief Shutdown the client
     */
    void Shutdown();
    
    /**
     * @brief Check if the client is ready
     * @return true if ready, false otherwise
     */
    bool IsReady() const;
    
    // Cryptographic operations
    
    /**
     * @brief Generate a cryptographic key
     * @param request Key generation request
     * @return Operation result with response
     */
    GrpcResult<supacrypt::v1::GenerateKeyResponse> GenerateKey(
        const supacrypt::v1::GenerateKeyRequest& request
    );
    
    /**
     * @brief Sign data
     * @param request Signing request
     * @return Operation result with response
     */
    GrpcResult<supacrypt::v1::SignDataResponse> SignData(
        const supacrypt::v1::SignDataRequest& request
    );
    
    /**
     * @brief Verify signature
     * @param request Verification request
     * @return Operation result with response
     */
    GrpcResult<supacrypt::v1::VerifySignatureResponse> VerifySignature(
        const supacrypt::v1::VerifySignatureRequest& request
    );
    
    /**
     * @brief Get key information
     * @param request Key retrieval request
     * @return Operation result with response
     */
    GrpcResult<supacrypt::v1::GetKeyResponse> GetKey(
        const supacrypt::v1::GetKeyRequest& request
    );
    
    /**
     * @brief List available keys
     * @param request Key listing request
     * @return Operation result with response
     */
    GrpcResult<supacrypt::v1::ListKeysResponse> ListKeys(
        const supacrypt::v1::ListKeysRequest& request
    );
    
    /**
     * @brief Delete a key
     * @param request Key deletion request
     * @return Operation result with response
     */
    GrpcResult<supacrypt::v1::DeleteKeyResponse> DeleteKey(
        const supacrypt::v1::DeleteKeyRequest& request
    );
    
    /**
     * @brief Encrypt data
     * @param request Encryption request
     * @return Operation result with response
     */
    GrpcResult<supacrypt::v1::EncryptDataResponse> EncryptData(
        const supacrypt::v1::EncryptDataRequest& request
    );
    
    /**
     * @brief Decrypt data
     * @param request Decryption request
     * @return Operation result with response
     */
    GrpcResult<supacrypt::v1::DecryptDataResponse> DecryptData(
        const supacrypt::v1::DecryptDataRequest& request
    );
    
    // Connection management
    
    /**
     * @brief Get connection pool statistics
     * @return Map of statistics
     */
    std::map<std::string, size_t> GetConnectionStats() const;
    
    /**
     * @brief Get circuit breaker state
     * @return Current circuit breaker state
     */
    CircuitBreakerState GetCircuitBreakerState() const;
    
    /**
     * @brief Reset circuit breaker to closed state
     */
    void ResetCircuitBreaker();

private:
    // Configuration
    ConnectionPoolConfig poolConfig_;
    CircuitBreakerConfig cbConfig_;
    
    // Connection pool
    mutable std::mutex poolMutex_;
    std::vector<std::unique_ptr<PooledConnection>> connectionPool_;
    
    // Circuit breaker state
    mutable std::mutex cbMutex_;
    std::atomic<CircuitBreakerState> cbState_{CircuitBreakerState::CLOSED};
    std::atomic<size_t> failureCount_{0};
    std::atomic<size_t> halfOpenCalls_{0};
    std::atomic<size_t> halfOpenSuccesses_{0};
    std::chrono::steady_clock::time_point lastFailureTime_;
    
    // Statistics
    mutable std::mutex statsMutex_;
    std::atomic<size_t> totalRequests_{0};
    std::atomic<size_t> successfulRequests_{0};
    std::atomic<size_t> failedRequests_{0};
    std::atomic<size_t> circuitBreakerRejects_{0};
    
    // Initialization state
    std::atomic<bool> initialized_{false};
    
    // Internal methods
    
    /**
     * @brief Create a new gRPC channel
     * @return Shared pointer to the channel
     */
    std::shared_ptr<grpc::Channel> CreateChannel();
    
    /**
     * @brief Get a connection from the pool
     * @return Pooled connection or nullptr if unavailable
     */
    std::unique_ptr<PooledConnection> AcquireConnection();
    
    /**
     * @brief Return a connection to the pool
     * @param connection Connection to return
     */
    void ReleaseConnection(std::unique_ptr<PooledConnection> connection);
    
    /**
     * @brief Clean up idle connections
     */
    void CleanupIdleConnections();
    
    /**
     * @brief Execute a gRPC operation with circuit breaker protection
     * @param operation Function that performs the gRPC call
     * @return Operation result
     */
    template<typename TResponse>
    GrpcResult<TResponse> ExecuteWithCircuitBreaker(
        std::function<GrpcResult<TResponse>()> operation
    );
    
    /**
     * @brief Handle operation success for circuit breaker
     */
    void HandleSuccess();
    
    /**
     * @brief Handle operation failure for circuit breaker
     */
    void HandleFailure();
    
    /**
     * @brief Check if circuit breaker allows the request
     * @return true if request is allowed, false otherwise
     */
    bool IsRequestAllowed();
    
    /**
     * @brief Load TLS credentials
     * @return gRPC channel credentials
     */
    std::shared_ptr<grpc::ChannelCredentials> LoadTlsCredentials();
};

/**
 * @brief Factory function to create a gRPC client
 * @param poolConfig Connection pool configuration
 * @param cbConfig Circuit breaker configuration
 * @return Unique pointer to the client
 */
std::unique_ptr<GrpcClient> CreateGrpcClient(
    const ConnectionPoolConfig& poolConfig = ConnectionPoolConfig{},
    const CircuitBreakerConfig& cbConfig = CircuitBreakerConfig{}
);

} // namespace supacrypt::csp

#else // !ENABLE_GRPC

namespace supacrypt::csp {

// Stub implementation when gRPC is disabled
class GrpcClient {
public:
    bool Initialize() { return false; }
    void Shutdown() {}
    bool IsReady() const { return false; }
    
    template<typename T>
    struct GrpcResult {
        bool success = false;
        std::string errorMessage = "gRPC support not enabled";
    };
    
    // All operations return failure when gRPC is disabled
    GrpcResult<void> GenerateKey(const void*) { return {}; }
    GrpcResult<void> SignData(const void*) { return {}; }
    GrpcResult<void> VerifySignature(const void*) { return {}; }
    GrpcResult<void> GetKey(const void*) { return {}; }
    GrpcResult<void> ListKeys(const void*) { return {}; }
    GrpcResult<void> DeleteKey(const void*) { return {}; }
    GrpcResult<void> EncryptData(const void*) { return {}; }
    GrpcResult<void> DecryptData(const void*) { return {}; }
};

std::unique_ptr<GrpcClient> CreateGrpcClient() {
    return std::make_unique<GrpcClient>();
}

} // namespace supacrypt::csp

#endif // ENABLE_GRPC

#endif // SUPACRYPT_CSP_GRPC_CLIENT_H