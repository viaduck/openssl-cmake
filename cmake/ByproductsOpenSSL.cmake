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

# precompute future OpenSSL library paths from prefix dir
function(GetOpenSSLByproducts OPENSSL_PREFIX_PATH OPENSSL_BYPRODUCTS_VAR OPENSSL_INCLUDE_VAR)
    # include directory
    set(${OPENSSL_INCLUDE_VAR} "${OPENSSL_PREFIX_PATH}/usr/local/include" PARENT_SCOPE)
    
    if (WIN32)
        # windows pre/suffixes
        
        set(OPENSSL_SHARED_PREFIX "lib")
        set(OPENSSL_STATIC_PREFIX "lib")
        set(OPENSSL_SHARED_SUFFIX ".dll.a")
        set(OPENSSL_STATIC_SUFFIX ".a")
    else()
        # unix pre/suffixes
        
        set(OPENSSL_SHARED_PREFIX ${CMAKE_SHARED_LIBRARY_PREFIX})
        set(OPENSSL_STATIC_PREFIX ${CMAKE_STATIC_LIBRARY_PREFIX})
        set(OPENSSL_SHARED_SUFFIX ${CMAKE_SHARED_LIBRARY_SUFFIX})
        set(OPENSSL_STATIC_SUFFIX ${CMAKE_STATIC_LIBRARY_SUFFIX})
    endif()
    
    set(OPENSSL_BASE_NAMES crypto ssl)
    foreach(OPENSSL_BASE_NAME ${OPENSSL_BASE_NAMES})
        set(OPENSSL_STATIC_LIB ${OPENSSL_PREFIX_PATH}/usr/local/lib/${OPENSSL_STATIC_PREFIX}${OPENSSL_BASE_NAME}${OPENSSL_STATIC_SUFFIX})

        add_library(${OPENSSL_BASE_NAME}_static_lib STATIC IMPORTED GLOBAL)
        set_property(TARGET ${OPENSSL_BASE_NAME}_static_lib PROPERTY IMPORTED_LOCATION ${OPENSSL_STATIC_LIB})
        
        set(OPENSSL_SHARED_LIB ${OPENSSL_PREFIX_PATH}/usr/local/lib/${OPENSSL_SHARED_PREFIX}${OPENSSL_BASE_NAME}${OPENSSL_SHARED_SUFFIX})
        
        # windows .dll.a requires unknown import library type
        add_library(${OPENSSL_BASE_NAME}_shared_lib UNKNOWN IMPORTED GLOBAL)
        set_property(TARGET ${OPENSSL_BASE_NAME}_shared_lib PROPERTY IMPORTED_LOCATION ${OPENSSL_SHARED_LIB})
        
        list(APPEND ${OPENSSL_BYPRODUCTS_VAR} ${OPENSSL_STATIC_LIB} ${OPENSSL_SHARED_LIB})
    endforeach()
    
    # returns
    set(${OPENSSL_BYPRODUCTS_VAR} ${${OPENSSL_BYPRODUCTS_VAR}} PARENT_SCOPE)
endfunction()
