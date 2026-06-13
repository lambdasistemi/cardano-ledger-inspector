#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

git diff --check
nix develop --quiet -c just format-check
nix develop --quiet -c just hlint
nix develop --quiet -c just ui-check
just test-playwright
