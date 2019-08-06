#!/bin/bash
# MIT License
#
# Copyright (c) 2018-2019 The ViaDuck Project
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
# usage: <architecture> <directory>

# early exit when no secrets are set
if [[ $PREBUILT_AUTH = ":" ]]; then
    echo "No secrets to upload result."
    exit 0
fi

# rename dir as arch for tarring
mkdir -p $1
mv $2 $1/$2
tar czf $1.tar.gz $1

# capture the code while printing the page
{ code=$(curl -u $PREBUILT_AUTH -F "file=@$1.tar.gz" -F "dir=prebuilts/openssl/$OPENSSL_BUILD_VERSION" -F 'checksum=yes' -o /dev/stderr -w '%{http_code}' https://mirror.viaduck.org/scripts/upload.py); } 2>&1

# check for 200
if [ "$code" -ne 200 ]; then
    echo "cURL error"
    exit 1
fi

