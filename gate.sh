#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

git diff --check
nix develop --quiet -c just format-check
nix develop --quiet -c just build-wasm
nix develop --quiet -c just build-smokes
nix develop --quiet -c just build-extism-host
nix develop --quiet -c just build-extism-spike
nix develop --quiet -c just test
