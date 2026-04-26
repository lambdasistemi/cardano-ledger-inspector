# Tasks: Transaction Validation Operation

**Input**: Design documents from `/specs/002-tx-validate/`
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

**Purpose**: Promote the planned `tx.validate` contract into the public API
surface before implementation depends on it.

- [ ] T001 Copy the planned result schema from `specs/002-tx-validate/contracts/schemas/tx-validate-result.schema.json` to `specs/001-ledger-functional-layer/schemas/tx-validate-result.schema.json`
- [ ] T002 Add `tx.validate` request and response examples to `nix/ledger-functional-openapi.nix`
- [ ] T003 Register `TxValidateResult` in OpenAPI components in `nix/ledger-functional-openapi.nix`
- [ ] T004 Update the operation registry and `tx.validate` section in `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`
- [ ] T005 Regenerate committed OpenAPI JSON in `specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json`
- [ ] T006 Add the `tx.validate` schema link to `gh-docs/api.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Prepare shared code and checks used by all validation stories.
No user story work should begin until this phase is complete.

- [ ] T007 [P] Add `tx.validate` contract-shape assertions to a new Nix check in `flake.nix`
- [ ] T008 [P] Add `just check-validate` to `justfile`
- [ ] T009 Extract producer context and input-resolution helpers from `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs` into a shared section or module
- [ ] T010 Add validation result helper constructors in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T011 Add `normalizeOperation "validate" = "tx.validate"` and dispatch plumbing in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T012 Invoke upstream Conway ledger validation/checking functions and map ledger failures in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T013 Run `just check-openapi` and `just check-swagger` to verify `specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json`

**Checkpoint**: Contract artifacts and operation dispatch are ready for user
story implementation.

---

## Phase 3: User Story 1 - Validate a Candidate Transaction (Priority: P1) MVP

**Goal**: A user with a candidate transaction and complete explicit context can
get a deterministic `valid` or `invalid` result without signing, submitting,
balancing, patching, or mutating the transaction.

**Independent Test**: Run `tx.validate` twice with the same candidate
transaction and explicit context, then verify that the top-level status,
evaluated checks, and failures are equivalent and no `tx_cbor` mutation is
returned.

### Tests for User Story 1

- [ ] T014 [US1] Establish whether complete ledger context is available for `specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json`; if not, document blocked context categories in `specs/002-tx-validate/quickstart.md`
- [ ] T015 [P] [US1] Add a `tx.validate` complete-context smoke request fixture in `specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json`
- [ ] T016 [US1] Add jq assertions for valid/invalid validation result shape in `flake.nix`
- [ ] T017 [US1] Add determinism assertions for repeated `tx.validate` runs in `flake.nix`

### Implementation for User Story 1

- [ ] T018 [US1] Implement `validateTxJson` result rendering in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T019 [US1] Populate candidate `tx_id`, `body_hash`, `complete`, and `valid_for_supplied_context` in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T020 [US1] Add evaluated validation check groups and failure rendering in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T021 [US1] Attach `path` or related input/location metadata to every validation failure in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T022 [US1] Ensure `tx.validate` never returns `result.tx_cbor` or mutating changes in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T023 [US1] Run `just check-validate` and record any fixture limitations in `specs/002-tx-validate/quickstart.md`

**Checkpoint**: User Story 1 works independently as the MVP validation surface.

---

## Phase 4: User Story 2 - Diagnose Missing Validation Context (Priority: P2)

**Goal**: A user can tell what external context is missing and what to provide
next when validation cannot complete.

**Independent Test**: Run `tx.validate` with omitted context and verify
`status: "incomplete"`, non-empty `missing_context`, blocked checks marked
`not_evaluated`, and no claim that the transaction is valid or invalid.

### Tests for User Story 2

- [ ] T024 [P] [US2] Add a missing-context smoke request fixture in `specs/001-ledger-functional-layer/fixtures/tx-validate-missing-context-request.json`
- [ ] T025 [P] [US2] Add malformed `tx.validate` request fixtures in `specs/001-ledger-functional-layer/fixtures/tx-validate-malformed-requests.json`
- [ ] T026 [US2] Add jq assertions for `status == "incomplete"` and actionable `missing_context` entries in `flake.nix`
- [ ] T027 [US2] Add jq assertions that missing context is reported separately from `failures` in `flake.nix`
- [ ] T028 [US2] Add assertions that malformed hex, malformed CBOR, and malformed operation envelopes remain command-level errors in `flake.nix`

### Implementation for User Story 2

- [ ] T029 [US2] Implement missing source-output diagnostics in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T030 [US2] Implement missing network, slot, epoch, and protocol-parameter diagnostics in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T031 [US2] Add path fields for every missing-context item in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T032 [US2] Reject or explicitly label caller-provided non-CBOR UTxO context in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T033 [US2] Ensure partially evaluated checks can return both `failures` and `missing_context` in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T034 [US2] Run `just check-validate` and verify the missing-context fixture output in `result-validate-smoke/response.json`

**Checkpoint**: User Story 2 works independently and incomplete validation is
actionable.

---

## Phase 5: User Story 3 - Resolve Inputs From Producer Transactions (Priority: P3)

**Goal**: A user can provide producer transaction CBOR and see which candidate
inputs and reference inputs resolve to stable source outputs.

**Independent Test**: Run `tx.validate` with producer transaction CBOR for
visible inputs and verify resolved input rows, mismatch rejection, and
unresolved input reporting.

### Tests for User Story 3

- [ ] T035 [P] [US3] Add a producer-context validation smoke request fixture in `specs/001-ledger-functional-layer/fixtures/tx-validate-producer-context-request.json`
- [ ] T036 [US3] Add jq assertions for `resolved_inputs` and `resolved_reference_inputs` in `flake.nix`
- [ ] T037 [P] [US3] Add a producer-id mismatch fixture in `specs/001-ledger-functional-layer/fixtures/tx-validate-producer-mismatch-request.json`
- [ ] T038 [US3] Add jq assertions that mismatched producer evidence produces `status == "rejected"` or invalid-context errors in `flake.nix`

### Implementation for User Story 3

- [ ] T039 [US3] Reuse producer transaction decoding to fill `resolved_inputs` in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T040 [US3] Reuse producer transaction decoding to fill `resolved_reference_inputs` in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T041 [US3] Validate producer map keys against decoded producer transaction ids in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T042 [US3] Report missing output indexes as invalid context in `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T043 [US3] Run `just check-input-context` and `just check-validate` to verify input-resolution behavior in `result-input-context-smoke/response.json`

**Checkpoint**: User Story 3 works independently and producer transaction
evidence is explicit, stable, and navigable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Finish repo integration, docs, formatting, and optional browser
surface.

- [ ] T044 [P] Update implemented operation docs in `gh-docs/functional-layer.md`
- [ ] T045 [P] Update developer commands and CI artifact notes in `README.md`
- [ ] T046 [P] Add `tx.validate` to the implemented operations table in `gh-docs/api.md`
- [ ] T047 Add `tx-validate-result.schema.json` to the public schema list in `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`
- [ ] T048 Run Fourmolu formatting check with `just format-check` for `nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs`
- [ ] T049 Run PureScript compile with `just ui-check` for `docs/inspector/src/Main.purs`
- [ ] T050 Run full repository verification with `just test` for `flake.nix`
- [ ] T051 [P] If a browser validation panel is added, implement result decoding in `docs/inspector/src/FFI/Json.js`
- [ ] T052 [P] If a browser validation panel is added, implement UI rendering in `docs/inspector/src/Main.purs`
- [ ] T053 If browser validation UI is added, verify it with Playwright in `docs/inspector/tests/tx-identify.spec.mjs`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**: no dependencies.
- **Phase 2 Foundational**: depends on Phase 1 because generated contracts must
  exist before dispatch and checks reference them.
- **US1 MVP**: depends on Phase 2. Delivers the first usable `tx.validate`
  operation.
- **US2 Missing Context**: depends on Phase 2 shared result helpers. It must
  remain independently testable by using omitted-context fixtures.
- **US3 Producer Context**: depends on Phase 2 and the shared input-resolution
  helpers. It can proceed in parallel with US2 after the foundation is complete.
- **Polish**: depends on the implemented stories being selected for the PR.

### User Story Dependencies

- **US1 (P1)**: MVP. No dependency on US2 or US3 after foundational helpers.
- **US2 (P2)**: Uses the shared result constructors from Phase 2 but must be
  testable with missing-context fixtures alone.
- **US3 (P3)**: Uses shared producer context parsing and reports resolved input
  coverage. It should not require browser work.

### Within Each User Story

- Add smoke fixture and jq assertions before implementation tasks.
- Implement Haskell result rendering before docs/UI updates.
- Run the story-specific check at the checkpoint before moving to polish.

## Parallel Opportunities

- T007 and T008 can run in parallel once Phase 1 is committed.
- T015 can run in parallel with Haskell planning for US1, but T016 and T017
  both edit `flake.nix` and should be sequenced.
- T024 and T025 can run in parallel for US2 because they add different fixture
  files; T026, T027, and T028 all edit `flake.nix` and should be sequenced.
- T035 and T037 can run in parallel for US3 because they add different fixture
  files; T036 and T038 both edit `flake.nix` and should be sequenced.
- T044, T045, and T046 can run in parallel during polish.
- T051 and T052 can run in parallel if browser UI work is selected.

## Parallel Examples

### User Story 1

```text
Task: "Add a tx.validate complete-context smoke request fixture in specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json"
Task: "Implement validateTxJson result rendering in nix/wasm/tx-inspector/wasm-tx-inspector/src/Conway/Inspector.hs"
```

### User Story 2

```text
Task: "Add a missing-context smoke request fixture in specs/001-ledger-functional-layer/fixtures/tx-validate-missing-context-request.json"
Task: "Add malformed tx.validate request fixtures in specs/001-ledger-functional-layer/fixtures/tx-validate-malformed-requests.json"
```

### User Story 3

```text
Task: "Add a producer-context validation smoke request fixture in specs/001-ledger-functional-layer/fixtures/tx-validate-producer-context-request.json"
Task: "Add a producer-id mismatch fixture in specs/001-ledger-functional-layer/fixtures/tx-validate-producer-mismatch-request.json"
```

## Implementation Strategy

### MVP First

1. Complete Phase 1 setup and Phase 2 foundational work.
2. Complete Phase 3 / US1.
3. Stop and validate with `just check-validate`, `just check-openapi`, and
   `just check-swagger`.
4. Open the MVP for review before adding browser UI.

### Incremental Delivery

1. Add contract and schema coverage.
2. Add `tx.validate` dispatch and upstream ledger validation/checking.
3. Add MVP validation result and failure location metadata.
4. Add missing-context diagnostics and command-level error boundary coverage.
5. Add producer transaction input-resolution diagnostics.
6. Add docs and optional browser panel.

### Verification Gates

- Contract/schema changes: `just check-openapi` and `just check-swagger`.
- Haskell changes: `just check-validate`, `just check-identify`,
  `just check-witness-plan`, and `just check-input-context`.
- UI changes: `just ui-check` and `just test-playwright`.
- Final PR: `just test`.

## Notes

- `[P]` tasks are file-disjoint or fixture/check-disjoint enough to run in
  parallel after their phase prerequisites.
- The planned browser work is optional until the WASI operation and contract are
  stable.
- A valid `tx.validate` result means valid for supplied context, not future
  network acceptance.
