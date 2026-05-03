# Tasks: tx.intent Required Signer Coverage

**Input**: Design documents from `/specs/008-intent-required-signers/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: Included because this feature changes the public `tx.intent`
signing contract and the generated report snapshots.

## Phase 1: Library and contract

- [X] T001 Extend `tx.intent.signing` with explicit signer arrays in `libs/cardano-ledger-inspector/src/Conway/Inspector.hs`
- [X] T002 Add a `Declared required signers` section to `intent.sections` in `libs/cardano-ledger-inspector/src/Conway/Inspector.hs`
- [X] T003 Update `specs/001-ledger-functional-layer/schemas/tx-intent-result.schema.json` for the expanded signing object
- [X] T004 Update `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md` with the signer coverage shape
- [X] T005 Update `nix/ledger-functional-openapi.nix` and regenerate `specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json`
- [X] T006 Strengthen `tx-intent-smoke` in `flake.nix` to assert the signer arrays are always present

## Phase 2: Renderer and fixtures

- [X] T007 Refresh `apps/tx-deep-diagnosis/test/golden/value-not-conserved/input.json` with the new signing fields and section rows
- [X] T008 Refresh `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/summary.md`
- [X] T009 Refresh `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/explain.md`
- [X] T010 Update `apps/tx-deep-diagnosis/README.md` if the visible report section contract changes

## Phase 3: Verification

- [X] T011 Run `nix build .#checks.x86_64-linux.tx-intent-smoke`
- [X] T012 Run `nix build .#checks.x86_64-linux.tx-explain-render-smoke`
- [X] T013 Run `nix build .#checks.x86_64-linux.ledger-functional-openapi-check`
- [X] T014 Run `just format-check`
