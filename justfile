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

check-identify:
    nix build .#checks.x86_64-linux.tx-identify-smoke -o result-identify-smoke

check-witness-plan:
    nix build .#checks.x86_64-linux.tx-witness-plan-smoke -o result-witness-plan-smoke

check-input-context:
    nix build .#checks.x86_64-linux.tx-input-context-smoke -o result-input-context-smoke

check-validate:
    nix build .#checks.x86_64-linux.tx-validate-smoke -o result-validate-smoke

build-extism-spike:
    nix build .#packages.x86_64-linux.wasm-extism-spike -o result-extism-spike

build-extism-host:
    nix build .#packages.x86_64-linux.extism-spike-host -o result-extism-host

check-extism-spike:
    nix build .#checks.x86_64-linux.tx-extism-spike-smoke -o result-extism-spike-smoke

test-playwright: build-ui
    nix develop --quiet -c sh -c 'cd docs/inspector && ln -sfn $(dirname $(dirname $(readlink -f $(command -v playwright))))/lib/node_modules node_modules && TX_INSPECTOR_SITE_DIR=../../result playwright test --reporter=list'

test:
    just check-identify
    just check-witness-plan
    just check-input-context
    just check-validate
    just test-playwright

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
