# MIT License
#
# Copyright (c) 2015-2018 The ViaDuck Project
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

# check out prebuilts for the current system

# includes
include(ExternalProject)
include(TargetArch)

# autodetect PREBUILT_BRANCH
if (NOT PREBUILT_BRANCH)
    target_architecture(ARCH)
    if (${ARCH} STREQUAL "unknown")
        message(FATAL_ERROR "Architecture detection failed. Please specify manually.")
    endif()
    
    if (WIN32)
        # prebuilts on windows use mingw-w64 for building
        set(ARCH_SYSTEM ${ARCH}-w64-mingw32)
    elseif(ANDROID)
        set(ARCH_SYSTEM ${ARCH}-android)
    elseif(UNIX AND NOT APPLE)
        set(ARCH_SYSTEM ${ARCH}-linux)
    else()
        message(FATAL_ERROR "Prebuilts for this system are not available (yet)!")
    endif()
    message(STATUS "Using ${ARCH_SYSTEM} prebuilts")
endif()
set(PREBUILT_BRANCH ${ARCH_SYSTEM} CACHE STRING "Branch in OpenSSL-Prebuilts to checkout from")

# auto version
if (NOT OPENSSL_PREBUILT_VERSION)
    set(OPENSSL_PREBUILT_VERSION "1.1.1r")
endif()

# add openssl target
ExternalProject_Add(openssl
        URL https://builds.viaduck.org/prebuilts/openssl/${OPENSSL_PREBUILT_VERSION}/${PREBUILT_BRANCH}.tar.gz

        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        BUILD_BYPRODUCTS ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/usr/local/lib/libssl.a ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/usr/local/lib/libcrypto.a
        INSTALL_COMMAND ""
        TEST_COMMAND ""
)
