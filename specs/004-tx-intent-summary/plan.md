# Implementation Plan: Transaction Intent Summary

**Branch**: `feat/add-signer-focused-transaction-intent-summary-to-i` | **Date**: 2026-05-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-tx-intent-summary/spec.md`

## Summary

Add `tx.intent` as a ledger-backed WASI operation and render it in the PureScript
browser inspector before lower-level decoded views. The operation returns both
display-ready summary rows and structured fields for API consumers, including
conservative signer-perspective value accounting when input source outputs are
resolved from explicit producer transaction CBOR.

## Technical Context

**Language/Version**: Haskell2010 with GHC 9.12 to `wasm32-wasi`; PureScript/Halogen browser workbench

**Primary Dependencies**: `cardano-ledger-api`, `cardano-ledger-conway`, `cardano-ledger-core`, `aeson`, `bytestring`, `containers`, `microlens`; existing PureScript/Halogen and browser WASI shim

**Storage**: None in the ledger layer. Host applications own transaction bytes and explicit producer context.

**Testing**: `just format-check`, `just ui-check`, `just check-openapi`, `just check-swagger`, `just test-playwright`, and `just test`

**Target Platform**: WASI command artifact plus browser inspector

**Project Type**: WASI ledger operation package with browser reference UI

**Constraints**: Ledger semantics and transaction interpretation stay in Haskell/WASI. JavaScript remains a thin FFI layer; PureScript owns browser rendering.

## Constitution Check

- **Ledger Code Is Authoritative**: PASS. Summary data is generated in Haskell
  from ledger-decoded transaction values and explicit context.
- **Transaction Documents Own State**: PASS. Every call receives current
  `tx_cbor`; no hidden state is introduced.
- **JSON Control Plane, CBOR Data Plane**: PASS. `tx.intent` returns JSON view
  data over CBOR transaction bytes.
- **Explicit Context Only**: PASS. Producer transaction context is read only
  from `args.context.producer_txs`.
- **WASI Artifacts Are First-Class**: PASS. The WASI operation is the primary
  implementation; the browser renders it.
- **Quality Gates**: PASS. Contract/schema docs and Playwright viewport
  regression are part of the implementation.

## Project Structure

```text
nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs
docs/inspector/src/Main.purs
docs/inspector/src/FFI/Json.purs
docs/inspector/src/FFI/Json.js
docs/inspector/tests/tx-identify.spec.mjs
specs/001-ledger-functional-layer/contracts/ledger-functional-api.md
specs/001-ledger-functional-layer/schemas/tx-intent-result.schema.json
specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex
```

## Phase Plan

1. Add `tx.intent` dispatch, result shape, metadata extraction, and summary rows
   to the Haskell ledger operation.
2. Add signer value buckets and net ADA calculation in Haskell when producer
   transaction context resolves every regular input.
3. Render `tx.intent` in PureScript before raw decoded views, keeping JavaScript
   limited to JSON parse FFI.
4. Add a real signing CBOR fixture and a Playwright first-viewport regression
   using `getBoundingClientRect`.
5. Update contract/schema/OpenAPI/docs and run repository checks.

## Complexity Tracking

No constitution violations or complexity exceptions are required.
