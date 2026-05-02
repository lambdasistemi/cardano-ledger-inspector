# cardano-ledger-wasi Development Guidelines

Auto-generated from feature plans, then curated for this repository.
Last updated: 2026-04-26

## Active Technologies

- Haskell2010 compiled with GHC 9.12 to `wasm32-wasi`
- PureScript/Halogen browser workbench
- Nix flakes and haskell.nix builds
- Cardano ledger packages: `cardano-ledger-api`, `cardano-ledger-conway`,
  `cardano-ledger-core`, `cardano-ledger-binary`
- JSON/control dependencies: `aeson`, `bytestring`, `containers`, `microlens`

## Project Structure

```text
libs/cardano-ledger-inspector/   # Conway tx inspector library (lib + wasm Main.hs)
apps/tx-deep-diagnosis/          # Native Haskell CLI for layered tx diagnosis
apps/extism-spike-host/          # Native Extism host loading the wasm spike
apps/wasm-extism-spike/          # Wasm Extism plugin spike
docs/inspector/                  # Browser workbench and Playwright tests
specs/                           # Spec Kit artifacts and public API contracts
gh-docs/                         # MkDocs pages published to GitHub Pages
nix/                             # Nix builders, generated OpenAPI source, checks
```

## Commands

```bash
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

## Code Style

- Haskell sources are Fourmolu-formatted.
- Ledger semantics belong in Haskell/WASI, not browser or provider adapters.
- Transaction CBOR and producer transaction CBOR are canonical data-plane
  inputs. JSON is for control arguments, summaries, diagnostics, and views.
- Ledger operations must receive explicit context and must not depend on hidden
  prior calls.

## Recent Changes

- `002-tx-validate`: added the planned `tx.validate` functional operation
  contract, data model, and implementation plan.

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
