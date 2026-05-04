# Tasks: Formalize tx.intent Output Rows and Asset Detail

**Input**: Design documents from `/specs/011-intent-output-values-assets/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: Included because this slice changes both the public contract and the
human-facing report.

## Phase 1: Contract surface

- [X] T001 Add an explicit `value.outputs[]` definition to `specs/001-ledger-functional-layer/schemas/tx-intent-result.schema.json`
- [X] T002 Update `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md` to describe `value.outputs[]`
- [X] T003 Refresh `specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json`

## Phase 2: Verification of live payload

- [X] T004 Extend `tx-intent-smoke` in `flake.nix` to assert that
      `value.outputs[]` exists and that the existing Conway fixture has at
      least one non-empty `assets` map

## Phase 3: Renderer

- [X] T005 Add an Assets column to
      `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs`
- [X] T006 Refresh
      `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/summary.md`
- [X] T007 Refresh
      `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/explain.md`

## Phase 4: Verification

- [X] T008 Run `nix build .#checks.x86_64-linux.tx-intent-smoke`
- [X] T009 Run `nix build .#checks.x86_64-linux.ledger-functional-openapi-check`
- [X] T010 Run `nix build .#checks.x86_64-linux.tx-explain-render-smoke`
- [X] T011 Run `just format-check`
