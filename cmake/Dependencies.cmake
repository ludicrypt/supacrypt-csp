# Dependencies.cmake - Dependency management for supacrypt-csp

include(FetchContent)

# Set FetchContent options
set(FETCHCONTENT_QUIET FALSE)

# Required: Threading support
find_package(Threads REQUIRED)

# Windows-specific system libraries
if(WIN32)
    # Core Windows crypto and networking libraries
    set(WINDOWS_SYSTEM_LIBS
        advapi32      # Registry and crypto APIs
        crypt32       # Windows crypto APIs
        ws2_32        # Winsock
        user32        # User interface functions
        kernel32      # Core Windows functions
    )
endif()

# Optional: gRPC and Protocol Buffers
if(ENABLE_GRPC)
    message(STATUS "Fetching gRPC...")
    
    # Disable gRPC tests and examples to speed up build
    set(gRPC_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(gRPC_BUILD_CSHARP_EXT OFF CACHE BOOL "" FORCE)
    set(gRPC_BUILD_GRPC_CSHARP_PLUGIN OFF CACHE BOOL "" FORCE)
    set(gRPC_BUILD_GRPC_NODE_PLUGIN OFF CACHE BOOL "" FORCE)
    set(gRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN OFF CACHE BOOL "" FORCE)
    set(gRPC_BUILD_GRPC_PHP_PLUGIN OFF CACHE BOOL "" FORCE)
    set(gRPC_BUILD_GRPC_PYTHON_PLUGIN OFF CACHE BOOL "" FORCE)
    set(gRPC_BUILD_GRPC_RUBY_PLUGIN OFF CACHE BOOL "" FORCE)
    
    FetchContent_Declare(
        grpc
        GIT_REPOSITORY https://github.com/grpc/grpc.git
        GIT_TAG v1.65.0
        GIT_SHALLOW TRUE
    )
    
    FetchContent_MakeAvailable(grpc)
    
    # Set gRPC targets for linking
    set(GRPC_LIBRARIES
        gRPC::grpc++
        gRPC::grpc++_reflection
        protobuf::libprotobuf
    )
    
    message(STATUS "gRPC configured successfully")
endif()

# Optional: Google Test for testing
if(BUILD_TESTING)
    message(STATUS "Fetching Google Test...")
    
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.15.0
        GIT_SHALLOW TRUE
    )
    
    # Prevent overriding the parent project's compiler/linker settings on Windows
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    
    FetchContent_MakeAvailable(googletest)
    
    message(STATUS "Google Test configured successfully")
endif()

# Optional: Google Benchmark for performance testing
if(BUILD_BENCHMARKS)
    message(STATUS "Fetching Google Benchmark...")
    
    set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
    set(BENCHMARK_ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
    
    FetchContent_Declare(
        benchmark
        GIT_REPOSITORY https://github.com/google/benchmark.git
        GIT_TAG v1.8.3
        GIT_SHALLOW TRUE
    )
    
    FetchContent_MakeAvailable(benchmark)
    
    message(STATUS "Google Benchmark configured successfully")
endif()

# Optional: OpenTelemetry for observability
if(ENABLE_OBSERVABILITY)
    message(STATUS "Fetching OpenTelemetry C++...")
    
    set(WITH_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
    set(WITH_BENCHMARK OFF CACHE BOOL "" FORCE)
    
    FetchContent_Declare(
        opentelemetry-cpp
        GIT_REPOSITORY https://github.com/open-telemetry/opentelemetry-cpp.git
        GIT_TAG v1.16.0
        GIT_SHALLOW TRUE
    )
    
    FetchContent_MakeAvailable(opentelemetry-cpp)
    
    message(STATUS "OpenTelemetry C++ configured successfully")
endif()

# Summary of available dependencies
message(STATUS "Dependencies configured:")
message(STATUS "  Threading: ${CMAKE_THREAD_LIBS_INIT}")
if(WIN32)
    message(STATUS "  Windows libraries: ${WINDOWS_SYSTEM_LIBS}")
endif()
if(ENABLE_GRPC)
    message(STATUS "  gRPC: Available")
endif()
if(BUILD_TESTING)
    message(STATUS "  Google Test: Available")
endif()
if(BUILD_BENCHMARKS)
    message(STATUS "  Google Benchmark: Available")
endif()
if(ENABLE_OBSERVABILITY)
    message(STATUS "  OpenTelemetry: Available")
endif()