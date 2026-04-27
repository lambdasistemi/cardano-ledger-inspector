# Tasks: Transaction Script Evaluation Operation

**Input**: Design documents from `/specs/003-tx-evaluate-scripts/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/
**Tests**: Included because the plan requires Nix smoke checks, OpenAPI checks,
and Playwright verification for UI work.
**Organization**: Tasks are grouped by user story so each story can be
implemented and tested independently after the foundational contract work.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with other marked tasks in the same phase.
- **[Story]**: User story traceability label.
- Every task includes the main file path it changes or verifies.

## Phase 1: Setup (Shared Contract Scaffolding)

**Purpose**: Promote the planned `tx.evaluate.scripts` contract into the public
API surface before implementation depends on it.

- [ ] T001 Copy `contracts/schemas/tx-evaluate-scripts-result.schema.json` to `specs/001-ledger-functional-layer/schemas/tx-evaluate-scripts-result.schema.json`
- [ ] T002 Add `tx.evaluate.scripts` request and response examples to `nix/ledger-functional-openapi.nix`
- [ ] T003 Register `TxEvaluateScriptsResult` in OpenAPI components in `nix/ledger-functional-openapi.nix`
- [ ] T004 Update the operation registry and `tx.evaluate.scripts` section in `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`
- [ ] T005 Regenerate committed OpenAPI JSON in `specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json`
- [ ] T006 Add the `tx.evaluate.scripts` schema link to `gh-docs/api.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Prepare shared context-resolution code and smoke checks used by
all script-evaluation stories.

- [ ] T007 [P] Add `tx.evaluate.scripts` contract-shape assertions to a new Nix check in `flake.nix`
- [ ] T008 [P] Add `just check-evaluate-scripts` to `justfile`
- [ ] T009 Extract or reuse producer context and input-resolution helpers from `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T010 Add script-evaluation result helper constructors in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T011 Add `normalizeOperation "evaluate.scripts" = "tx.evaluate.scripts"` and dispatch plumbing in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T012 Decode explicit script-evaluation context from operation args in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T013 Run `just check-openapi` and `just check-swagger` to verify generated API artifacts

**Checkpoint**: Contract artifacts and operation dispatch are ready for user
story implementation.

---

## Phase 3: User Story 1 - Evaluate Phase-2 Scripts (Priority: P1)

**Goal**: A user with a candidate transaction and complete explicit context can
see whether every phase-2 script evaluates successfully and how many execution
units each redeemer consumes.

**Independent Test**: Run `tx.evaluate.scripts` twice with the same candidate
transaction and explicit context, then verify that per-redeemer statuses and
execution units are equivalent and no `tx_cbor` mutation is returned.

### Tests for User Story 1

- [ ] T014 [US1] Add a complete-context script-evaluation fixture in `specs/001-ledger-functional-layer/fixtures/tx-evaluate-scripts-complete-request.json`
- [ ] T015 [US1] Add jq assertions for `status == "succeeded"` and per-redeemer execution units in `flake.nix`
- [ ] T016 [US1] Add determinism assertions for repeated `tx.evaluate.scripts` runs in `flake.nix`

### Implementation for User Story 1

- [ ] T017 [US1] Invoke upstream ledger script evaluation and map successful redeemer execution units in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T018 [US1] Populate candidate `tx_id`, `body_hash`, `complete`, `scripts_evaluate_for_supplied_context`, and `total_ex_units` in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T019 [US1] Ensure `tx.evaluate.scripts` never returns `result.tx_cbor` or mutating changes in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T020 [US1] Run `just check-evaluate-scripts` and record fixture limitations in `specs/003-tx-evaluate-scripts/quickstart.md`

**Checkpoint**: User Story 1 works independently as the MVP script-evaluation
surface.

---

## Phase 4: User Story 2 - Diagnose Missing or Invalid Evaluation Context (Priority: P2)

**Goal**: A user can tell what external context is missing or contradictory and
what to provide next when script evaluation cannot complete.

**Independent Test**: Run `tx.evaluate.scripts` with omitted context and verify
`status: "incomplete"`, non-empty `missing_context`, blocked redeemers marked
`not_evaluated`, and no claim that scripts succeeded or failed.

### Tests for User Story 2

- [ ] T021 [P] [US2] Add a missing-context script-evaluation fixture in `specs/001-ledger-functional-layer/fixtures/tx-evaluate-scripts-missing-context-request.json`
- [ ] T022 [P] [US2] Add a producer-id mismatch fixture in `specs/001-ledger-functional-layer/fixtures/tx-evaluate-scripts-producer-mismatch-request.json`
- [ ] T023 [US2] Add jq assertions for `status == "incomplete"` and actionable `missing_context` entries in `flake.nix`
- [ ] T024 [US2] Add jq assertions that contradictory context produces `status == "rejected"` or structured context errors in `flake.nix`
- [ ] T025 [US2] Add assertions that malformed hex, malformed CBOR, and malformed operation envelopes remain command-level errors in `flake.nix`

### Implementation for User Story 2

- [ ] T026 [US2] Implement missing source-output diagnostics for script inputs in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T027 [US2] Implement missing protocol-parameter, cost-model, network, slot, and epoch diagnostics in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T028 [US2] Reject or explicitly label caller-provided non-CBOR UTxO context in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T029 [US2] Ensure partially associated redeemers can return both `failures` and `missing_context` in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T030 [US2] Run `just check-evaluate-scripts` and verify missing-context output

**Checkpoint**: User Story 2 works independently and incomplete evaluation is
actionable.

---

## Phase 5: User Story 3 - Navigate Script Evidence and Budgets (Priority: P3)

**Goal**: A user can connect every script evaluation result back to the
transaction area that caused it and compare budgeted versus evaluated execution
units.

**Independent Test**: Evaluate a transaction with multiple redeemer purposes
and verify that every result has stable labels, paths, copyable identifiers,
and budget/evaluation data where available.

### Tests for User Story 3

- [ ] T031 [P] [US3] Add a fixture with multiple redeemer purposes if available in `specs/001-ledger-functional-layer/fixtures/`
- [ ] T032 [US3] Add jq assertions for redeemer `purpose`, `index`, `path`, script identifiers, and budget/evaluated unit fields in `flake.nix`
- [ ] T033 [US3] Add a no-script transaction fixture or assertion for `status == "not_applicable"` in `flake.nix`

### Implementation for User Story 3

- [ ] T034 [US3] Attach navigation paths to every redeemer result in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T035 [US3] Report budgeted execution units from the candidate transaction and evaluated execution units from ledger evaluation in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T036 [US3] Include script hash, redeemer data hash, datum hash, and related input identifiers where available in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T037 [US3] Run `just check-evaluate-scripts` and verify navigation fields in the smoke response

**Checkpoint**: User Story 3 works independently and evaluation results are
navigable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Finish repo integration, docs, formatting, and optional browser
surface.

- [ ] T038 [P] Update implemented operation docs in `gh-docs/functional-layer.md`
- [ ] T039 [P] Update developer commands and CI artifact notes in `README.md`
- [ ] T040 [P] Add `tx.evaluate.scripts` to the implemented operations table in `gh-docs/api.md`
- [ ] T041 Add `tx-evaluate-scripts-result.schema.json` to the public schema list in `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`
- [ ] T042 Run Fourmolu formatting check with `just format-check` for Haskell changes
- [ ] T043 Run PureScript compile with `just ui-check` if browser code changes
- [ ] T044 Run full repository verification with `just test`
- [ ] T045 [P] If a browser evaluation panel is added, implement result decoding in `docs/inspector/src/FFI/Json.js`
- [ ] T046 [P] If a browser evaluation panel is added, implement UI rendering in `docs/inspector/src/Main.purs`
- [ ] T047 If browser evaluation UI is added, verify it with Playwright in `docs/inspector/tests/tx-identify.spec.mjs`

## Dependencies & Execution Order

- Phase 1 Setup has no dependencies.
- Phase 2 Foundational depends on Phase 1 because generated contracts must
  exist before dispatch and checks reference them.
- US1 MVP depends on Phase 2 and delivers the first usable operation.
- US2 Missing/Invalid Context depends on Phase 2 shared result helpers and can
  proceed in parallel with US1 fixture search.
- US3 Navigation/Budgets depends on Phase 2 and can proceed after redeemer
  association exists.
- Polish depends on selected user stories being implemented for the PR.

## Parallel Opportunities

- T007 and T008 can run in parallel once Phase 1 is committed.
- T021 and T022 can run in parallel because they add different fixtures.
- T038, T039, and T040 can run in parallel after operation behavior stabilizes.

## Implementation Strategy

1. Contract/schema/OpenAPI first.
2. WASI dispatch plus an incomplete-context result.
3. Complete-context ledger evaluation fixture and per-redeemer execution units.
4. Missing/rejected context coverage.
5. Navigation fields, docs, and optional browser panel.
