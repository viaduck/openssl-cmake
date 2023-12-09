# MIT License
#
# Copyright (c) 2015-2023 The ViaDuck Project
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

cmake_minimum_required(VERSION 3.2...3.27)
project(openssl-cmake)

set(BUILD_OPENSSL OFF CACHE BOOL "Automated OpenSSL building")
set(OPENSSL_BUILD_VERSION OFF CACHE STRING "OpenSSL version to build")
set(OPENSSL_USE_STATIC_LIBS ON CACHE STRING "OpenSSL static libs are preferred over shared libs")
set(OPENSSL_INSTALL_MAN OFF CACHE STRING "Install man pages?")
set(OPENSSL_MODULES "no-cast no-md2 no-md4 no-mdc2 no-rc4 no-rc5 no-engine no-idea no-mdc2 no-rc5 no-camellia no-ssl3 no-heartbeats no-gost no-deprecated no-capieng no-comp no-dtls no-psk no-srp no-dso no-dsa no-rc2 no-des" CACHE STRING "OpenSSL configure options")
set(OPENSSL_RPATH "" CACHE STRING "RPath to set during build")
set(CROSS_ANDROID OFF CACHE BOOL "Cross-compiling for Android?")
set(CROSS OFF CACHE BOOL "Cross-compiling?")
set(CROSS_TARGET OFF CACHE STRING "Cross-compilation target")
set(SYSTEM_OPENSSL OFF CACHE STRING "Use system-provided openssl libraries (instead of prebuilts or building)")

# allow including our modules
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

# mimic system ssl and crypto targets
add_library(ssl INTERFACE)
add_library(crypto INTERFACE)

if (SYSTEM_OPENSSL)
    # use system provided openssl
    find_package(OpenSSL REQUIRED)

    # link fake targets
    target_link_libraries(ssl INTERFACE OpenSSL::SSL)
    target_link_libraries(crypto INTERFACE OpenSSL::Crypto)
    add_custom_target(openssl)
else()
    # build our own or use prebuilts
    
    # set up prefix
    if (BUILD_OPENSSL)
        set(OPENSSL_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/openssl-build/)
    else()
        set(OPENSSL_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl)
    endif()
    
    # predict byproduct names and include directory
    include(ByproductsOpenSSL)
    GetOpenSSLByproducts(${OPENSSL_PREFIX} OPENSSL_BYPRODUCTS OPENSSL_INCLUDE_DIR)
    
    # set up openssl target
    if (BUILD_OPENSSL)
        include(BuildOpenSSL)
    else()
        include(PrebuiltOpenSSL)
    endif()
    
    # add imported targets to common target
    add_dependencies(ssl_static_lib openssl)
    add_dependencies(ssl_shared_lib openssl)
    add_dependencies(crypto_static_lib openssl)
    add_dependencies(crypto_shared_lib openssl)
    
    if (OPENSSL_USE_STATIC_LIBS)
        target_link_libraries(ssl INTERFACE ssl_static_lib)
        target_link_libraries(crypto INTERFACE crypto_static_lib)
    else()
        target_link_libraries(ssl INTERFACE ssl_shared_lib)
        target_link_libraries(crypto INTERFACE crypto_shared_lib)
    endif()

    # set include locations
    target_include_directories(ssl BEFORE INTERFACE $<BUILD_INTERFACE:${OPENSSL_INCLUDE_DIR}>)
    target_include_directories(crypto BEFORE INTERFACE $<BUILD_INTERFACE:${OPENSSL_INCLUDE_DIR}>)

    install(DIRECTORY ${OPENSSL_PREFIX}/usr/local/bin/ TYPE BIN)
    install(DIRECTORY ${OPENSSL_PREFIX}/usr/local/include/ TYPE INCLUDE)
    install(DIRECTORY ${OPENSSL_PREFIX}/usr/local/lib/ TYPE LIB)
    if (OPENSSL_INSTALL_MAN)
        install(DIRECTORY ${OPENSSL_PREFIX}/usr/local/share/ TYPE DATA)
    endif()
endif()
