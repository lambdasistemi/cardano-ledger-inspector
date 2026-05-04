# Tasks: Formalize tx.intent Scripts Detail

**Input**: Design documents from `/specs/012-intent-scripts-contract/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

## Phase 1: Contract surface

- [X] T001 Add `scripts[]` definitions to `specs/001-ledger-functional-layer/schemas/tx-intent-result.schema.json`
- [X] T002 Update `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md` to document `scripts[]`
- [X] T003 Refresh `specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json`

## Phase 2: Live assertion

- [X] T004 Extend `tx-intent-smoke` in `flake.nix` to assert the existing minting redeemer row under `result.intent.scripts[]`

## Phase 3: Verification

- [X] T005 Run `nix build .#checks.x86_64-linux.tx-intent-smoke`
- [X] T006 Run `nix build .#checks.x86_64-linux.ledger-functional-openapi-check`
- [X] T007 Run `just format-check`
