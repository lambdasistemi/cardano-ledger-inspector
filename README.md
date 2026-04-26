# cardano-ledger-wasi

Cardano ledger operations compiled to WASI, with a browser transaction
workbench that exercises the same Haskell ledger code.

This repository was split out of
[`lambdasistemi/cardano-node-clients`](https://github.com/lambdasistemi/cardano-node-clients)
so the WASI ledger operation layer can evolve independently from the node-client
library.

## What Is Here

- `nix/wasm/` — reusable Nix machinery for compiling selected Cardano ledger
  Haskell packages to `wasm32-wasi`.
- `nix/wasm/tx-inspector/` — Haskell WASI executable that accepts transaction
  CBOR and ledger operation requests on stdin.
- `docs/inspector/` — PureScript/Halogen browser workbench embedding the WASI
  artifact with `@bjorn3/browser_wasi_shim`.
- `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md` —
  current JSON-control / CBOR-data operation contract.

## Build

```bash
nix build .#packages.x86_64-linux.wasm-tx-inspector -o result-wasm
nix build .#packages.x86_64-linux.tx-inspector-ui -o result-site
nix build .#packages.x86_64-linux.ledger-functional-openapi -o result-openapi
```

The WASI executable is `./result-wasm/wasm-tx-inspector.wasm`. The built
browser bundle is `./result-site/{index.html,index.js}` after the UI build.
The OpenAPI/Swagger artifact is `./result-openapi/cardano-ledger-functional.openapi.json`
with the JSON schemas it references.

You can also build directly from GitHub:

```bash
nix build github:lambdasistemi/cardano-ledger-wasi#packages.x86_64-linux.wasm-tx-inspector
nix build github:lambdasistemi/cardano-ledger-wasi#packages.x86_64-linux.tx-inspector-ui
```

## Development

```bash
just --list
just build-wasm
just build-ui
just check-openapi
just check-swagger
just check-identify
just check-witness-plan
just check-input-context
just test-playwright
just test
```

The first full WASI ledger build can take a long time because Cabal populates a
fresh dependency cache. Haskell-only edits inside the tx inspector use the
split `prebuiltDeps` path and rebuild much faster after the cache exists.
`just check-openapi` and `just check-swagger` regenerate the OpenAPI document
through Nix and fail if it differs from the committed Swagger JSON.
`just check-identify` runs the WASI executable against a committed Conway
transaction fixture and verifies the `tx.identify` response shape.
`just check-witness-plan` verifies the implemented `tx.witness.plan` response
shape against the same fixture.
`just check-input-context` verifies that explicit `args.context.utxo` entries
are parsed and reported as complete witness-plan input context.
`just test-playwright` runs the Playwright E2E suite against the packaged inspector UI.
`just test` runs the feature smoke check plus the browser suite.

## Published Site

Repository docs: <https://lambdasistemi.github.io/cardano-ledger-wasi/>

Functional API definition: <https://lambdasistemi.github.io/cardano-ledger-wasi/api/>

Swagger UI: <https://lambdasistemi.github.io/cardano-ledger-wasi/swagger/>

Transaction inspector: <https://lambdasistemi.github.io/cardano-ledger-wasi/inspector/>

Pull-request previews are published to Surge by the `PR preview` workflow.

## CI Artifacts

Every `CI` workflow run uploads downloadable artifacts:

- `wasm-tx-inspector` — `wasm-tx-inspector.wasm` plus `SHA256SUMS`.
- `tx-inspector-ui` — static `index.html`, `index.js`, plus `SHA256SUMS`.
- `ledger-functional-openapi` — OpenAPI JSON, referenced schemas, plus
  `SHA256SUMS`.

Open a workflow run under
<https://github.com/lambdasistemi/cardano-ledger-wasi/actions/workflows/ci.yml>
and download them from the run's **Artifacts** section.

## License

See `LICENSE`.
