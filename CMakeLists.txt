cmake_minimum_required(VERSION 3.20)

# Project definition
project(supacrypt-csp
    VERSION 1.0.0
    DESCRIPTION "Supacrypt Windows Cryptographic Service Provider (CSP)"
    LANGUAGES CXX C
)

# Set C++ and C standards
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# Build options
option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(BUILD_TESTING "Build tests" ON)
option(BUILD_EXAMPLES "Build examples" OFF)
option(BUILD_BENCHMARKS "Build benchmarks" OFF)
option(ENABLE_COVERAGE "Enable code coverage" OFF)
option(ENABLE_SANITIZERS "Enable sanitizers" OFF)
option(ENABLE_GRPC "Enable gRPC client support" ON)
option(ENABLE_OBSERVABILITY "Enable OpenTelemetry observability" OFF)
option(BUILD_INSTALLER "Build Windows installer package" OFF)

# Ensure we're building for Windows
if(NOT WIN32)
    message(FATAL_ERROR "supacrypt-csp can only be built on Windows")
endif()

# Enable Windows DLL symbol export
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

# Include modular CMake files
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(Dependencies)
include(CompilerOptions)
include(Platform)

# Enable gRPC and protobuf generation if requested
if(ENABLE_GRPC)
    include(ProtoGeneration)
endif()

# Add subdirectories
add_subdirectory(src)

# Add tests if enabled
if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()

# Add examples if enabled
if(BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

# Include installation and packaging
include(Installation)
if(BUILD_INSTALLER)
    include(Packaging)
endif()

# Print configuration summary
message(STATUS "")
message(STATUS "supacrypt-csp configuration summary:")
message(STATUS "  Version: ${PROJECT_VERSION}")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Shared libraries: ${BUILD_SHARED_LIBS}")
message(STATUS "  Testing: ${BUILD_TESTING}")
message(STATUS "  Examples: ${BUILD_EXAMPLES}")
message(STATUS "  Benchmarks: ${BUILD_BENCHMARKS}")
message(STATUS "  gRPC support: ${ENABLE_GRPC}")
message(STATUS "  Observability: ${ENABLE_OBSERVABILITY}")
message(STATUS "  Code coverage: ${ENABLE_COVERAGE}")
message(STATUS "  Sanitizers: ${ENABLE_SANITIZERS}")
message(STATUS "  Windows installer: ${BUILD_INSTALLER}")
message(STATUS "")