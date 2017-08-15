cmake_minimum_required(VERSION 3.2)

set(BUILD_OPENSSL OFF CACHE BOOL "Automated OpenSSL building")
set(OPENSSL_BRANCH OFF CACHE STRING "OpenSSL branch (or tag) to build")
set(OPENSSL_INSTALL_MAN OFF CACHE STRING "Install man pages?")
set(CROSS_ANDROID OFF CACHE BOOL "Cross-compiling for Android?")
set(CROSS OFF CACHE BOOL "Cross-compiling?")
set(CROSS_TARGET OFF CACHE STRING "Cross-compilation target")
set(SYSTEM_OPENSSL OFF CACHE STRING "Use system-provided openssl libraries (instead of prebuilts or building)")

set(NUM_JOBS 5)

set(OS "UNIX")
find_package(Git REQUIRED)
if (NOT GIT_FOUND)
    message(FATAL_ERROR "Please specify git path")
endif()

find_package(PythonInterp 3 REQUIRED)       # use Python 3 - Python2 is not compatible!

if (SYSTEM_OPENSSL)
    find_package(OpenSSL REQUIRED)
    add_custom_target(openssl)
else()
    include(ExternalProject)
    add_library(ssl STATIC IMPORTED GLOBAL)
    add_library(crypto STATIC IMPORTED GLOBAL)
    
    if ((EXISTS ${CMAKE_CURRENT_BINARY_DIR}/lib/libssl.a) AND (EXISTS ${CMAKE_CURRENT_BINARY_DIR}/lib/libcrypto.a))
        message(WARNING "Not building OpenSSL again. Remove ${CMAKE_CURRENT_BINARY_DIR}/lib/libssl.a and ${CMAKE_CURRENT_BINARY_DIR}/lib/libcrypto.a for rebuild")
    endif()

    if(BUILD_OPENSSL AND (NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/lib/libssl.a OR NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/lib/libcrypto.a))
        if (NOT OPENSSL_BRANCH)
            message(FATAL_ERROR "You must specify OPENSSL_BRANCH!")
        endif()

        if (WIN32 AND NOT CROSS)
            # yep, windows need a special treatment, but neither cygwin nor msys, since they provide an UNIX-like environment
            if (MINGW)
                message(WARNING "Building on windows might fail")
                set(OS "WIN32")
                find_program(MSYS_BASH "bash.exe" PATHS "C:/Msys/" "C:/MinGW/msys/" PATH_SUFFIXES "/1.0/bin/" "/bin/"
                        DOC "Path to MSYS installation")
                if (NOT MSYS_BASH)
                    message(FATAL_ERROR "Specify MSYS installation path")
                endif(NOT MSYS_BASH)
                message(WARNING "I assume your make program is a sibling of your compiler (resides in same directory)")
                set(MINGW_MAKE ${CMAKE_MAKE_PROGRAM})
            elseif(NOT (CYGWIN OR MSYS))
                message(FATAL_ERROR "Unsupported compiler infrastructure")
            endif(MINGW)
            
            set(MAKE_PROGRAM ${CMAKE_MAKE_PROGRAM})
        elseif(NOT UNIX)
            message(FATAL_ERROR "Unsupported platform, sorry")
        else()
            # for OpenSSL we can only use GNU make no such exotic things as Ninja (MSYS always uses GNU make)
            find_program(MAKE_PROGRAM make)
        endif()

        # save old git values for core.autocrlf and core.eol
        execute_process(COMMAND ${GIT_EXECUTABLE} config --global --get core.autocrlf OUTPUT_VARIABLE GIT_CORE_AUTOCRLF OUTPUT_STRIP_TRAILING_WHITESPACE)
        execute_process(COMMAND ${GIT_EXECUTABLE} config --global --get core.eol OUTPUT_VARIABLE GIT_CORE_EOL OUTPUT_STRIP_TRAILING_WHITESPACE)


        # on windows we need to replace path to perl since CreateProcess(..) cannot handle unix paths
        if (WIN32 AND NOT CROSS)
            set(PERL_PATH_FIX_INSTALL sed -i -- 's/\\/usr\\/bin\\/perl/perl/g' Makefile)
        else()
            set(PERL_PATH_FIX_INSTALL true)
        endif()

        # CROSS and CROSS_ANDROID cannot both be set (because of internal reasons)
        if (CROSS AND CROSS_ANDROID)
            # if user set CROSS_ANDROID and CROSS we assume we wants CROSS_ANDROID, so set CROSS to OFF
            set(CROSS OFF)
        endif()

        if (CROSS_ANDROID)
            set(OS "LINUX_CROSS_ANDROID")
        endif()

        # python helper script for corrent building environment
        set(BUILD_ENV_TOOL ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/building_env.py ${OS} ${MSYS_BASH} ${MINGW_MAKE})

        # no-dsa no-rc2 no-des break tests, therefore we need them
        set(CONFIGURE_OPENSSL_MODULES no-cast no-md2 no-md4 no-mdc2 no-rc4 no-rc5 no-engine no-idea no-mdc2 no-rc5 no-camellia no-ssl3 no-heartbeats no-gost no-deprecated no-capieng no-comp no-dtls no-psk no-srp no-dso)

        # additional configure script parameters
        set(CONFIGURE_OPENSSL_PARAMS --api=1.1.0)

        # set install command depending of choice on man page generation
        if (OPENSSL_INSTALL_MAN)
            set(INSTALL_OPENSSL "install")
        else()
            set(INSTALL_OPENSSL "install_sw")
        endif()

        # set OpenSSL API compatibility version
        add_definitions(-DOPENSSL_API_COMPAT=0x10100000L)
        
        # We need to tell Clang to ignore unused arguments to avoid compilation errors, since OpenSSL passes an -mandroid which is only known by GCC (but not Clang)
        # We cannot silence this error ("-Wno-error=unused-command-line-argument-hard-error-in-future" no longer works), therefore we need a patch... uargh... the patch is applied in ExternalProject_Add
        find_program(PATCH_PROGRAM patch)
        if (NOT PATCH_PROGRAM)
            message(FATAL_ERROR "Cannot find patch utility. This is only required for Android cross-compilation but due to script complexity "
                                "the requirement is always enforced")
        endif()
        
        # cross-compiling
        if (CROSS)
            set(COMMAND_CONFIGURE ./Configure ${CONFIGURE_OPENSSL_PARAMS} --prefix=${CMAKE_CURRENT_BINARY_DIR} --cross-compile-prefix=${CROSS_PREFIX} ${CROSS_TARGET} ${CONFIGURE_OPENSSL_MODULES})
            set(COMMAND_TEST "true")
        elseif(CROSS_ANDROID)
            
        
            # Android specific configuration options
            set(CONFIGURE_OPENSSL_MODULES ${CONFIGURE_OPENSSL_MODULES} no-hw)
            
            set(CFLAGS ${CMAKE_C_FLAGS})
            set(CXXFLAGS ${CMAKE_CXX_FLAGS})
            
            # silence warnings about unused arguments (Clang specific)
            set(CFLAGS ${CFLAGS} "-Qunused-arguments")
            set(CXXFLAGS ${CXXFLAGS} "-Qunused-arguments")
        
            # required environment configuration is already set (by e.g. ndk) so no need to fiddle around with all the OpenSSL options ...
            if (ANDROID)
                if (ARMEABI_V7A)
                    set(OPENSSL_PLATFORM "armeabi")
                    set(CONFIGURE_OPENSSL_PARAMS ${CONFIGURE_OPENSSL_PARAMS} "-march=armv7-a")
                else()
                    if (ANDROID_NDK_ABI_NAME MATCHES "arm64-v8a")
                        set(OPENSSL_PLATFORM "aarch64")
                        set(CFLAGS "${CFLAGS} -fno-integrated-as")
                        set(CXXFLAGS "${CXXFLAGS} -fno-integrated-as")
                    else()
                        set(OPENSSL_PLATFORM ${ANDROID_NDK_ABI_NAME})
                    endif()
                    
                    if(ANDROID_NDK_ABI_NAME MATCHES "mips64")
                        set(CFLAGS "${CFLAGS} -fno-integrated-as")
                        set(CXXFLAGS "${CXXFLAGS} -fno-integrated-as")
                    endif()
                endif()
                
                set(ANDROID_STRING "android")
                if (ANDROID_ARCH_NAME MATCHES "64")
                    set(ANDROID_STRING "${ANDROID_STRING}64")
                endif()
                
                # ... but we have to convert all the CMake options to environment variables!
                set(CROSS_SYSROOT ${CMAKE_SYSROOT})
                set(AS ${CMAKE_ASM_COMPILER})
                set(AR ${CMAKE_AR})
                set(LD ${CMAKE_LINKER} ${CMAKE_MODULE_LINKER_FLAGS})
                
                # have to surround variables with double quotes, otherwise they will be merged together without any separator
                set(CC "${CMAKE_C_COMPILER} ${CMAKE_C_COMPILE_OPTIONS_EXTERNAL_TOOLCHAIN} ${CMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN} ${CFLAGS} -target ${CMAKE_C_COMPILER_TARGET}")
                
                set(COMMAND_CONFIGURE ./Configure ${ANDROID_STRING}-${OPENSSL_PLATFORM} ${CONFIGURE_OPENSSL_PARAMS} --prefix=${CMAKE_CURRENT_BINARY_DIR} ${CONFIGURE_OPENSSL_MODULES})
            else()
                # The following code is an adapted version of OpenSSL's Setenv-android.sh
                # Original contents are licensed under the terms of the OpenSSL license
                # http://www.openssl.org/source/license.html
                # ####################################

                # cache variables
                set(ANDROID_NDK "" CACHE STRING "Android NDK directory (for auto discovery)")
                set(ANDROID_NDK_ROOT "" CACHE STRING "Android NDK root directory")
                set(ANDROID_EABI "" CACHE STRING "Android EABI (see ANDROID_NDK_ROOT/toolchains for a list of possible values)")
                set(ANDROID_ARCH "" CACHE STRING "Android architecture (e.g. arch-arm, arch-x86, ...)")
                set(ANDROID_API "" CACHE STRING "Android API to build against (e.g. android-19)")
                set(ANDROID_MACHINE "" CACHE STRING "Android machine (e.g. armv7, i686)")


                if (NOT ANDROID_NDK AND NOT ANDROID_NDK_ROOT)
                    message(FATAL_ERROR "Please specify ANDROID_NDK (for auto discovery) or ANDROID_NDK_ROOT (manual path)")
                endif()
                if (NOT ANDROID_EABI)
                    message(FATAL_ERROR "Please specify ANDROID_EABI")
                endif()
                if (NOT ANDROID_ARCH)
                    message(FATAL_ERROR "Please specify ANDROID_ARCH")
                endif()
                if (NOT ANDROID_API)
                    message(FATAL_ERROR "Please specify ANDROID_API")
                endif()
                if (NOT ANDROID_MACHINE)
                    message(FATAL_ERROR "Please specify ANDROID_MACHINE")
                endif()

                # try detecting ANDROID_NDK_ROOT
                if (NOT ANDROID_NDK_ROOT)
                    if (EXISTS "/usr/local/${ANDROID_NDK}")
                        set(ANDROID_NDK_ROOT "/usr/local/${ANDROID_NDK}")
                    endif()
                    if (EXISTS "/opt/${ANDROID_NDK}")
                        set(ANDROID_NDK_ROOT "/opt/${ANDROID_NDK}")
                    endif()
                    if (EXISTS "ENV${HOME}/${ANDROID_NDK}")
                        set(ANDROID_NDK_ROOT "ENV${HOME}/${ANDROID_NDK}")
                    endif()
                    if (EXISTS "ENV${PWD}/${ANDROID_NDK}")
                        set(ANDROID_NDK_ROOT "ENV${PWD}/${ANDROID_NDK}")
                    endif()
                endif()

                if (NOT ANDROID_NDK_ROOT)
                    message(FATAL_ERROR "Android NDK root directory not found!")
                endif()

                if (NOT EXISTS "${ANDROID_NDK_ROOT}/toolchains")
                    message(FATAL_ERROR "${ANDROID_NDK_ROOT}/toolchains not found!")
                endif()

                if (NOT EXISTS "${ANDROID_NDK_ROOT}/toolchains/${ANDROID_EABI}")
                    message(FATAL_ERROR "${ANDROID_NDK_ROOT}/toolchains/${ANDROID_EABI} not found!")
                endif()

                ###
                set(ANDROID_TOOLCHAIN "${ANDROID_NDK_ROOT}/toolchains/${ANDROID_EABI}/prebuilt/linux-x86_64/bin")
                set(PATH ${ANDROID_TOOLCHAIN})
                set(ANDROID_SYSROOT ${ANDROID_NDK_ROOT}/platforms/${ANDROID_API}/${ANDROID_ARCH})
                set(ANDROID_NDK_SYSROOT ${ANDROID_SYSROOT})
                set(NDK_SYSROOT ${ANDROID_SYSROOT})
                set(SYSROOT ${ANDROID_SYSROOT})
                if (ANDROID_ARCH MATCHES "arch-arm")
                    set(IF_EABI "eabi")
                    set(ARCH "arm")
                else()
                    set(ARCH "x86")
                endif()
                set(MACHINE ${ANDROID_MACHINE})
                set(SYSTEM android)
                # for OpenSSL
                set(CROSS_COMPILE "${ARCH}-linux-android${IF_EABI}-")
                set(ANDROID_DEV ${ANDROID_SYSROOT}/usr)
                set(HOSTCC gcc) #${CMAKE_C_COMPILER})
                set(RELEASE "2.6.37")
                
                set(COMMAND_CONFIGURE ./config ${CONFIGURE_OPENSSL_PARAMS} --prefix=${CMAKE_CURRENT_BINARY_DIR} ${CONFIGURE_OPENSSL_MODULES})
            endif()
            set(COMMAND_TEST "true")
        else()                   # detect host system automatically
            set(COMMAND_CONFIGURE ./config ${CONFIGURE_OPENSSL_PARAMS} --prefix=${CMAKE_CURRENT_BINARY_DIR} ${CONFIGURE_OPENSSL_MODULES})
            set(COMMAND_TEST ${BUILD_ENV_TOOL} <SOURCE_DIR> ${MAKE_PROGRAM} test)
        endif()

        ExternalProject_Add(openssl
            GIT_REPOSITORY git://git.openssl.org/openssl.git
            GIT_TAG ${OPENSSL_BRANCH}

            UPDATE_COMMAND ""

            CONFIGURE_COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${COMMAND_CONFIGURE}
            PATCH_COMMAND ${PATCH_PROGRAM} -p1 --forward -r - < ${CMAKE_CURRENT_SOURCE_DIR}/openssl-android-clang.patch || true
            COMMAND ${PATCH_PROGRAM} -p1 --forward -r - < ${CMAKE_CURRENT_SOURCE_DIR}/0001-Configurations-10-main.conf-add-android64-x86_64-tar.patch || true
            COMMAND ${PATCH_PROGRAM} -p1 --forward -r - < ${CMAKE_CURRENT_SOURCE_DIR}/0002-MIPS-assembly-pack-adapt-it-for-MIPS-32-64-R6.patch || true
            COMMAND ${PATCH_PROGRAM} -p1 --forward -r - < ${CMAKE_CURRENT_SOURCE_DIR}/0003-Configurations-10-main.conf-add-android64-mips64-tar.patch || true
            COMMAND ${PATCH_PROGRAM} -p1 --forward -r - < ${CMAKE_CURRENT_SOURCE_DIR}/0004-modes-asm-ghash-armv4.pl-improve-interoperability-wi.patch || true
            COMMAND ${PATCH_PROGRAM} -p1 --forward -r - < ${CMAKE_CURRENT_SOURCE_DIR}/openssl-fix-armv4.patch || true

            BUILD_COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${MAKE_PROGRAM} -j ${NUM_JOBS}
            BUILD_BYPRODUCTS ${CMAKE_CURRENT_BINARY_DIR}/lib/libssl.a ${CMAKE_CURRENT_BINARY_DIR}/lib/libcrypto.a

            TEST_BEFORE_INSTALL 1
            TEST_COMMAND ${COMMAND_TEST}

            INSTALL_COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${PERL_PATH_FIX_INSTALL}
            COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${MAKE_PROGRAM} ${INSTALL_OPENSSL}
            COMMAND ${CMAKE_COMMAND} -G ${CMAKE_GENERATOR} ${CMAKE_BINARY_DIR}                    # force CMake-reload

            LOG_INSTALL 1
        )

        # set git config values to openssl requirements (no impact on linux though)
        ExternalProject_Add_Step(openssl setGitConfig
            COMMAND ${GIT_EXECUTABLE} config --global core.autocrlf false
            COMMAND ${GIT_EXECUTABLE} config --global core.eol lf
            DEPENDEES
            DEPENDERS download
            ALWAYS ON
        )

        # set, don't abort if it fails (due to variables being empty). To realize this we must only call git if the configs
        # are set globally, otherwise do a no-op command ("echo 1", since "true" is not available everywhere)
        if (GIT_CORE_AUTOCRLF)
            set (GIT_CORE_AUTOCRLF_CMD ${GIT_EXECUTABLE} config --global core.autocrlf ${GIT_CORE_AUTOCRLF})
        else()
            set (GIT_CORE_AUTOCRLF_CMD echo)
        endif()
        if (GIT_CORE_EOL)
            set (GIT_CORE_EOL_CMD ${GIT_EXECUTABLE} config --global core.eol ${GIT_CORE_EOL})
        else()
            set (GIT_CORE_EOL_CMD echo)
        endif()
        ##

        # set git config values to previous values
        ExternalProject_Add_Step(openssl restoreGitConfig
        # unset first (is required, since old value could be omitted, which wouldn't take any effect in "set"
            COMMAND ${GIT_EXECUTABLE} config --global --unset core.autocrlf
            COMMAND ${GIT_EXECUTABLE} config --global --unset core.eol

            COMMAND ${GIT_CORE_AUTOCRLF_CMD}
            COMMAND ${GIT_CORE_EOL_CMD}

            DEPENDEES download
            DEPENDERS configure
            ALWAYS ON
        )

        # write environment to file, is picked up by python script
        get_cmake_property(_variableNames VARIABLES)
        foreach (_variableName ${_variableNames})
            if (NOT _variableName MATCHES "lines")
                set(OUT_FILE "${OUT_FILE}${_variableName}=\"${${_variableName}}\"\n")
            endif()
        endforeach()
        file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/buildenv.txt ${OUT_FILE})

        set_target_properties(ssl PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/lib/libssl.a)
        set_target_properties(crypto PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/lib/libcrypto.a)
    else()             # using external prebuilts
        # detect system
        include(TargetArch.cmake)
        target_architecture(ARCH)
        if (WIN32)
            set(ARCH_SYSTEM ${ARCH}-w64-mingw32)            # prebuilts use mingw-w64 for building
        elseif(UNIX AND NOT APPLE)
            set(ARCH_SYSTEM ${ARCH}-linux)
        elseif(APPLE)
            message(FATAL_ERROR "Prebuilts for Apple systems are not available (yet)!")
        endif()
        message(STATUS "Using ${ARCH_SYSTEM} prebuilts")
        set(PREBUILT_BRANCH ${ARCH_SYSTEM} CACHE STRING "Branch in OpenSSL-Prebuilts to checkout from")

        ExternalProject_Add(openssl
		GIT_REPOSITORY https://gl.viaduck.org/viaduck/openssl-prebuilts.git
                GIT_TAG ${PREBUILT_BRANCH}

                UPDATE_COMMAND ""
                CONFIGURE_COMMAND ""
                BUILD_COMMAND ""
                BUILD_BYPRODUCTS ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/${PREBUILT_BRANCH}/lib/libssl.a ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/${PREBUILT_BRANCH}/lib/libcrypto.a
                INSTALL_COMMAND ""
                TEST_COMMAND ""
        )

        if (PREBUILT_BRANCH)
            # set library locations if prebuilt branch specified
            set_target_properties(ssl PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/${PREBUILT_BRANCH}/lib/libssl.a)
            set_target_properties(crypto PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/openssl-prefix/src/openssl/${PREBUILT_BRANCH}/lib/libcrypto.a)
        else()
            # try to use locations of alredy built libraries (using BUILD_OPENSSL)
            if ((NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/lib/libssl.a) OR (NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/lib/libcrypto.a))
                message(FATAL_ERROR "OpenSSL libraries not found. Either build them (with BUILD_OPENSSL) or use prebuilts (set PREBUILT_BRANCH)
                        or use the system-provided libraries (SYSTEM_OPENSSL).")
            endif()
            set_target_properties(ssl PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/lib/libssl.a)
            set_target_properties(crypto PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/lib/libcrypto.a)
        endif()
    endif()

    add_dependencies(ssl openssl)
    add_dependencies(crypto openssl)
endif()
