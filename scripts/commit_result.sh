#!/bin/bash

git clone git@g82.primeghost.de:secchatgroup/openssl-prebuilts.git || exit 1

cd openssl-prebuilts
git branch $1
git checkout $1

rm -R $1/* || mkdir $1
cp -R ../bin $1
cp -R ../lib $1
cp -R ../include $1
cp -R ../ssl $1

git add $1
git commit -m "Automatically built by slave ($2)" > /dev/null
git push --set-upstream origin $1
