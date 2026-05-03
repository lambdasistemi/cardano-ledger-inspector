# Tasks: tx.intent Withdrawal Detail

**Input**: Design documents from `/specs/007-intent-withdrawal-detail/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: Included because this feature changes the public `tx.intent`
contract and the generated report snapshots.

## Phase 1: Library and contract

- [X] T001 Add shared reward-account / withdrawal JSON helpers in `libs/cardano-ledger-inspector/src/Conway/Inspector/Common.hs`
- [X] T002 Emit `result.intent.withdrawals[]` from `libs/cardano-ledger-inspector/src/Conway/Inspector.hs`
- [X] T003 Update `specs/001-ledger-functional-layer/schemas/tx-intent-result.schema.json` for the new withdrawal shape
- [X] T004 Update `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md` with a `withdrawals[]` example and field notes
- [X] T005 Update `nix/ledger-functional-openapi.nix` and the generated `specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json`
- [X] T006 Strengthen `tx-intent-smoke` in `flake.nix` to assert `withdrawals[]` is always present, including the zero-withdrawal fixture

## Phase 2: Renderer

- [X] T007 Add a `Withdrawals` section in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs`
- [X] T008 Refine rewarding-script target text in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs` using `intent.withdrawals[]`
- [X] T009 Update the report contract notes in `apps/tx-deep-diagnosis/README.md`

## Phase 3: Fixtures and verification

- [X] T010 Refresh `apps/tx-deep-diagnosis/test/golden/value-not-conserved/input.json` with the new `intent.withdrawals[]` field
- [X] T011 Refresh `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/summary.md`
- [X] T012 Refresh `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/explain.md`
- [X] T013 Run `nix build .#checks.x86_64-linux.tx-intent-smoke`
- [X] T014 Run `nix build .#checks.x86_64-linux.tx-explain-render-smoke`
- [X] T015 Run `nix build .#checks.x86_64-linux.ledger-functional-openapi-check`
- [X] T016 Run `just format-check`
