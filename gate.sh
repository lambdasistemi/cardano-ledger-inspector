#!/usr/bin/env bash
set -euo pipefail

git diff --check
just ci
just build-pages-site
test -f _site/inspector/index.html
grep -F 'https://lambdasistemi.github.io/cardano-swiss-knife/' _site/inspector/index.html
test -f _site/openapi/cardano-ledger-functional.openapi.json
test ! -e _site/inspector/index.js
