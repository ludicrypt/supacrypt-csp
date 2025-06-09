# CompilerOptions.cmake - Compiler-specific settings for supacrypt-csp

# Enable position independent code for shared libraries
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Set symbol visibility to hidden by default (Windows DLL export control)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN YES)

# Generate export header for clean API boundaries
include(GenerateExportHeader)

# Compiler-specific flags
if(MSVC)
    # MSVC-specific options
    set(MSVC_COMPILE_OPTIONS
        /W4                     # High warning level
        /WX                     # Treat warnings as errors
        /permissive-            # Disable non-conforming code
        /Zc:__cplusplus         # Enable correct __cplusplus macro
        /Zc:inline              # Remove unreferenced COMDAT
        /Zc:throwingNew         # Assume operator new throws
        /utf-8                  # Set source and execution character sets to UTF-8
    )
    
    # MSVC-specific definitions
    set(MSVC_COMPILE_DEFINITIONS
        WIN32_LEAN_AND_MEAN     # Exclude rarely-used Windows headers
        NOMINMAX                # Prevent min/max macro conflicts
        _WIN32_WINNT=0x0601     # Target Windows 7 and later
        _CRT_SECURE_NO_WARNINGS # Disable CRT security warnings
        _SILENCE_CXX17_DEPRECATION_WARNING  # Silence C++17 deprecation warnings
    )
    
    # Add MSVC options to global compile options
    add_compile_options(${MSVC_COMPILE_OPTIONS})
    add_compile_definitions(${MSVC_COMPILE_DEFINITIONS})
    
    # Release-specific optimizations
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        add_compile_options(/O2 /Ob2 /DNDEBUG)
        add_link_options(/OPT:REF /OPT:ICF)
    endif()
    
    # Debug-specific options
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_compile_options(/Od /Zi /RTC1)
        add_compile_definitions(_DEBUG)
    endif()
    
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    # GCC/Clang options (for cross-compilation scenarios)
    set(GCC_CLANG_COMPILE_OPTIONS
        -Wall
        -Wextra
        -Wpedantic
        -Werror
        -Wconversion
        -Wsign-conversion
        -Wcast-align
        -Wformat=2
        -Wuninitialized
        -Wnull-dereference
        -Wdouble-promotion
        -Wshadow
        -Wcast-qual
        -Wold-style-cast
    )
    
    add_compile_options(${GCC_CLANG_COMPILE_OPTIONS})
    
    # GCC/Clang-specific definitions for Windows cross-compilation
    if(WIN32)
        add_compile_definitions(
            WIN32_LEAN_AND_MEAN
            NOMINMAX
            _WIN32_WINNT=0x0601
        )
    endif()
    
    # Release optimizations
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        add_compile_options(-O3 -DNDEBUG)
        add_link_options(-s)  # Strip symbols
    endif()
    
    # Debug options
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_compile_options(-O0 -g -DDEBUG)
    endif()
endif()

# Sanitizer support
if(ENABLE_SANITIZERS)
    if(MSVC)
        # MSVC sanitizers (limited support)
        add_compile_options(/fsanitize=address)
        add_link_options(/fsanitize=address)
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        # GCC/Clang sanitizers
        set(SANITIZER_OPTIONS
            -fsanitize=address
            -fsanitize=undefined
            -fsanitize=leak
            -fno-omit-frame-pointer
        )
        add_compile_options(${SANITIZER_OPTIONS})
        add_link_options(${SANITIZER_OPTIONS})
    endif()
    
    message(STATUS "Sanitizers enabled")
endif()

# Code coverage support
if(ENABLE_COVERAGE)
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        add_compile_options(--coverage -fprofile-arcs -ftest-coverage)
        add_link_options(--coverage)
        
        # Find gcov or llvm-cov
        find_program(GCOV_EXECUTABLE gcov)
        if(NOT GCOV_EXECUTABLE)
            find_program(LLVM_COV_EXECUTABLE llvm-cov)
            if(LLVM_COV_EXECUTABLE)
                set(GCOV_EXECUTABLE "${LLVM_COV_EXECUTABLE} gcov")
            endif()
        endif()
        
        message(STATUS "Code coverage enabled with: ${GCOV_EXECUTABLE}")
    else()
        message(WARNING "Code coverage is only supported with GCC or Clang")
    endif()
endif()

# Function to apply common compile options to targets
function(apply_csp_compile_options target_name)
    # Set target properties
    set_target_properties(${target_name} PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
        C_STANDARD 17
        C_STANDARD_REQUIRED ON
        C_EXTENSIONS OFF
    )
    
    # Generate export header for the target
    generate_export_header(${target_name}
        EXPORT_FILE_NAME "${CMAKE_CURRENT_BINARY_DIR}/${target_name}_export.h"
        EXPORT_MACRO_NAME "${target_name}_EXPORT"
        NO_EXPORT_MACRO_NAME "${target_name}_NO_EXPORT"
        DEPRECATED_MACRO_NAME "${target_name}_DEPRECATED"
        NO_DEPRECATED_MACRO_NAME "${target_name}_NO_DEPRECATED"
    )
    
    # Add the export header to the target's include directories
    target_include_directories(${target_name} PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
    )
endfunction()

message(STATUS "Compiler options configured for: ${CMAKE_CXX_COMPILER_ID}")
if(MSVC)
    message(STATUS "  MSVC options: ${MSVC_COMPILE_OPTIONS}")
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    message(STATUS "  GCC/Clang options: ${GCC_CLANG_COMPILE_OPTIONS}")
endif()