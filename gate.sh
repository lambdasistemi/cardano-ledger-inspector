#!/usr/bin/env bash
set -euo pipefail

git diff --check
just ui-check
just build-ui
nix develop --quiet -c sh -c 'cd docs/inspector && ln -sfn $(dirname $(dirname $(readlink -f $(command -v playwright))))/lib/node_modules node_modules && TX_INSPECTOR_SITE_DIR=../../result playwright test tests/tx-identify.spec.mjs --grep "generic hex-suffix credential resolution" --reporter=list'
