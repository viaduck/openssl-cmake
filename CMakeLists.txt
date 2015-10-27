cmake_minimum_required(VERSION 3.3)

set(OPENSSL_BRANCH OpenSSL_1_0_2d)
set(NUM_JOBS 5)
set(BUILD_OPENSSL OFF CACHE BOOL "Automated OpenSSL building")

set(OS "UNIX")

if (WIN32)
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
elseif(NOT UNIX)
    message(FATAL_ERROR "Unsupported platform, sorry")
endif()

find_package(Git REQUIRED)
if (NOT GIT_FOUND)
    message(FATAL_ERROR "Please specify git path")
endif()

find_package(PythonInterp 3 REQUIRED)       # use Python 3 - Python2 is not compatible!

include(ExternalProject)
if (BUILD_OPENSSL)
    # save old git values for core.autocrlf and core.eol
    execute_process(COMMAND ${GIT_EXECUTABLE} config --global --get core.autocrlf OUTPUT_VARIABLE GIT_CORE_AUTOCRLF OUTPUT_STRIP_TRAILING_WHITESPACE)
    execute_process(COMMAND ${GIT_EXECUTABLE} config --global --get core.eol OUTPUT_VARIABLE GIT_CORE_EOL OUTPUT_STRIP_TRAILING_WHITESPACE)

    # python helper script for corrent building environment
    set(BUILD_ENV_TOOL ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/building_env.py ${OS} ${MSYS_BASH} ${MINGW_MAKE})

    # on windows we need to replace path to perl since CreateProcess(..) cannot handle unix paths
    if (WIN32)
        set(PERL_PATH_FIX_INSTALL sed -i -- 's/\\/usr\\/bin\\/perl/perl/g' Makefile)
    else()
        set(PERL_PATH_FIX_INSTALL true)
    endif()

    ExternalProject_Add(openssl
        GIT_REPOSITORY git://git.openssl.org/openssl.git
        GIT_TAG ${OPENSSL_BRANCH}

        UPDATE_COMMAND ""

        CONFIGURE_COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ./config --prefix=${CMAKE_CURRENT_BINARY_DIR} no-cast no-md2 no-md4 no-mdc2 no-rc4 no-rc5 no-engines
        no-idea no-mdc2 no-rc5 no-camellia no-ripemd no-ssl2 no-ssl3 no-heartbeats no-gost no-sha0 no-deprecated no-capieng no-decc-init no-comp no-dtls no-psk no-srp no-dso
        # no-dsa no-rc2 no-des break tests, therefore we need them

        BUILD_COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${CMAKE_MAKE_PROGRAM} depend
        COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${CMAKE_MAKE_PROGRAM} -j ${NUM_JOBS}

        TEST_BEFORE_INSTALL 1
        TEST_COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${CMAKE_MAKE_PROGRAM} test

        INSTALL_COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${PERL_PATH_FIX_INSTALL}
        COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${CMAKE_MAKE_PROGRAM} install

        LOG_CONFIGURE 1
        LOG_BUILD 1
        LOG_TEST 1
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
else()
    ExternalProject_Add(openssl
            GIT_REPOSITORY git://git.openssl.org/openssl.git
            GIT_TAG ${OPENSSL_BRANCH}

            UPDATE_COMMAND ""
            CONFIGURE_COMMAND ""
            BUILD_COMMAND ""
            INSTALL_COMMAND ""
            TEST_COMMAND ""
    )
endif()


add_library(ssl STATIC IMPORTED GLOBAL)
add_library(crypto STATIC IMPORTED GLOBAL)
set_target_properties(ssl PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/lib/libssl.a)
set_target_properties(crypto PROPERTIES IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/lib/libcrypto.a)
add_dependencies(ssl openssl)
add_dependencies(crypto openssl)
