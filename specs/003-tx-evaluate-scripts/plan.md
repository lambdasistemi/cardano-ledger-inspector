# Implementation Plan: Transaction Script Evaluation Operation

**Branch**: `003-tx-evaluate-scripts` | **Date**: 2026-04-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-tx-evaluate-scripts/spec.md`

## Summary

Add `tx.evaluate.scripts` to the Cardano Ledger WASI functional layer as a
ledger-backed operation over the caller's current transaction CBOR and explicit
script-evaluation context. The vertical slice extends the existing operation
envelope, reuses producer transaction evidence for source-output resolution,
returns per-redeemer execution-unit and failure data, and keeps mutation,
balancing, signing, and submission outside this operation.

## Technical Context

**Language/Version**: Haskell2010 compiled with GHC 9.12 to `wasm32-wasi`; PureScript/Halogen browser workbench; Nix flakes and haskell.nix for builds

**Primary Dependencies**: `cardano-ledger-api`, `cardano-ledger-conway`, `cardano-ledger-core`, `cardano-ledger-binary`, `aeson`, `bytestring`, `containers`, `microlens`; existing browser WASI shim and provider byte/context fetchers

**Storage**: None in the ledger layer. Host applications own transaction documents and any fetched context cache, then pass current `tx_cbor` and explicit context on every call.

**Testing**: Nix checks for WASI smoke tests, OpenAPI/Swagger regeneration checks, Fourmolu formatting, PureScript compile, and Playwright browser tests when UI changes are added

**Target Platform**: WASI command artifact consumed by CLI tests and the browser workbench; generated documentation and schemas published through GitHub Pages

**Project Type**: WASI ledger operation package with generated API/docs artifacts and a browser reference UI

**Performance Goals**: Single-transaction script evaluation must remain a local deterministic operation with no network calls; smoke fixtures should run inside the existing CI build gate without adding a service dependency.

**Constraints**: Ledger semantics must come from Haskell ledger code; CBOR remains canonical for transactions and producer evidence; JSON is only the control/result view; evaluation must not sign, submit, patch, balance, update fees, or mutate the transaction.

**Scale/Scope**: One selected Conway transaction per call for 0.1; many redeemers supported; regular inputs/reference inputs resolved through explicit producer transaction context; full wallet coin selection and live-chain submission checks remain separate features.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Ledger Code Is Authoritative**: PASS. The operation delegates transaction decoding, script context construction, and script evaluation to the ledger packages compiled to WASI.
- **Transaction Documents Own State**: PASS. The candidate transaction is always the supplied `tx_cbor`; no hidden workspace state is introduced.
- **JSON Control Plane, CBOR Data Plane**: PASS. Operation requests/results are JSON, while transactions and producer transactions remain CBOR hex.
- **Explicit Context Only**: PASS. Provider fetches are outside the operation. Missing or contradictory context is returned as data instead of guessed.
- **WASI Artifacts Are First-Class**: PASS. The core deliverable is the WASI operation plus Nix checks and generated contract artifacts.
- **Quality Gates**: PASS. Contracts/schemas are planned before UI/provider behavior; implementation must add Nix smoke checks, OpenAPI regeneration checks, Fourmolu, PureScript compile, and Playwright checks for UI work.

## Project Structure

### Documentation (this feature)

```text
specs/003-tx-evaluate-scripts/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
│   └── requirements.md
└── contracts/
    ├── tx-evaluate-scripts.md
    └── schemas/
        ├── tx-evaluate-scripts-args.schema.json
        └── tx-evaluate-scripts-result.schema.json
```

### Source Code (repository root)

```text
nix/wasm/tx-inspector/wasm-tx-inspector/
├── src/Conway/Inspector.hs
└── app/Main.hs

specs/001-ledger-functional-layer/
├── contracts/ledger-functional-api.md
├── openapi/cardano-ledger-functional.openapi.json
└── schemas/
    ├── ledger-operation-request.schema.json
    ├── ledger-operation-response.schema.json
    ├── producer-tx-context.schema.json
    └── tx-evaluate-scripts-result.schema.json

nix/
└── ledger-functional-openapi.nix

flake.nix
justfile
gh-docs/
docs/inspector/
```

**Structure Decision**: Specify the operation in this feature directory first.
Implementation can initially extend `Conway.Inspector` beside `tx.validate`,
but should extract shared context-resolution helpers if the combined operation
dispatcher becomes difficult to review.

## Phase Plan

1. **Contract and schemas**: Promote `tx.evaluate.scripts` into the public
   functional API docs, add result/argument schemas, wire it into the generated
   OpenAPI source, and keep `just check-openapi` / `just check-swagger` green.
2. **WASI operation**: Add operation normalization and dispatch, explicit
   evaluation context decoding, producer transaction source-output resolution,
   and structured evaluation result rendering.
3. **Ledger evaluation coverage**: Add smoke fixtures for no-script,
   incomplete-context, successful-evaluation, and script-failure cases when
   suitable committed transactions are available.
4. **Docs and UI**: Update `gh-docs/api.md`, `gh-docs/functional-layer.md`, and
   README commands. Add browser rendering only after the WASI contract and
   checks are stable, then verify with Playwright.

## Post-Design Constitution Check

- **Ledger Code Is Authoritative**: PASS. The contract explicitly disallows
  browser/provider script evaluation and requires ledger-originated results.
- **Transaction Documents Own State**: PASS. `tx.evaluate.scripts` is stateless
  across calls and never owns the host workspace.
- **JSON Control Plane, CBOR Data Plane**: PASS. The result carries names,
  statuses, paths, execution units, and diagnostics as JSON; transaction data
  remains CBOR hex.
- **Explicit Context Only**: PASS. Missing context uses `incomplete`;
  contradictory context uses `rejected`.
- **WASI Artifacts Are First-Class**: PASS. Nix checks and generated OpenAPI are
  part of the implementation sequence.
- **Quality Gates**: PASS. UI/provider behavior waits for contracts and WASI
  checks.

## Complexity Tracking

No constitution violations or complexity exceptions are required.

## Status

2026-04-27:

- Feature specification, research, data model, contract sketch, schema drafts,
  quickstart, and implementation task plan are created.
- Public schema, generated OpenAPI, public API docs, README command notes, and
  WASI dispatch are wired for `tx.evaluate.scripts`.
- `Conway.Inspector.Evaluation` calls upstream `evalTxExUnitsWithLogs` when
  producer transaction CBOR, network, slot, epoch, and protocol parameters are
  supplied explicitly.
- `just check-evaluate-scripts` verifies incomplete context, rejected
  provider-style UTxO JSON, complete-context evaluation, per-redeemer execution
  units, and deterministic repeated results.
- Remaining follow-up scope: producer-id mismatch fixture, command-level
  malformed request checks specific to this operation, richer multi-purpose
  redeemer fixture coverage, and optional browser UI rendering.
