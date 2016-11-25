#!/bin/bash
# usage: <architecture> <directory>

git clone $PREBUILTS_REPO
cd openssl-prebuilts
git checkout master
git branch $1
git checkout $1
git pull -u origin $1

rm -R $1/* || mkdir $1
cp -R ../$2/bin $1
cp -R ../$2/lib $1
cp -R ../$2/include $1
cp -R ../$2/ssl $1

git add $1
git config --global user.email "slave@viaduck.org"
git config --global user.name "slave"
git commit -m "Automatically built by slave ($OPENSSL_BRANCH)" > /dev/null
git push --set-upstream origin $1
