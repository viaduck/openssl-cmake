# MIT License
#
# Copyright (c) 2023 The ViaDuck Project
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

set(OPENSSL_PATCH_N 2)

# fix a failing test, see https://github.com/openssl/openssl/issues/20249
set(OPENSSL_PATCH_1_FILE ${CMAKE_CURRENT_SOURCE_DIR}/patches/0001-Fix-failing-cms-test-when-no-des-is-used.patch)
set(OPENSSL_PATCH_1_VERS "3.0.8..3.1.0")

# fix a failing test, see https://github.com/openssl/openssl/pull/22150
set(OPENSSL_PATCH_2_FILE ${CMAKE_CURRENT_SOURCE_DIR}/patches/0002-Fix-test_cms-if-DSA-is-not-supported.patch)
set(OPENSSL_PATCH_2_VERS "3.1.3..")

# process patches

set(OPENSSL_PATCH_COMMAND PATCH_COMMAND echo)
foreach(PATCH_INDEX RANGE 1 ${OPENSSL_PATCH_N})
    set(PATCH_FILE ${OPENSSL_PATCH_${PATCH_INDEX}_FILE})
    set(PATCH_VERS ${OPENSSL_PATCH_${PATCH_INDEX}_VERS})

    set(PATCH_APPLY OFF)
    string(FIND ${PATCH_VERS} ".." PATCH_HAS_RANGE)
    if (PATCH_HAS_RANGE)
        string(REGEX MATCH "^([a-zA-Z0-9\\.]*)\\.\\.([a-zA-Z0-9\\.]*)$" PATCH_RANGE_FOUND ${PATCH_VERS})

        if (("${CMAKE_MATCH_1}" STREQUAL "" OR ${OPENSSL_BUILD_VERSION} VERSION_GREATER_EQUAL "${CMAKE_MATCH_1}")
                AND ("${CMAKE_MATCH_2}" STREQUAL "" OR ${OPENSSL_BUILD_VERSION} VERSION_LESS "${CMAKE_MATCH_2}"))
            set(PATCH_APPLY ON)
        endif()
    else()
        if (${OPENSSL_BUILD_VERSION} VERSION_EQUAL ${PATCH_VERS})
            set(PATCH_APPLY ON)
        endif()
    endif()

    if (PATCH_APPLY)
        set(OPENSSL_PATCH_COMMAND ${OPENSSL_PATCH_COMMAND} COMMAND ${PATCH_PROGRAM} -p1 --forward -r - < ${PATCH_FILE} || echo)
    endif()
endforeach()
