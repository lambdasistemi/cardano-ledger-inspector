default:
    just --list

build-wasm:
    nix build .#packages.x86_64-linux.wasm-tx-inspector

build-ui:
    nix build .#packages.x86_64-linux.tx-inspector-ui

build-openapi:
    nix build .#packages.x86_64-linux.ledger-functional-openapi -o result-openapi

check-openapi:
    nix build .#checks.x86_64-linux.ledger-functional-openapi-check

check-swagger:
    nix build .#checks.x86_64-linux.ledger-functional-swagger-check

build-smokes:
    nix build .#packages.x86_64-linux.wasm-smoke
    nix build .#packages.x86_64-linux.wasm-ledger-smoke

format-check:
    nix develop --quiet -c find nix/wasm -type f -name '*.hs' -exec fourmolu -m check {} +

ui-check:
    nix develop --quiet -c sh -c 'cd docs/inspector && spago build'

build-pages-site:
    nix build .#packages.x86_64-linux.tx-inspector-ui -o result-inspector
    nix build .#packages.x86_64-linux.ledger-functional-openapi -o result-openapi
    rm -rf _site
    nix develop --quiet -c mkdocs build --strict --site-dir _site
    mkdir -p _site/inspector
    cp -rL result-inspector/* _site/inspector/
    mkdir -p _site/openapi
    cp -rL result-openapi/* _site/openapi/

deploy-surge-preview:
    nix build .#packages.x86_64-linux.tx-inspector-ui
    rm -rf /tmp/cardano-ledger-wasi-surge
    mkdir -p /tmp/cardano-ledger-wasi-surge
    cp -rL result/* /tmp/cardano-ledger-wasi-surge/
    nix shell 'nixpkgs#nodejs_20' -c npx --yes surge /tmp/cardano-ledger-wasi-surge cardano-tx-inspector.surge.sh
