#!/usr/bin/env bash
set -euo pipefail

just format-check
just hlint
nix build .#packages.x86_64-linux.tx-inspector-ui
just test-playwright
