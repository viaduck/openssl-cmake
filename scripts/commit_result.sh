#!/bin/bash
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
# usage: <architecture> <directory>

# early exit when no secrets are set
if [[ $PREBUILTS_REPO = *"://:@"* ]]; then
    echo "No secrets to commit result."
    exit 0
fi

git clone $PREBUILTS_REPO
cd openssl-prebuilts
git checkout master
git branch $1
git checkout $1
git branch --set-upstream-to=origin/$1
git pull

rm -R $1/* || mkdir $1
cp -R ../$2/usr $1

git add $1
git config --global user.email "slave@viaduck.org"
git config --global user.name "slave"
git commit -m "Automatically built by slave ($OPENSSL_BRANCH)" > /dev/null
git push --set-upstream origin $1
