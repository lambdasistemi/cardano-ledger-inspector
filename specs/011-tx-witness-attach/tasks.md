# Tasks: Attach a VKey Witness to Transaction CBOR

**Input**: Design documents from `/specs/011-tx-witness-attach/`
**Prerequisites**: plan.md, spec.md
**Tests**: Included because this feature adds a public ledger operation, a new
smoke check, and contract/OpenAPI changes.

## Phase 1: Contract and Check Scaffolding

- [x] T001 Add `tx.witness.attach` to the public operation registry and
  contract text in `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`
- [x] T002 Add a public result schema for the operation under
  `specs/001-ledger-functional-layer/schemas/`
- [x] T003 Add request/response examples and schema registration in
  `nix/ledger-functional-openapi.nix`
- [x] T004 Regenerate
  `specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json`

## Phase 2: Red Test

- [x] T005 Add a new fixture or inline witness payload used by
  `tx.witness.attach` smoke coverage
- [x] T006 Add `tx-witness-attach-smoke` to `flake.nix`
- [x] T007 Add `just check-witness-attach` to `justfile`
- [x] T008 Add the smoke check to `.github/workflows/ci.yml` and
  `scripts/setup-branch-protection.sh`
- [x] T009 Run the new smoke check and confirm it fails before the Haskell
  operation exists

## Phase 3: Implementation

- [x] T010 Add operation normalization and dispatch for `tx.witness.attach` in
  `libs/cardano-ledger-inspector/src/Conway/Inspector.hs`
- [x] T011 Add witness-payload decoding and transaction re-encoding helpers in
  `libs/cardano-ledger-inspector/src/Conway/Inspector/Common.hs` or
  `Conway/Inspector.hs`
- [x] T012 Implement insert-or-replace logic for the vkey witness set while
  preserving non-target witness content
- [x] T013 Return structured `applied` and `rejected` result payloads with
  stable diagnostics

## Phase 4: Verification

- [x] T014 Run `just check-witness-attach`
- [x] T015 Run `just check-openapi` and `just check-swagger`
- [x] T016 Run `just format-check`
- [x] T017 Run relevant repo verification, ending with `just test`
