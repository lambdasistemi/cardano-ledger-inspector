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

check-rdf:
    nix build .#checks.x86_64-linux.tx-rdf-smoke -o result-rdf-smoke

check-witness-plan:
    nix build .#checks.x86_64-linux.tx-witness-plan-smoke -o result-witness-plan-smoke

check-witness-attach:
    nix build .#checks.x86_64-linux.tx-witness-attach-smoke -o result-witness-attach-smoke

check-intent:
    nix build .#checks.x86_64-linux.tx-intent-smoke -o result-intent-smoke

check-input-context:
    nix build .#checks.x86_64-linux.tx-input-context-smoke -o result-input-context-smoke

check-validate:
    nix build .#checks.x86_64-linux.tx-validate-smoke -o result-validate-smoke

check-evaluate-scripts:
    nix build .#checks.x86_64-linux.tx-evaluate-scripts-smoke -o result-evaluate-scripts-smoke

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
    just check-rdf
    just check-witness-plan
    just check-witness-attach
    just check-intent
    just check-input-context
    just check-validate
    just check-evaluate-scripts
    just hlint
    just test-playwright

build-smokes:
    nix build .#packages.x86_64-linux.wasm-smoke
    nix build .#packages.x86_64-linux.wasm-ledger-smoke

format:
    nix develop --quiet -c find libs apps nix/wasm -type f -name '*.hs' -exec fourmolu -m inplace {} +

format-check:
    nix develop --quiet -c find libs apps nix/wasm -type f -name '*.hs' -exec fourmolu -m check {} +

hlint:
    nix develop --quiet -c hlint libs apps nix/wasm

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

deploy-preview pr_number="130":
    nix --quiet build .#packages.x86_64-linux.tx-inspector-ui -o result-inspector
    nix --quiet build .#packages.x86_64-linux.ledger-functional-openapi -o result-openapi
    rm -rf preview-site
    nix develop --quiet -c mkdocs build --strict --site-dir preview-site
    mkdir -p preview-site/inspector
    cp -RL result-inspector/. preview-site/inspector/
    test "$(find preview-site/inspector -maxdepth 1 -name 'inspector.*.wasm' | wc -l)" -eq 1
    test "$(find preview-site/inspector -maxdepth 1 -name 'rdf_shapes_wasm_bg.*.wasm' | wc -l)" -eq 1
    for wasm in preview-site/inspector/inspector.*.wasm preview-site/inspector/rdf_shapes_wasm_bg.*.wasm; do test -f "$wasm"; test -f "$wasm.gz"; test -f "$wasm.br"; done
    test -f preview-site/inspector/index.js.gz
    test -f preview-site/inspector/index.js.br
    mkdir -p preview-site/openapi
    cp -L result-openapi/* preview-site/openapi/
    chmod -R u+w preview-site
    sudo env INPUT_PATH=preview-site INPUT_OWNER=lambdasistemi INPUT_REPOSITORY=cardano-ledger-inspector INPUT_PR_NUMBER='{{pr_number}}' bash /code/dev-assets/static-preview/scripts/preview.sh

deploy-surge-preview pr_number="130":
    just deploy-preview '{{pr_number}}'
