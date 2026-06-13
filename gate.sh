#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

nix develop --quiet -c just check-rdf
nix develop --quiet -c just ui-check
nix develop --quiet -c just test-playwright
