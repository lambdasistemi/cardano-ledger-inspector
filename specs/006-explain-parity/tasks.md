# Tasks: Explain Markdown Parity Phase 1

**Input**: Design documents from `/specs/006-explain-parity/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: Included because the feature is defined by deterministic markdown
artifacts and the existing snapshot smoke is the primary contract.
**Organization**: Tasks are grouped by user story so each report-level parity
improvement can be implemented and verified independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with other marked tasks in the same phase.
- **[Story]**: Which user story this task belongs to.
- Every task includes the main file path it changes or verifies.

## Phase 1: Setup (Shared Documentation Surface)

**Purpose**: Establish the app-local documentation that explains the report
contract being changed in this branch.

- [X] T001 Create `apps/tx-deep-diagnosis/README.md` with the explain artifact purpose, intended top-level section order, and snapshot verification commands

---

## Phase 2: Foundational (Blocking Renderer Prerequisites)

**Purpose**: Add the shared renderer helpers and ordering structure used by all
three user stories.

- [X] T002 Add shared headline/resource extraction helpers in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs`
- [X] T003 Add a reusable collapsed-diagram wrapper in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Single.hs`
- [X] T004 Reorder `renderSummaryMarkdown` in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs` so reader-first sections can be inserted without duplicate passes

**Checkpoint**: The renderer has a stable scaffold for headline/resources,
claim-badge rendering, and collapsed single-file diagrams.

---

## Phase 3: User Story 1 - Triage a Transaction at First Glance (Priority: P1) 🎯 MVP

**Goal**: A reader sees the action headline, verdict, failure summary, balance,
and fees/resources before lower-priority sections.

**Independent Test**: Regenerate the invalid golden fixture and confirm the top
of both `summary.md` and `explain.md` now presents headline, verdict,
validation failures, balance, and fees/resources before the narrative sections.

### Tests for User Story 1

- [X] T005 [US1] Update `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/summary.md` for the new top-of-file ordering and headline/resources content
- [X] T006 [US1] Update `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/explain.md` for the same ordering and wording changes

### Implementation for User Story 1

- [X] T007 [US1] Render a one-line headline action summary in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs`
- [X] T008 [US1] Promote human-readable failure summaries ahead of raw rule names in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs`
- [X] T009 [US1] Add a fees/resources section using current envelope fields in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs`
- [X] T010 [US1] Verify the scoped renderer contract with `nix build .#checks.x86_64-linux.tx-explain-render-smoke`

**Checkpoint**: The explain report is usable as a first-screen triage tool even
before the reader expands diagrams or reads claims.

---

## Phase 4: User Story 2 - Distinguish Derived Facts from Self-Declared Claims (Priority: P2)

**Goal**: Metadata-derived destinations and claims are clearly marked as
unverified without weakening the distinction from registry-resolved evidence.

**Independent Test**: Generate the invalid fixture report and confirm every
metadata-derived destination or claim shown in the report carries visible
self-declared warning text inline.

### Tests for User Story 2

- [X] T011 [US2] Refresh `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/summary.md` for self-declared badges in observations and claims
- [X] T012 [US2] Refresh `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/explain.md` for the same badge behavior

### Implementation for User Story 2

- [X] T013 [US2] Add inline self-declared warning text to metadata destination rendering in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs`
- [X] T014 [US2] Add equivalent self-declared provenance treatment to metadata-driven claims in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs`
- [X] T015 [US2] Re-run `nix build .#checks.x86_64-linux.tx-explain-render-smoke` after the badge changes

**Checkpoint**: Readers can visually separate metadata assertions from
ledger-derived facts.

---

## Phase 5: User Story 3 - Expand Visual Detail Only When Needed (Priority: P3)

**Goal**: Inline Mermaid sections remain available in `explain.md` but are
collapsed by default so the report reads like a document first.

**Independent Test**: Regenerate `explain.md` and confirm the Parties, Topology,
and Failure overlay sections appear under collapsed detail summaries while the
rest of the report remains directly readable.

### Tests for User Story 3

- [X] T016 [US3] Update `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/explain.md` to assert collapsed diagram sections

### Implementation for User Story 3

- [X] T017 [US3] Wrap inline Parties, Topology, and Failure overlay blocks with collapsed details in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Single.hs`
- [X] T018 [US3] Re-run `nix build .#checks.x86_64-linux.tx-explain-render-smoke` after the single-file diagram changes

**Checkpoint**: The single-file explain report keeps the same visual data while
defaulting to a cleaner reading flow.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Finish documentation and repository-level verification for the PR.

- [X] T019 [P] Update the app-local explain contract notes in `apps/tx-deep-diagnosis/README.md` to match the final implementation
- [X] T020 [P] Run `just format-check`
- [X] T021 Run a final `nix build .#checks.x86_64-linux.tx-explain-render-smoke`

---

## Dependencies & Execution Order

- **Setup (Phase 1)** starts immediately and establishes the local docs target.
- **Foundational (Phase 2)** depends on Setup and blocks all user stories
  because the same renderer files are shared by every story.
- **User Story 1 (Phase 3)** depends on Foundational and delivers the MVP.
- **User Story 2 (Phase 4)** depends on Foundational and should be applied after
  the reader-first ordering because it edits the same summary renderer.
- **User Story 3 (Phase 5)** depends on Foundational and is isolated to the
  single-file renderer plus explain snapshot.
- **Polish (Phase 6)** depends on the selected story work being complete.

## Parallel Opportunities

- T019 and T020 can run in parallel after the renderer behavior is stable.
- The summary and explain golden file refresh tasks within each story should be
  done sequentially because they update the same fixture set.

## Implementation Strategy

1. Establish the README target and the shared renderer scaffolding.
2. Implement the P1 reader-first ordering and resource summary first.
3. Add self-declared claim badges.
4. Collapse inline diagrams in the single-file renderer.
5. Refresh the golden outputs and finish with snapshot plus formatting checks.
