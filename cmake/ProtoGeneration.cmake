# ProtoGeneration.cmake - Protocol buffer and gRPC code generation for supacrypt-csp

# Ensure gRPC is available
if(NOT ENABLE_GRPC)
    message(FATAL_ERROR "ProtoGeneration.cmake requires ENABLE_GRPC=ON")
endif()

# Find required tools
find_program(PROTOC_EXECUTABLE protoc)
find_program(GRPC_CPP_PLUGIN_EXECUTABLE grpc_cpp_plugin)

if(NOT PROTOC_EXECUTABLE)
    message(FATAL_ERROR "protoc not found. Please install Protocol Buffers.")
endif()

if(NOT GRPC_CPP_PLUGIN_EXECUTABLE)
    message(FATAL_ERROR "grpc_cpp_plugin not found. Please install gRPC.")
endif()

# Path to the shared protobuf file
set(SUPACRYPT_PROTO_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../supacrypt-common/proto")
set(SUPACRYPT_PROTO_FILE "${SUPACRYPT_PROTO_DIR}/supacrypt.proto")

# Verify the proto file exists
if(NOT EXISTS "${SUPACRYPT_PROTO_FILE}")
    message(FATAL_ERROR "Supacrypt proto file not found: ${SUPACRYPT_PROTO_FILE}")
endif()

# Output directory for generated files
set(PROTO_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated/proto")
file(MAKE_DIRECTORY "${PROTO_GENERATED_DIR}")

# Generated file names
set(PROTO_GENERATED_SOURCES
    "${PROTO_GENERATED_DIR}/supacrypt.pb.cc"
    "${PROTO_GENERATED_DIR}/supacrypt.grpc.pb.cc"
)

set(PROTO_GENERATED_HEADERS
    "${PROTO_GENERATED_DIR}/supacrypt.pb.h"
    "${PROTO_GENERATED_DIR}/supacrypt.grpc.pb.h"
)

# Custom command to generate protobuf files
add_custom_command(
    OUTPUT ${PROTO_GENERATED_SOURCES} ${PROTO_GENERATED_HEADERS}
    COMMAND ${PROTOC_EXECUTABLE}
        --proto_path="${SUPACRYPT_PROTO_DIR}"
        --cpp_out="${PROTO_GENERATED_DIR}"
        --grpc_out="${PROTO_GENERATED_DIR}"
        --plugin=protoc-gen-grpc="${GRPC_CPP_PLUGIN_EXECUTABLE}"
        "${SUPACRYPT_PROTO_FILE}"
    DEPENDS "${SUPACRYPT_PROTO_FILE}"
    COMMENT "Generating protobuf and gRPC files for supacrypt-csp"
    VERBATIM
)

# Create a library target for the generated protobuf code
add_library(supacrypt_proto_csp STATIC
    ${PROTO_GENERATED_SOURCES}
    ${PROTO_GENERATED_HEADERS}
)

# Set target properties
set_target_properties(supacrypt_proto_csp PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    POSITION_INDEPENDENT_CODE ON
)

# Include directories for the generated files
target_include_directories(supacrypt_proto_csp PUBLIC
    $<BUILD_INTERFACE:${PROTO_GENERATED_DIR}>
    $<INSTALL_INTERFACE:include>
)

# Link against gRPC and protobuf libraries
target_link_libraries(supacrypt_proto_csp PUBLIC
    gRPC::grpc++
    gRPC::grpc++_reflection
    protobuf::libprotobuf
)

# Apply compiler options
if(COMMAND apply_csp_compile_options)
    apply_csp_compile_options(supacrypt_proto_csp)
endif()

# Suppress warnings in generated code
if(MSVC)
    target_compile_options(supacrypt_proto_csp PRIVATE
        /wd4100  # Unreferenced formal parameter
        /wd4127  # Conditional expression is constant
        /wd4244  # Conversion from type1 to type2, possible loss of data
        /wd4267  # Conversion from size_t to type, possible loss of data
        /wd4996  # Function or variable may be unsafe
    )
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(supacrypt_proto_csp PRIVATE
        -Wno-unused-parameter
        -Wno-sign-conversion
        -Wno-conversion
        -Wno-shadow
    )
endif()

# Create a custom target for proto generation (useful for IDEs)
add_custom_target(generate_protos_csp
    DEPENDS ${PROTO_GENERATED_SOURCES} ${PROTO_GENERATED_HEADERS}
    COMMENT "Generating Protocol Buffer files for CSP"
)

# Make the proto library depend on the generation target
add_dependencies(supacrypt_proto_csp generate_protos_csp)

# Function to link proto library to other targets
function(link_supacrypt_proto target_name)
    target_link_libraries(${target_name} PRIVATE supacrypt_proto_csp)
    
    # Ensure proto files are generated before building the target
    add_dependencies(${target_name} generate_protos_csp)
    
    message(STATUS "Linked supacrypt proto library to target: ${target_name}")
endfunction()

# Installation rules for proto library
install(TARGETS supacrypt_proto_csp
    EXPORT SupacryptCSPTargets
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
    INCLUDES DESTINATION include
)

# Install generated headers
install(FILES ${PROTO_GENERATED_HEADERS}
    DESTINATION include/supacrypt/proto
)

message(STATUS "Protocol buffer configuration:")
message(STATUS "  Proto file: ${SUPACRYPT_PROTO_FILE}")
message(STATUS "  Generated directory: ${PROTO_GENERATED_DIR}")
message(STATUS "  Generated sources: ${PROTO_GENERATED_SOURCES}")
message(STATUS "  Generated headers: ${PROTO_GENERATED_HEADERS}")
message(STATUS "  protoc: ${PROTOC_EXECUTABLE}")
message(STATUS "  grpc_cpp_plugin: ${GRPC_CPP_PLUGIN_EXECUTABLE}")