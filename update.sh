#!/usr/bin/env bash

set -euo pipefail

httrack --sockets=32 --mirror --update --disable-security-limits -X -N100 https://blog.nut
rmdir f i t
git add .
git commit -am "$(date)"
git push
