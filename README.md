# cardano-ledger-inspector

Cardano ledger operations compiled to WASI, with a browser transaction
workbench that exercises the same Haskell ledger code.

This repository was split out of
[`lambdasistemi/cardano-node-clients`](https://github.com/lambdasistemi/cardano-node-clients)
so the WASI ledger operation layer can evolve independently from the node-client
library.

## What Is Here

- `libs/cardano-ledger-inspector/` — Haskell library implementing the Conway
  ledger operations (`tx.intent`, `tx.validate`, `tx.evaluate.scripts`, …).
  The library plus a 25-line WASI `Main.hs` compile to
  `wasm-tx-inspector.wasm`; the same library is also linked natively by the
  CLI below.
- `apps/tx-deep-diagnosis/` — native CLI that links the inspector library
  directly, resolves producer transactions via Blockfrost, and labels script
  hashes against the protocol registry to produce a layered diagnosis report.
  The default registry (under `docs/inspector/protocols/`) is bundled into
  the binary at build time, so `nix run` works from anywhere with no
  checkout. Pass `--registry DIR` (repeatable) to layer your own protocol
  identifications on top.
- `apps/wasm-extism-spike/` — wasm Extism plugin exposing the inspector's
  operations as named exports for cross-implementation conformance testing.
- `apps/extism-spike-host/` — native Extism host that loads the wasm spike
  via libextism for CI-side conformance checks.
- `docs/inspector/` — PureScript/Halogen browser workbench embedding the WASI
  artifact with `@bjorn3/browser_wasi_shim`.
- `nix/wasm/` — reusable Nix machinery for compiling selected Cardano ledger
  Haskell packages to `wasm32-wasi`.
- `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md` —
  current JSON-control / CBOR-data operation contract.

## Build

```bash
nix build .#packages.x86_64-linux.wasm-tx-inspector -o result-wasm
nix build .#packages.x86_64-linux.tx-inspector-ui -o result-site
nix build .#packages.x86_64-linux.ledger-functional-openapi -o result-openapi
nix build .#packages.x86_64-linux.tx-deep-diagnosis -o result-cli
```

The WASI executable is `./result-wasm/wasm-tx-inspector.wasm`. The built
browser bundle is `./result-site/{index.html,index.js}` after the UI build.
The OpenAPI/Swagger artifact is `./result-openapi/cardano-ledger-functional.openapi.json`
with the JSON schemas it references. The native CLI is
`./result-cli/bin/tx-deep-diagnosis` — see `gh-docs/build.md` for a
walkthrough on the SundaeSwap fixture.

You can also build directly from GitHub:

```bash
nix build github:lambdasistemi/cardano-ledger-inspector#packages.x86_64-linux.wasm-tx-inspector
nix build github:lambdasistemi/cardano-ledger-inspector#packages.x86_64-linux.tx-inspector-ui
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
just check-validate
just check-evaluate-scripts
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
`tx.intent` is covered by the browser suite, including the
`sundae-swap-usdm-disbursement.hex` fixture and a first-viewport signer summary
regression. `just check-intent` verifies signer-perspective value accounting
against a complete producer-context fixture.
`just check-witness-plan` verifies the implemented `tx.witness.plan` response
shape against the same fixture.
`just check-input-context` verifies that explicit `args.context.producer_txs`
entries are decoded by Haskell and reported as complete witness-plan input
context.
`just check-validate` verifies the implemented `tx.validate` response shape,
including incomplete-context diagnostics and producer transaction coverage.
The positive validation fixture is
`specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json`.
`just check-evaluate-scripts` verifies the implemented `tx.evaluate.scripts`
response shape, including incomplete-context diagnostics, per-redeemer budget
data, and complete-context execution-unit reporting.
`just test-playwright` runs the Playwright E2E suite against the packaged inspector UI.
`just test` runs the feature smoke check plus the browser suite.

## Published Site

Repository docs: <https://lambdasistemi.github.io/cardano-ledger-inspector/>

Functional API definition: <https://lambdasistemi.github.io/cardano-ledger-inspector/api/>

Swagger UI: <https://lambdasistemi.github.io/cardano-ledger-inspector/swagger/>

Transaction inspector: <https://lambdasistemi.github.io/cardano-ledger-inspector/inspector/>

Pull-request previews are published to Surge by the `PR preview` workflow.

## Releases

Tagged releases are produced by
[release-please](https://github.com/googleapis/release-please) from
conventional-commit history. Each release attaches:

- `cardano-ledger-reference-<tag>.wasm` — Extism plugin exposing
  `tx_identify` and `tx_validate`. The conformance reference for
  alternative node implementations: load this in your test runner via
  any [Extism host SDK](https://extism.org/docs/concepts/host-sdk),
  call the same exports against the same input, diff your output. The
  Wasmtime-backed SDKs (Rust, Haskell, Python via libextism, etc.)
  work; the Go SDK currently does not because its bundled wazero
  predates wasm tail-call support.
- `wasm-tx-inspector-<tag>.wasm` — same Conway ledger, packaged as a
  WASI reactor (stdin/stdout JSON). Suitable for shell-driven debug
  and the inspector UI.
- `ledger-functional-openapi-<tag>.tar.gz` — OpenAPI contract for the
  JSON envelope.
- `SHA256SUMS-<tag>.txt` — checksums.

Releases: <https://github.com/lambdasistemi/cardano-ledger-inspector/releases>

## CI Artifacts (per-run, ephemeral)

Every `CI` workflow run also uploads per-run artifacts retained for 30
days. Use these for inspecting a specific PR; use a tagged release for
anything you depend on.

- `wasm-tx-inspector` — `wasm-tx-inspector.wasm` plus `SHA256SUMS`.
- `tx-inspector-ui` — static `index.html`, `index.js`, plus `SHA256SUMS`.
- `ledger-functional-openapi` — OpenAPI JSON, referenced schemas, plus
  `SHA256SUMS`.

Open a workflow run under
<https://github.com/lambdasistemi/cardano-ledger-inspector/actions/workflows/ci.yml>
and download them from the run's **Artifacts** section.

## License

See `LICENSE`.
