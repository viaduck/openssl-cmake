# check out prebuilts for the current system

# includes
include(ExternalProject)
include(TargetArch)

# autodetect PREBUILT_BRANCH
target_architecture(ARCH)
if (WIN32)
    # prebuilts on windows use mingw-w64 for building
    set(ARCH_SYSTEM ${ARCH}-w64-mingw32)
elseif(UNIX AND NOT APPLE)
    set(ARCH_SYSTEM ${ARCH}-linux)
else()
    message(FATAL_ERROR "Prebuilts this system are not available (yet)!")
endif()
message(STATUS "Using ${ARCH_SYSTEM} prebuilts")
set(PREBUILT_BRANCH ${ARCH_SYSTEM} CACHE STRING "Branch in OpenSSL-Prebuilts to checkout from")

# add openssl target
ExternalProject_Add(openssl
        GIT_REPOSITORY https://gl.viaduck.org/viaduck/openssl-prebuilts.git
        GIT_TAG ${PREBUILT_BRANCH}

        UPDATE_COMMAND ""
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        BUILD_BYPRODUCTS ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/${PREBUILT_BRANCH}/usr/local/lib/libssl.a ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/${PREBUILT_BRANCH}/usr/local/lib/libcrypto.a
        INSTALL_COMMAND ""
        TEST_COMMAND ""
)
