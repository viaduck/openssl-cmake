# OpenSSL-CMake
CMake script supplying `OpenSSL` libraries conveniently, encapsulating the
`OpenSSL` build system on various platforms.

## Features
* Allows usage of system OpenSSL
* Allows trivial and complex building of OpenSSL
* Allows cross compilation, especially for Android
* Defaults to prebuilt binaries

## System OpenSSL
To use the system OpenSSL, simply set `SYSTEM_OPENSSL=ON`.

## Prebuilt OpenSSL
Default behaviour is the download of a prebuilt binary. This is only intended
as a convenience for debugging purposes and NOT for production use. 
Available prebuilt binaries can be viewed [here](https://builds.viaduck.org/prebuilts/openssl/).

## Build OpenSSL
In order to build `OpenSSL`, set `BUILD_OPENSSL=ON` along with the branch or 
tag name, for example `OPENSSL_BRANCH=OpenSSL_1_1_0g`. 

### General Cross Compile
Cross compilation is enabled using `CROSS=ON` and the target is specified using
`CROSS_TARGET=mingw` along with the optional `CROSS_PREFIX=mingw32-`. 

### Android Cross Compile
Android requires a special `CROSS_ANDROID=ON`. Using `OpenSSL-CMake` from 
Gradle's native build does not require additional settings. Otherwise, it is 
required to set the general NDK variables `ANDROID_NDK_ROOT`, `ANDROID_EABI`, 
`ANDROID_ARCH`, `ANDROID_API`, `ANDROID_MACHINE`.  
Cross compile was tested with NDK r18b, r19c and r20.

## Usage
1. Add `OpenSSL-CMake` as a submodule to your Git project using `git submodule 
add <URL> external/openssl-cmake`
2. Initialize the submodule using `git submodule update --init`
3. In your `CMakeLists.txt` include the directory using 
`add_subdirectory(external/openssl-cmake)`
4. Link against `ssl` and `crypto` targets, which will also include the headers

## Licensing
These scripts, unless otherwise stated, are subject to the MIT license.
