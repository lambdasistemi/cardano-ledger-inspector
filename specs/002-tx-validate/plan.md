# Implementation Plan: Transaction Validation Operation

**Branch**: `002-tx-validate` | **Date**: 2026-04-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-tx-validate/spec.md`

## Summary

Add `tx.validate` to the Cardano Ledger WASI functional layer as a ledger-backed
operation over the caller's current transaction CBOR and explicit validation
context. The vertical slice extends the existing operation envelope, reuses the
producer transaction input-resolution model from `tx.witness.plan`, introduces a
structured validation result, and adds contract/CI coverage before any browser
UI depends on the operation.

## Technical Context

**Language/Version**: Haskell2010 compiled with GHC 9.12 to `wasm32-wasi`; PureScript/Halogen browser workbench; Nix flakes and haskell.nix for builds

**Primary Dependencies**: `cardano-ledger-api`, `cardano-ledger-conway`, `cardano-ledger-core`, `cardano-ledger-binary`, `aeson`, `bytestring`, `containers`, `microlens`; existing browser WASI shim and provider byte fetchers

**Storage**: None in the ledger layer. Host applications own transaction documents and any producer-transaction cache, then pass current `tx_cbor` and explicit context on every call.

**Testing**: Nix checks for WASI smoke tests, OpenAPI/Swagger regeneration checks, Fourmolu formatting, PureScript compile, and Playwright browser tests when UI changes are added

**Target Platform**: WASI command artifact consumed by CLI tests and the browser workbench; generated documentation and schemas published through GitHub Pages

**Project Type**: WASI ledger operation package with generated API/docs artifacts and a browser reference UI

**Performance Goals**: Single-transaction validation must remain a local deterministic operation with no network calls; smoke fixtures should run inside the existing CI build gate without adding a separate service dependency.

**Constraints**: Ledger semantics must come from Haskell ledger code; CBOR remains canonical for transactions and producer evidence; JSON is only the control/result view; validation must not sign, submit, patch, balance, or mutate the transaction.

**Scale/Scope**: One selected Conway transaction per call for 0.1; many regular inputs/reference inputs supported through explicit producer transaction context; later eras and live-chain submission checks remain separate features.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Ledger Code Is Authoritative**: PASS. The plan routes decoding, input-output extraction, and validation through the Haskell ledger packages already compiled to WASI.
- **Transaction Documents Own State**: PASS. The candidate transaction is always the supplied `tx_cbor`; no hidden workspace state is introduced.
- **JSON Control Plane, CBOR Data Plane**: PASS. The request/result are JSON, while transaction and producer transaction data remain CBOR hex.
- **Explicit Context Only**: PASS. Provider fetches are outside the operation. Missing context is returned as data instead of guessed.
- **WASI Artifacts Are First-Class**: PASS. The core deliverable is the WASI operation plus Nix checks and generated contract artifacts.
- **Quality Gates**: PASS. Contracts/schemas are planned before UI behavior; implementation must add Nix smoke checks, OpenAPI regeneration checks, Fourmolu, PureScript compile, and Playwright checks for UI work.

## Project Structure

### Documentation (this feature)

```text
specs/002-tx-validate/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
│   └── requirements.md
└── contracts/
    ├── tx-validate.md
    └── schemas/
        ├── tx-validate-args.schema.json
        └── tx-validate-result.schema.json
```

### Source Code (repository root)

```text
nix/wasm/tx-inspector/wasm-tx-inspector/
├── src/Conway/Inspector.hs          # Current operation dispatcher and shared tx rendering
└── app/Main.hs                      # WASI stdin/stdout boundary

specs/001-ledger-functional-layer/
├── contracts/ledger-functional-api.md
├── openapi/cardano-ledger-functional.openapi.json
└── schemas/
    ├── ledger-operation-request.schema.json
    ├── ledger-operation-response.schema.json
    ├── producer-tx-context.schema.json
    └── tx-validate-result.schema.json

nix/
└── ledger-functional-openapi.nix    # Generated OpenAPI source

flake.nix                           # Nix packages/checks, including tx.validate smoke
justfile                            # Developer entry points
gh-docs/                            # Published API/docs pages
docs/inspector/                     # Browser workbench and Playwright tests
```

**Structure Decision**: Implement the operation in the existing WASI inspector
package first, extracting helper modules only if the validation code makes
`Conway.Inspector` difficult to review. Contract/schema changes belong under
`specs/001-ledger-functional-layer` for the public API, while this feature's
planning artifacts stay under `specs/002-tx-validate`.

## Phase Plan

1. **Contract and schemas**: Move the planned `tx.validate` contract into the
   public functional API docs, add `tx-validate-result.schema.json`, wire it into
   the generated OpenAPI source, and keep `just check-openapi` green.
2. **WASI operation**: Add `tx.validate` dispatch, shared producer transaction
   input-resolution helpers, explicit context normalization, and validation
   result rendering.
3. **Validation coverage**: Add a Nix smoke check for the incomplete-context
   path and one complete-context fixture when enough ledger context is available
   in-repo. Keep request-level malformed input errors separate from successful
   validation results.
4. **Docs and UI**: Update `gh-docs/api.md`, `gh-docs/functional-layer.md`, and
   README commands. Add browser display only after the contract and WASI checks
   are stable, then verify with Playwright.

## Post-Design Constitution Check

- **Ledger Code Is Authoritative**: PASS. The contract explicitly disallows
  JavaScript/provider validation and keeps provider adapters as byte/context
  suppliers.
- **Transaction Documents Own State**: PASS. `tx.validate` is stateless across
  calls and never owns the host workspace.
- **JSON Control Plane, CBOR Data Plane**: PASS. Contract schemas use JSON for
  names, statuses, paths, and diagnostics; CBOR hex remains the transaction data
  plane.
- **Explicit Context Only**: PASS. The design reports `incomplete` for missing
  context and rejects contradictory context.
- **WASI Artifacts Are First-Class**: PASS. Nix checks and generated OpenAPI are
  part of the implementation sequence.
- **Quality Gates**: PASS. No UI/provider behavior is planned before contracts
  and WASI checks.

## Complexity Tracking

No constitution violations or complexity exceptions are required.
