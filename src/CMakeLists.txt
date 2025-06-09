# src/CMakeLists.txt - Build configuration for supacrypt-csp source

# Create the main CSP library target
add_library(supacrypt-csp SHARED
    # Core CSP implementation
    csp_main.cpp
    csp_provider.cpp
    key_container.cpp
    crypto_operations.cpp
    error_handling.cpp
    
    # gRPC backend communication
    grpc_client.cpp
    
    # Headers (for IDE support)
    ${CMAKE_CURRENT_SOURCE_DIR}/../include/csp_provider.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../include/key_container.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../include/grpc_client.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../include/crypto_operations.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../include/error_handling.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../include/windows/csp_internal.h
)

# Set target properties
set_target_properties(supacrypt-csp PROPERTIES
    OUTPUT_NAME "supacrypt-csp"
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    
    # Windows-specific properties
    SUFFIX ".dll"
    PREFIX ""
    
    # Export all symbols for CSP functions
    WINDOWS_EXPORT_ALL_SYMBOLS ON
)

# Apply CSP-specific compile options
apply_csp_compile_options(supacrypt-csp)

# Configure as Windows CSP target
configure_csp_target(supacrypt-csp)

# Include directories
target_include_directories(supacrypt-csp
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/../include/windows
        ${CMAKE_CURRENT_SOURCE_DIR}
)

# Link system libraries
target_link_libraries(supacrypt-csp PRIVATE
    ${CSP_SYSTEM_LIBRARIES}
    Threads::Threads
)

# Link gRPC and protobuf if enabled
if(ENABLE_GRPC)
    link_supacrypt_proto(supacrypt-csp)
    target_compile_definitions(supacrypt-csp PRIVATE ENABLE_GRPC=1)
else()
    target_compile_definitions(supacrypt-csp PRIVATE ENABLE_GRPC=0)
endif()

# Link observability libraries if enabled
if(ENABLE_OBSERVABILITY)
    target_link_libraries(supacrypt-csp PRIVATE
        # Add OpenTelemetry libraries here when available
    )
    target_compile_definitions(supacrypt-csp PRIVATE ENABLE_OBSERVABILITY=1)
endif()

# Create module definition file for controlled exports
set(CSP_DEF_FILE "${CMAKE_CURRENT_SOURCE_DIR}/supacrypt-csp.def")
if(EXISTS "${CSP_DEF_FILE}")
    set_target_properties(supacrypt-csp PROPERTIES
        LINK_FLAGS "/DEF:${CSP_DEF_FILE}"
    )
endif()

# Installation rules
install(TARGETS supacrypt-csp
    EXPORT SupacryptCSPTargets
    RUNTIME DESTINATION ${CSP_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CSP_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CSP_INSTALL_LIBDIR}
    COMPONENT Runtime
)

# Create installation rules
create_csp_install_rules(supacrypt-csp)

message(STATUS "Configured supacrypt-csp library target")
message(STATUS "  Output name: supacrypt-csp.dll")
message(STATUS "  gRPC support: ${ENABLE_GRPC}")
message(STATUS "  Observability: ${ENABLE_OBSERVABILITY}")