#!/usr/bin/env bash
set -euo pipefail

git diff --check
nix build .#packages.x86_64-linux.tx-inspector-ui
nix develop --quiet -c sh -c 'cd docs/inspector && TX_AMARU_TREASURY_TX_ROOT=/code/amaru-treasury-tx TX_INSPECTOR_SITE_DIR=../../result playwright test tests/tx-identify.spec.mjs --grep "faithful CQuisitor parity" --reporter=list'
just test-playwright
just format-check
just hlint
