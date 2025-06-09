# Installation.cmake - Installation rules for supacrypt-csp

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Set installation paths
set(CSP_INSTALL_BINDIR ${CMAKE_INSTALL_BINDIR})
set(CSP_INSTALL_LIBDIR ${CMAKE_INSTALL_LIBDIR})
set(CSP_INSTALL_INCLUDEDIR ${CMAKE_INSTALL_INCLUDEDIR})
set(CSP_INSTALL_CONFIGDIR ${CMAKE_INSTALL_LIBDIR}/cmake/SupacryptCSP)

# Install targets will be added by individual target CMakeLists.txt files
# This file sets up the package configuration

# Generate package configuration file
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/supacrypt-csp-config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/SupacryptCSPConfig.cmake"
    INSTALL_DESTINATION ${CSP_INSTALL_CONFIGDIR}
    PATH_VARS
        CSP_INSTALL_BINDIR
        CSP_INSTALL_LIBDIR
        CSP_INSTALL_INCLUDEDIR
)

# Generate package version file
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/SupacryptCSPConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

# Install package configuration files
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/SupacryptCSPConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/SupacryptCSPConfigVersion.cmake"
    DESTINATION ${CSP_INSTALL_CONFIGDIR}
)

# Install export set (will be populated by targets)
install(EXPORT SupacryptCSPTargets
    FILE SupacryptCSPTargets.cmake
    NAMESPACE SupacryptCSP::
    DESTINATION ${CSP_INSTALL_CONFIGDIR}
)

# Create uninstall target
if(NOT TARGET uninstall)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/cmake_uninstall.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
        IMMEDIATE @ONLY
    )
    
    add_custom_target(uninstall
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake
        COMMENT "Uninstalling supacrypt-csp"
    )
endif()

# Windows-specific installation
if(WIN32)
    # CSP DLL must be installed to System32 for system-wide registration
    # Note: This requires administrator privileges
    set(WINDOWS_SYSTEM32_DIR "$ENV{SystemRoot}/System32")
    
    # Install CSP DLL to bin directory (user can manually copy to System32)
    install(TARGETS supacrypt-csp
        RUNTIME DESTINATION ${CSP_INSTALL_BINDIR}
        COMPONENT Runtime
    )
    
    # Install development files
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/"
        DESTINATION ${CSP_INSTALL_INCLUDEDIR}
        COMPONENT Development
        FILES_MATCHING PATTERN "*.h"
    )
    
    # Install registration utility
    if(TARGET csp_register)
        install(TARGETS csp_register
            RUNTIME DESTINATION ${CSP_INSTALL_BINDIR}
            COMPONENT Tools
        )
    endif()
    
    # Install documentation
    install(FILES
        "${CMAKE_CURRENT_SOURCE_DIR}/README.md"
        "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE"
        DESTINATION "${CMAKE_INSTALL_DOCDIR}"
        COMPONENT Documentation
        OPTIONAL
    )
endif()

# Component-based installation
set(CPACK_COMPONENTS_ALL Runtime Development Tools Documentation)

set(CPACK_COMPONENT_RUNTIME_DISPLAY_NAME "Supacrypt CSP Runtime")
set(CPACK_COMPONENT_RUNTIME_DESCRIPTION "Core CSP DLL and runtime files")
set(CPACK_COMPONENT_RUNTIME_REQUIRED TRUE)

set(CPACK_COMPONENT_DEVELOPMENT_DISPLAY_NAME "Development Files")
set(CPACK_COMPONENT_DEVELOPMENT_DESCRIPTION "Headers and libraries for development")
set(CPACK_COMPONENT_DEVELOPMENT_DEPENDS Runtime)

set(CPACK_COMPONENT_TOOLS_DISPLAY_NAME "Registration Tools")
set(CPACK_COMPONENT_TOOLS_DESCRIPTION "CSP registration and management utilities")
set(CPACK_COMPONENT_TOOLS_DEPENDS Runtime)

set(CPACK_COMPONENT_DOCUMENTATION_DISPLAY_NAME "Documentation")
set(CPACK_COMPONENT_DOCUMENTATION_DESCRIPTION "User and developer documentation")

message(STATUS "Installation configuration:")
message(STATUS "  Install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "  Binary directory: ${CSP_INSTALL_BINDIR}")
message(STATUS "  Library directory: ${CSP_INSTALL_LIBDIR}")
message(STATUS "  Include directory: ${CSP_INSTALL_INCLUDEDIR}")
message(STATUS "  Config directory: ${CSP_INSTALL_CONFIGDIR}")
if(WIN32)
    message(STATUS "  Windows System32: ${WINDOWS_SYSTEM32_DIR}")
endif()