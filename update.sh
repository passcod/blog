#!/usr/bin/env bash

set -euo pipefail

httrack --sockets=32 --mirror --update --disable-security-limits -X -N100 https://blog.nut

rmdir f i t || true
mv index-2.html index.html
mv feed feed.xml
rg -lFg !update.sh index-2.html | xargs sed -i 's/index-2.html/index.html/g'
rg -lFg !update.sh /feed | xargs sed -i 's|/feed"|/feed.xml"|g'
sed -i 's|"feed"|"/feed.xml"|g' index.html
echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0; url=/index.html">' > index-2.html

git add .
git commit -am "$(date)"
git push
