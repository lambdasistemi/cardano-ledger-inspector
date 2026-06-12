# cardano-ledger-inspector — Agent Guide

## What this repo is

One Haskell library (`libs/cardano-ledger-inspector/`) implements eight
Conway ledger operations (`tx.inspect`, `tx.browse`, `tx.identify`,
`tx.intent`, `tx.witness.plan`, `tx.witness.attach`, `tx.validate`,
`tx.evaluate.scripts`) behind the JSON dispatcher
`Conway.Inspector.runLedgerOperationInput`. The library is compiled three
ways: to a `wasm32-wasi` reactor (`wasm-tx-inspector.wasm`, GHC 9.12) used
by the browser workbench, to a wasm Extism plugin for cross-implementation
conformance testing, and natively (GHC 9.8.4) into the `tx-deep-diagnosis`
CLI. Builds are Nix flakes (haskell.nix + CHaP pins); the UI is
PureScript/Halogen built with spago.

## Project structure

```text
libs/cardano-ledger-inspector/   # Conway tx inspector library (lib + WASI Main.hs)
apps/tx-deep-diagnosis/          # Native Haskell CLI for layered tx diagnosis
apps/extism-spike-host/          # Native Extism host loading the wasm spike
apps/wasm-extism-spike/          # Wasm Extism plugin (tx_identify/tx_validate/tx_evaluate_scripts)
docs/inspector/                  # Browser workbench, Playwright tests, protocol registry
specs/                           # Spec Kit artifacts, public API contracts, fixtures
gh-docs/                         # MkDocs pages published to GitHub Pages
nix/                             # Nix builders (wasm + native), generated OpenAPI source
scripts/                         # fetch-tx-cbor.sh, setup-branch-protection.sh
```

## How to work here

All workflows go through `just` (run `just --list` for everything):

```bash
just build-wasm                # nix build the WASI reactor
just build-ui                  # nix build the browser bundle
just check-openapi             # OpenAPI regen matches committed spec
just check-identify            # tx.identify smoke against committed fixture
just check-witness-plan
just check-witness-attach
just check-intent
just check-input-context
just check-validate
just check-evaluate-scripts
just check-extism-spike        # Extism vs WASI byte-identical conformance
just hlint                     # lint
just format                    # fourmolu in place
just ui-check                  # spago build of the workbench
just test-playwright           # browser E2E against the packaged UI
just test                      # smokes + lint + browser suite
```

The first full WASI build populates a Cabal dependency cache and is slow;
later Haskell-only edits rebuild fast through the split `prebuiltDeps`
path. The docs site builds with `mkdocs build --strict` (mkdocs + material
are in the dev shell).

## Code style and boundaries

- Haskell sources are Fourmolu-formatted (`just format-check` gates CI).
- Ledger semantics belong in Haskell/WASI, not browser or provider adapters.
- Transaction CBOR and producer transaction CBOR are canonical data-plane
  inputs. JSON is for control arguments, summaries, diagnostics, and views.
- Ledger operations must receive explicit context and must not depend on
  hidden prior calls.

## Skills

Activatable procedures live under `skills/`:

- `skills/cardano-ledger-inspector-guide/` — repository map, build/test
  commands, code navigation, and how to run the ledger operations; load it
  when working on or answering questions about this repo.
