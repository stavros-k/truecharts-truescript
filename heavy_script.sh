#!/bin/bash

dir=$(pwd)
git remote set-url origin https://github.com/truecharts/truescript.git
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git fetch
git update-index -q --refresh
CHANGED=$(git diff --name-only origin/$BRANCH)
if [ ! -z "$CHANGED" ];
then
    echo "script requires update"
    git reset --hard
    git checkout $BRANCH
    git pull
    echo "script updated"
    
else
    echo "script up-to-date"
fi
chmod +x $dir/truescript.sh
$dir/truescript.sh
