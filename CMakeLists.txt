cmake_minimum_required(VERSION 3.2)

set(BUILD_OPENSSL OFF CACHE BOOL "Automated OpenSSL building")
set(OPENSSL_BRANCH OFF CACHE STRING "OpenSSL branch (or tag) to build")
set(OPENSSL_INSTALL_MAN OFF CACHE STRING "Install man pages?")
set(CROSS_ANDROID OFF CACHE BOOL "Cross-compiling for Android?")
set(CROSS OFF CACHE BOOL "Cross-compiling?")
set(CROSS_TARGET OFF CACHE STRING "Cross-compilation target")
set(SYSTEM_OPENSSL OFF CACHE STRING "Use system-provided openssl libraries (instead of prebuilts or building)")

# allow including our modules
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

if (SYSTEM_OPENSSL)
    # use system provided openssl
    find_package(OpenSSL REQUIRED)
    add_custom_target(openssl)
else()
    # build our own or use prebuilts
    
    # set up fake targets
    add_library(ssl_lib STATIC IMPORTED GLOBAL)
    add_library(crypto_lib STATIC IMPORTED GLOBAL)

    # set future paths
    set(OPENSSL_LIBSSL_PATH ${CMAKE_CURRENT_BINARY_DIR}/usr/local/lib/libssl.a)
    set(OPENSSL_LIBCRYPTO_PATH ${CMAKE_CURRENT_BINARY_DIR}/usr/local/lib/libcrypto.a)
    
    # set up openssl target
    if (BUILD_OPENSSL)
        include(BuildOpenSSL)
        
        # use locations of alredy built libraries
        set_target_properties(ssl_lib PROPERTIES IMPORTED_LOCATION ${OPENSSL_LIBSSL_PATH})
        set_target_properties(crypto_lib PROPERTIES IMPORTED_LOCATION ${OPENSSL_LIBCRYPTO_PATH})
    else()
        include(PrebuiltOpenSSL)
        
        # set library locations if prebuilt branch specified
        set_target_properties(ssl_lib PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/${PREBUILT_BRANCH}/usr/local/lib/libssl.a)
        set_target_properties(crypto_lib PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/${PREBUILT_BRANCH}/usr/local/lib/libcrypto.a)
    endif()
    
    # add fake targets to common target
    add_dependencies(ssl_lib openssl)
    add_dependencies(crypto_lib openssl)

    # mimic system ssl and crypto targets
    add_library(ssl INTERFACE)
    target_link_libraries(ssl INTERFACE ssl_lib)
    add_library(crypto INTERFACE)
    target_link_libraries(crypto INTERFACE crypto_lib)

    # prebuilt includes
    target_include_directories(ssl BEFORE INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/${PREBUILT_BRANCH}/usr/local/include)
    target_include_directories(crypto BEFORE INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/${PREBUILT_BRANCH}/usr/local/include)
    # local build includes
    target_include_directories(ssl BEFORE INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/usr/local/include)
    target_include_directories(crypto BEFORE INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/usr/local/include)
    
endif()
