#!/usr/bin/env bash
set -euo pipefail

git diff --check
nix build .#packages.x86_64-linux.tx-inspector-ui
nix develop --quiet -c just ui-check
nix develop --quiet -c just test-playwright
