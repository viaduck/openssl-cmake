#!/bin/bash
sed -i "s/OPENSSL_BUILD_VERSION: \".*\"/OPENSSL_BUILD_VERSION: \"$1\"/g" .gitlab-ci.yml
sed -i "s/OPENSSL_BUILD_HASH: \".*\"/OPENSSL_BUILD_HASH: \"$2\"/g" .gitlab-ci.yml
sed -i "s/set(OPENSSL_PREBUILT_VERSION \".*\"/set(OPENSSL_PREBUILT_VERSION \"$1\"/g" cmake/PrebuiltOpenSSL.cmake
