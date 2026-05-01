# Tasks: Transaction Intent Summary

**Input**: Design documents from `/specs/004-tx-intent-summary/`
**Prerequisites**: `spec.md`, `plan.md`

## Phase 1: Ledger Operation

- [x] T001 Add `tx.intent` operation normalization and dispatch in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [x] T002 Generate signer-focused metrics, metadata claims, effects, warnings, and structured fields in Haskell
- [x] T003 Decode nested metadata text without hard-coding one auxiliary metadata layout
- [x] T013 Add signer-perspective ADA net and payment-credential value buckets for complete producer context

## Phase 2: Browser Rendering

- [x] T004 Add PureScript `IntentSummary` parsing and rendering in `docs/inspector/src/FFI/Json.purs` and `docs/inspector/src/Main.purs`
- [x] T005 Keep `docs/inspector/src/FFI/Json.js` limited to thin JSON parse interop for the new feature
- [x] T006 Place the intent panel before lower-level inspection, identity, witness, validation, browser, and raw JSON views

## Phase 3: Regression Fixture And Tests

- [x] T007 Add `specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex`
- [x] T008 Add Playwright first-viewport assertions for signer-critical fields using explicit viewport geometry
- [x] T009 Preserve existing identity, witness-plan, validation, and browser behavior tests
- [x] T014 Add WASI smoke coverage for signer net and value buckets using a complete producer-context fixture

## Phase 4: Contracts And Docs

- [x] T010 Add `tx-intent-result.schema.json`
- [x] T011 Update functional API contract, OpenAPI source/generated artifact, README, and GitHub Pages docs
- [x] T012 Run formatting, UI compile, OpenAPI/Swagger checks, Playwright, and repository smoke tests
