# tests/CMakeLists.txt - Enhanced CSP Test Suite for Task 4.3
# Copyright (c) 2025 ludicrypt. All rights reserved.
# Licensed under the MIT License.

if(NOT BUILD_TESTING)
    return()
endif()

# Find testing dependencies
find_package(GTest REQUIRED)
find_package(GMock REQUIRED)

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Enhanced test framework library for CSP
add_library(csp_test_framework STATIC
    framework/test_framework.cpp
    framework/performance_profiler.cpp
    framework/security_validator.cpp
    framework/windows_test_utils.cpp
)

target_link_libraries(csp_test_framework
    supacrypt::csp
    GTest::gtest
    GTest::gmock
    crypt32
    advapi32
    kernel32
    psapi
)

target_include_directories(csp_test_framework PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/framework
)

# Enhanced unit tests for 100% coverage
add_executable(csp_enhanced_unit_tests
    enhanced/enhanced_unit_tests.cpp
    enhanced/stress_tests.cpp
    enhanced/edge_case_tests.cpp
    enhanced/concurrent_tests.cpp
)

target_link_libraries(csp_enhanced_unit_tests
    csp_test_framework
    GTest::gtest_main
)

# Performance benchmark tests
add_executable(csp_performance_tests
    performance/initialization_benchmarks.cpp
    performance/key_generation_benchmarks.cpp
    performance/signature_benchmarks.cpp
    performance/load_tests.cpp
)

target_link_libraries(csp_performance_tests
    csp_test_framework
    GTest::gtest_main
)

# Security validation tests
add_executable(csp_security_tests
    security/access_control_tests.cpp
    security/handle_security_tests.cpp
    security/memory_security_tests.cpp
    security/attack_simulation_tests.cpp
)

target_link_libraries(csp_security_tests
    csp_test_framework
    GTest::gtest_main
)

# Windows API integration tests
add_executable(csp_integration_tests
    integration/capi_compliance_tests.cpp
    integration/certificate_enrollment_tests.cpp
    integration/system_integration_tests.cpp
    integration/application_compatibility_tests.cpp
)

target_link_libraries(csp_integration_tests
    csp_test_framework
    GTest::gtest_main
    cryptui
    certcli
)

# Multi-architecture tests
add_executable(csp_architecture_tests
    architecture/x86_compatibility_tests.cpp
    architecture/x64_optimization_tests.cpp
    architecture/cross_platform_tests.cpp
)

target_link_libraries(csp_architecture_tests
    csp_test_framework
    GTest::gtest_main
)

# Compliance tests
add_executable(csp_compliance_tests
    compliance/capi_standard_compliance.cpp
    compliance/algorithm_compliance.cpp
    compliance/error_handling_compliance.cpp
)

target_link_libraries(csp_compliance_tests
    csp_test_framework
    GTest::gtest_main
)

# Test configuration
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/test_config.h.in
    ${CMAKE_CURRENT_BINARY_DIR}/test_config.h
)

# Test runner executable
add_executable(csp_test_runner
    test_runner.cpp
)

target_link_libraries(csp_test_runner
    csp_test_framework
    GTest::gtest_main
)

# Custom test targets
add_custom_target(csp_run_all_tests
    COMMAND csp_test_runner --gtest_output=xml:csp_test_results.xml
    DEPENDS csp_test_runner
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

add_custom_target(csp_coverage_tests
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/run_csp_coverage.ps1
    DEPENDS csp_test_runner
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

add_custom_target(csp_performance_validation
    COMMAND csp_performance_tests --gtest_output=xml:csp_performance_results.xml
    DEPENDS csp_performance_tests
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

add_custom_target(csp_security_assessment
    COMMAND csp_security_tests --gtest_output=xml:csp_security_results.xml
    DEPENDS csp_security_tests
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

# Add all tests to CTest
add_test(NAME CSP_Enhanced_Unit_Tests COMMAND csp_enhanced_unit_tests)
add_test(NAME CSP_Performance_Tests COMMAND csp_performance_tests)
add_test(NAME CSP_Security_Tests COMMAND csp_security_tests)
add_test(NAME CSP_Integration_Tests COMMAND csp_integration_tests)
add_test(NAME CSP_Architecture_Tests COMMAND csp_architecture_tests)
add_test(NAME CSP_Compliance_Tests COMMAND csp_compliance_tests)

# Installation
install(TARGETS csp_test_runner
    DESTINATION bin
)

install(DIRECTORY scripts/
    DESTINATION scripts
    FILES_MATCHING PATTERN "*.ps1"
)

message(STATUS "Configured Enhanced CSP Test Suite (Task 4.3):")
message(STATUS "  Enhanced Unit Tests: 100% coverage target")
message(STATUS "  Performance Tests: CSP targets (Init<100ms, Sign<100ms, KeyGen<3s)")
message(STATUS "  Security Tests: Comprehensive vulnerability assessment")
message(STATUS "  Integration Tests: Windows API and application compatibility")
message(STATUS "  Architecture Tests: x86, x64, cross-platform validation")
message(STATUS "  Compliance Tests: CAPI standard compliance")