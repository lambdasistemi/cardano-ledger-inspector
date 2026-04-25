default:
    just --list

build-wasm:
    nix build .#packages.x86_64-linux.wasm-tx-inspector

build-ui:
    nix build .#packages.x86_64-linux.tx-inspector-ui

build-smokes:
    nix build .#packages.x86_64-linux.wasm-smoke
    nix build .#packages.x86_64-linux.wasm-ledger-smoke

format-check:
    nix develop --quiet -c find nix/wasm -type f -name '*.hs' -exec fourmolu -m check {} +

ui-check:
    nix develop --quiet -c sh -c 'cd docs/inspector && spago build'

deploy-preview:
    nix build .#packages.x86_64-linux.tx-inspector-ui
    rm -rf /tmp/cardano-ledger-wasi-surge
    mkdir -p /tmp/cardano-ledger-wasi-surge
    cp -rL result/* /tmp/cardano-ledger-wasi-surge/
    nix shell 'nixpkgs#nodejs_20' -c npx --yes surge /tmp/cardano-ledger-wasi-surge cardano-tx-inspector.surge.sh
