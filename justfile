default:
    just --list

build-wasm:
    nix build .#packages.x86_64-linux.wasm-tx-inspector

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

check-review-types:
    nix build .#checks.x86_64-linux.tx-review-types-test -o result-review-types-check

check-review:
    nix build .#checks.x86_64-linux.tx-review-smoke -o result-review-smoke

build-extism-spike:
    nix build .#packages.x86_64-linux.wasm-extism-spike -o result-extism-spike

build-extism-host:
    nix build .#packages.x86_64-linux.extism-spike-host -o result-extism-host

check-extism-spike:
    nix build .#checks.x86_64-linux.tx-extism-spike-smoke -o result-extism-spike-smoke

check-ci-drift:
    scripts/check-ci-entry-point.sh

ci:
    just check-ci-drift
    nix build --quiet \
      .#packages.x86_64-linux.wasm-tx-inspector \
      .#packages.x86_64-linux.protocol-registry \
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
      .#checks.x86_64-linux.tx-explain-render-smoke \
      .#checks.x86_64-linux.tx-deep-diagnosis-emit-explain-smoke \
      .#checks.x86_64-linux.cardano-ledger-wasm-pin-check \
      .#checks.x86_64-linux.protocol-registry-drift-check \
      -o result-gate
    just check-review-types
    just check-review
    nix run --quiet .#ledger-functional-openapi-check
    nix run --quiet .#ledger-functional-swagger-check
    nix run --quiet .#tx-identify-smoke
    nix run --quiet .#tx-witness-plan-smoke
    nix run --quiet .#tx-intent-smoke
    nix run --quiet .#tx-validate-smoke
    nix run --quiet .#tx-evaluate-scripts-smoke
    nix run --quiet .#tx-input-context-smoke
    nix run --quiet .#tx-extism-spike-smoke
    nix run --quiet .#format-check
    nix run --quiet .#hlint

test: ci

build-smokes:
    nix build .#packages.x86_64-linux.wasm-smoke
    nix build .#packages.x86_64-linux.wasm-ledger-smoke

format:
    nix develop --quiet -c find libs apps nix/wasm -type f -name '*.hs' -exec fourmolu -m inplace {} +

format-check:
    nix develop --quiet -c find libs apps nix/wasm -type f -name '*.hs' -exec fourmolu -m check {} +

hlint:
    nix develop --quiet -c hlint libs apps nix/wasm

build-pages-site:
    nix build .#packages.x86_64-linux.ledger-functional-openapi -o result-openapi
    rm -rf _site
    nix develop --quiet -c mkdocs build --strict --site-dir _site
    mkdir -p _site/openapi
    cp -rL result-openapi/* _site/openapi/
