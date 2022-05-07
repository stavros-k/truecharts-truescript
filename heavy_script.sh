#!/bin/bash

dir=$(pwd)
git remote set-url origin https://github.com/truecharts/truescript.git 2>&1 >/dev/null
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git fetch 2>&1 >/dev/null
git update-index -q --refresh 2>&1 >/dev/null
CHANGED=""
CHANGED=$(git diff --name-only origin/$BRANCH)
if [ ! -z "$CHANGED" ];
then
    echo "script requires update"
    git reset --hard 2>&1 >/dev/null
    git checkout $BRANCH 2>&1 >/dev/null
    git pull 2>&1 >/dev/null
    echo "script updated"
    
else
    echo "script up-to-date"
fi
chmod +x $dir/heavy_script.sh
chmod +x $dir/truescript.sh
$dir/truescript.sh
