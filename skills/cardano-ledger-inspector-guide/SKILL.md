---
name: cardano-ledger-inspector-guide
description: Working guide for the lambdasistemi/cardano-ledger-inspector engine repository — Conway ledger operations compiled to wasm32-wasi, an Extism conformance plugin, OpenAPI, protocol registry, and a native diagnosis CLI. Load when a task mentions wasm-tx-inspector, tx-deep-diagnosis, the ledger functional layer or its operations (tx.inspect, tx.browse, tx.identify, tx.intent, tx.witness.plan, tx.witness.attach, tx.validate, tx.evaluate.scripts), Extism exports or extism-spike-host, the protocol registry (registry.json, --registry, --no-bundled-registry, the Amaru journal), Conway.Inspector modules, the ledger-functional OpenAPI contract, error strings like malformed_cbor or unknown_ledger_operation, or engine recipes such as build-wasm, check-identify, or check-validate.
---

# cardano-ledger-inspector guide

## Repository map

| Path | Purpose |
| --- | --- |
| `libs/cardano-ledger-inspector/` | The canonical Haskell library. `src/Conway/Inspector.hs` holds the dispatcher and envelope codec; `Validation.hs`, `Evaluation.hs`, `Context.hs`, `Common.hs` implement the operations. `app/Main.hs` is the 34-line WASI reactor. |
| `apps/tx-deep-diagnosis/` | Native CLI linking the library. `app/Main.hs` parses flags and orchestrates the intent → Blockfrost resolution → validate pipeline; `src/TxDeepDiagnosisHost/` holds Blockfrost, Registry, and the markdown/diagram renderers; `snapshot/Main.hs` is the golden-file harness. |
| `apps/wasm-extism-spike/` | Extism PDK plugin; `src/Extism/Spike.hs` exports `tx_identify`, `tx_validate`, `tx_evaluate_scripts`. |
| `apps/extism-spike-host/` | Native host calling the plugin via libextism/Wasmtime. |
| `docs/inspector/protocols/` | Protocol registry source bundled into the native CLI and exposed as the `protocol-registry` flake package. Its path is a downstream contract. |
| `specs/001-ledger-functional-layer/` | API contract, JSON schemas, OpenAPI document, and committed transaction fixtures. |
| `gh-docs/` | MkDocs pages published to GitHub Pages. |
| `nix/` | `wasm/` (mkCardanoLedgerWasm, forks, wasm C libs), `host/` (native builds, libextism), `ledger-functional-openapi.nix`, and `wasm-targets.nix`. |

## Build, test, run

Use `just` recipes (they wrap `nix build`):

- `just build-wasm` / `just build-openapi` — main generated artifacts.
- `just check-identify`, `check-witness-plan`, `check-witness-attach`,
  `check-intent`, `check-input-context`, `check-validate`,
  `check-evaluate-scripts` — fixture-driven smoke checks, one per operation.
- `just check-extism-spike` — asserts Extism responses match the WASI
  reactor byte-for-byte.
- `just hlint`, `just format` / `format-check`, and
  `just build-pages-site` — lint, formatting, and strict docs/redirect/OpenAPI.
- `just test` — complete engine CI recipe.

The first WASI build is slow (fresh Cabal dependency cache); subsequent
Haskell-only edits rebuild fast. Flake outputs exist for `x86_64-linux` and
`aarch64-darwin`; CI exercises Linux.

## Navigating the code

- Operation dispatch: `libs/cardano-ledger-inspector/src/Conway/Inspector.hs`,
  `runLedgerOperation` — the case table maps the eight `op` strings to
  handlers; `normalizeOperation` accepts legacy unprefixed names.
- Request/response envelope and error categories (`malformed_hex`,
  `malformed_cbor`, `malformed_ledger_operation`,
  `unknown_ledger_operation`): same file plus `app/Main.hs`.
- Validation (`applyTx`, context assembly, missing-context diagnostics):
  `src/Conway/Inspector/Validation.hs`. Phase-2 script evaluation:
  `src/Conway/Inspector/Evaluation.hs`.
- CLI flags (`--cbor`, `--registry`, `--no-bundled-registry`, `--format`,
  `--emit-explain`, `--network`, `--blockfrost-id`, env
  `BLOCKFROST_PROJECT_ID`): `apps/tx-deep-diagnosis/app/Main.hs`.
- Registry layering (bundled via cabal data-files, extra roots concat,
  Amaru journal last-wins): `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Registry.hs`.
- Report section order and renderers:
  `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs` and
  golden files under `apps/tx-deep-diagnosis/test/golden/`.
- Downstream browser product: cardano-swiss-knife consumes the
  `wasm-tx-inspector` and `protocol-registry` flake outputs and owns UI and
  provider adapters.

## Using the ledger operations

The WASI reactor reads one JSON envelope (or raw tx hex) on stdin and
writes one JSON response on stdout:

```bash
nix build .#packages.x86_64-linux.wasm-tx-inspector -o result-wasm
nix develop --quiet -c sh -c \
  'wasmtime result-wasm/wasm-tx-inspector.wasm \
     < specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex'
```

Envelope shape: `{"ledger_functional_layer": "cardano-ledger-functional/v1",
"tx_cbor": "<hex>", "op": "tx.identify", "args": {}}`. Producer context goes
in `args.context.producer_txs`. The native CLI:

```bash
nix run .#tx-deep-diagnosis -- --cbor tx.hex --format explain
```

Extism conformance host:
`extism-spike-host PATH-TO-WASM [FUNCTION] < envelope.json` (FUNCTION
defaults to `tx_identify`).

## Answering questions

- "What operations exist / what do they return?" — README Usage table;
  full contract in `gh-docs/api.md` and
  `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`;
  result schemas under `specs/001-ledger-functional-layer/schemas/`.
- "How do I install / download artifacts?" — `gh-docs/installation.md`
  (release assets, nix build/run, CI artifacts).
- "How does the architecture fit together?" — `gh-docs/architecture.md`
  (layer-by-layer, flake output tables) and the README mermaid diagram.
- "How do I diagnose a transaction?" — `gh-docs/build.md` CLI walkthrough
  (registries, Blockfrost, `--emit-explain` artifacts).
- "How do I identify my protocol's scripts?" —
  `docs/inspector/protocols/README.md` and `WORKED-EXAMPLE.md`.
- "Why doesn't the Go Extism SDK work?" — `apps/wasm-extism-spike/README.md`
  (wazero predates wasm tail-call support; use Wasmtime-backed SDKs).
- The browser workbench lives at
  <https://lambdasistemi.github.io/cardano-swiss-knife/>. This repository's
  Pages site publishes engine documentation and Swagger/OpenAPI; its former
  `/inspector/` route redirects to that workbench.
