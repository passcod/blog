#!/usr/bin/env bash

set -euo pipefail

httrack --sockets=32 --mirror --update --disable-security-limits -X -N100 https://blog.nut

rmdir f i t
mv index.html index.html
rg -lF index.html | xargs sed -i 's/index.html/index.html/g'
rg -lF /feed | xargs sed -i 's|/feed.xml"|/feed.xml"|g'

git add .
git commit -am "$(date)"
git push
