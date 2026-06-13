#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

git diff --check

nix build --quiet \
  .#packages.x86_64-linux.wasm-tx-inspector \
  .#packages.x86_64-linux.tx-inspector-ui \
  .#packages.x86_64-linux.ledger-functional-openapi \
  .#packages.x86_64-linux.wasm-extism-spike \
  .#packages.x86_64-linux.extism-spike-host \
  .#packages.x86_64-linux.tx-deep-diagnosis \
  .#checks.x86_64-linux.ledger-functional-openapi-check \
  .#checks.x86_64-linux.ledger-functional-swagger-check \
  .#checks.x86_64-linux.tx-identify-smoke \
  .#checks.x86_64-linux.tx-rdf-smoke \
  .#checks.x86_64-linux.tx-witness-plan-smoke \
  .#checks.x86_64-linux.tx-witness-attach-smoke \
  .#checks.x86_64-linux.tx-intent-smoke \
  .#checks.x86_64-linux.tx-validate-smoke \
  .#checks.x86_64-linux.tx-evaluate-scripts-smoke \
  .#checks.x86_64-linux.tx-input-context-smoke \
  .#checks.x86_64-linux.tx-extism-spike-smoke \
  -o result-gate

nix develop --quiet -c just ui-check
nix develop --quiet -c just test-playwright
