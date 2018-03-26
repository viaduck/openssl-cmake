#!/bin/bash
# usage: <architecture> <directory>

# early exit when no secrets are set
if [ -z $GIT_PASSWORD ]; then
    echo "No secrets to commit result."
    exit 0
fi

PREBUILTS_REPO="https://$GIT_USER:$GIT_PASSWORD@gl.viaduck.org/viaduck/openssl-prebuilts.git"

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
