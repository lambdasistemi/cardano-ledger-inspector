#!/usr/bin/env bash
set -euo pipefail

git diff --check
nix develop --quiet -c sh -c 'cd docs/inspector && spago build'
nix build .#packages.x86_64-linux.tx-inspector-ui
nix develop --quiet -c sh -c 'cd docs/inspector && ln -sfn $(dirname $(dirname $(readlink -f $(command -v playwright))))/lib/node_modules node_modules && TX_INSPECTOR_SITE_DIR=../../result playwright test --reporter=list'
