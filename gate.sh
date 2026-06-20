#!/usr/bin/env bash
set -euo pipefail

git diff --check
nix build .#packages.x86_64-linux.tx-inspector-ui
nix develop --quiet -c just format-check
nix develop --quiet -c just hlint
nix develop --quiet -c just test-playwright
