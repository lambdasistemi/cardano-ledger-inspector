#!/usr/bin/env bash
set -euo pipefail

mode="${1:-quick}"

nix develop --quiet -c sh -c 'cd docs/inspector && spago build'
nix build .#packages.x86_64-linux.tx-inspector-ui

if [ -d packages/purescript-rdf-editor/src ]; then
  if rg -n 'FFI\.BookStore|FFI\.OverlayBook|Routing|module Main|cardano-ledger-inspector|BookStore|OverlayBook|BookStore\.Book' packages/purescript-rdf-editor; then
    echo "purescript-rdf-editor contains inspector-coupled imports or vocabulary" >&2
    exit 1
  fi
fi

if [ "$mode" = "final" ]; then
  test -f docs/inspector/SECURITY.md
  rg -i 'CodeMirror|signing|key|pin|supply-chain|WASM' docs/inspector/SECURITY.md >/dev/null
  test -d packages/purescript-rdf-editor/src
  jq -e '
    .dependencies
    | to_entries
    | map(select(.key | test("^(@codemirror/|codemirror$)")))
    | length > 0
  ' docs/inspector/package.json >/dev/null
  jq -e '
    .dependencies
    | to_entries
    | map(select((.key | test("^(@codemirror/|codemirror$)")) and (.value | test("^[0-9]"))))
    | length > 0
  ' docs/inspector/package.json >/dev/null
  just test-playwright
fi
