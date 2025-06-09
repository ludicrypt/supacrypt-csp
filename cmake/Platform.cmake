# Platform.cmake - Windows-specific platform configurations for supacrypt-csp

# Ensure we're on Windows
if(NOT WIN32)
    message(FATAL_ERROR "supacrypt-csp requires Windows platform")
endif()

# Windows version requirements
set(MIN_WINDOWS_VERSION 0x0601)  # Windows 7
add_compile_definitions(_WIN32_WINNT=${MIN_WINDOWS_VERSION})

# Windows-specific compile definitions
set(WINDOWS_COMPILE_DEFINITIONS
    WIN32_LEAN_AND_MEAN         # Reduce Windows header bloat
    NOMINMAX                    # Prevent min/max macro conflicts with std::min/max
    UNICODE                     # Use Unicode versions of Windows APIs
    _UNICODE                    # Use Unicode versions of C runtime
    _CRT_SECURE_NO_WARNINGS     # Disable CRT security warnings
    _WINSOCK_DEPRECATED_NO_WARNINGS  # Disable Winsock deprecation warnings
)

add_compile_definitions(${WINDOWS_COMPILE_DEFINITIONS})

# Windows SDK requirements
if(MSVC)
    # Ensure we have at least Windows 10 SDK (10.0.19041.0 or later)
    if(CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION)
        if(CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION VERSION_LESS "10.0.19041.0")
            message(WARNING "Windows 10 SDK 10.0.19041.0 or later is recommended")
        endif()
    endif()
endif()

# Windows-specific linker settings
if(BUILD_SHARED_LIBS)
    # Enable DLL symbol export
    set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
    
    # Set DLL characteristics
    if(MSVC)
        # Enable DEP (Data Execution Prevention)
        add_link_options(/NXCOMPAT)
        
        # Enable ASLR (Address Space Layout Randomization)
        add_link_options(/DYNAMICBASE)
        
        # Enable high entropy ASLR for 64-bit
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            add_link_options(/HIGHENTROPYVA)
        endif()
        
        # Set subsystem to Windows (GUI) for CSP DLL
        add_link_options(/SUBSYSTEM:WINDOWS)
    endif()
endif()

# Windows architecture detection
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(WINDOWS_ARCH "x64")
    set(WINDOWS_ARCH_SUFFIX "64")
    message(STATUS "Building for Windows x64")
elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
    set(WINDOWS_ARCH "x86")
    set(WINDOWS_ARCH_SUFFIX "32")
    message(STATUS "Building for Windows x86")
else()
    message(FATAL_ERROR "Unsupported Windows architecture")
endif()

# Registry paths for CSP registration
set(CSP_REGISTRY_ROOT "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Cryptography\\Defaults\\Provider")
set(CSP_REGISTRY_TYPES_ROOT "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Cryptography\\Defaults\\Provider Types")

# CSP-specific definitions
set(CSP_COMPILE_DEFINITIONS
    # CSP provider type (PROV_RSA_FULL)
    CSP_PROVIDER_TYPE=1
    
    # CSP version
    CSP_VERSION_MAJOR=1
    CSP_VERSION_MINOR=0
    
    # Registry paths
    CSP_REGISTRY_PATH="${CSP_REGISTRY_ROOT}"
    CSP_TYPES_REGISTRY_PATH="${CSP_REGISTRY_TYPES_ROOT}"
)

add_compile_definitions(${CSP_COMPILE_DEFINITIONS})

# Windows system libraries required for CSP
set(CSP_SYSTEM_LIBRARIES
    advapi32    # Registry and advanced APIs
    crypt32     # Windows Cryptography APIs
    user32      # User interface functions
    kernel32    # Core Windows functions
    ws2_32      # Windows Sockets API
    rpcrt4      # UUID generation
    secur32     # Security support provider interface
)

# Function to configure Windows CSP target
function(configure_csp_target target_name)
    # Link Windows system libraries
    target_link_libraries(${target_name} PRIVATE ${CSP_SYSTEM_LIBRARIES})
    
    # Set Windows-specific target properties
    set_target_properties(${target_name} PROPERTIES
        # Set DLL module definition file if it exists
        LINK_FLAGS_RELEASE "/DEF:${CMAKE_CURRENT_SOURCE_DIR}/${target_name}.def"
        LINK_FLAGS_DEBUG "/DEF:${CMAKE_CURRENT_SOURCE_DIR}/${target_name}.def"
        
        # Set output name pattern
        OUTPUT_NAME "${target_name}"
        SUFFIX ".dll"
        
        # Set import library name
        ARCHIVE_OUTPUT_NAME "${target_name}"
        
        # Version information
        VERSION ${PROJECT_VERSION}
        SOVERSION ${PROJECT_VERSION_MAJOR}
    )
    
    # Add Windows-specific include directories
    target_include_directories(${target_name} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include/windows
    )
    
    message(STATUS "Configured Windows CSP target: ${target_name}")
endfunction()

# Function to create CSP installation rules
function(create_csp_install_rules target_name)
    # Install the CSP DLL to System32 directory (requires admin privileges)
    install(TARGETS ${target_name}
        RUNTIME DESTINATION "bin"
        LIBRARY DESTINATION "lib"
        ARCHIVE DESTINATION "lib"
    )
    
    # Install headers
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/"
        DESTINATION "include"
        FILES_MATCHING PATTERN "*.h"
    )
    
    message(STATUS "Created installation rules for CSP: ${target_name}")
endfunction()

# Registry helper functions for CSP registration
set(CSP_PROVIDER_NAME "Supacrypt CSP")
set(CSP_DLL_NAME "supacrypt-csp.dll")

message(STATUS "Windows platform configuration:")
message(STATUS "  Architecture: ${WINDOWS_ARCH}")
message(STATUS "  Minimum Windows version: ${MIN_WINDOWS_VERSION}")
message(STATUS "  CSP Provider Name: ${CSP_PROVIDER_NAME}")
message(STATUS "  CSP DLL Name: ${CSP_DLL_NAME}")
message(STATUS "  System Libraries: ${CSP_SYSTEM_LIBRARIES}")