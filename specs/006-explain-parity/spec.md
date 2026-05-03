# Feature Specification: Explain Markdown Parity Phase 1

**Feature Branch**: `006-explain-parity`
**Created**: 2026-05-03
**Status**: Draft
**Input**: GitHub issue #58: "explain.md: feature parity with mainstream tx inspectors (Cardanoscan / Cexplorer / Pool.pm / Etherscan / Solscan / Mempool.space / Starkscan)", scoped to the unblocked work on the current `main` branch

## User Scenarios & Testing

### User Story 1 - Triage a Transaction at First Glance (Priority: P1)

A reader opens the generated `explain.md` and can understand the main action,
overall verdict, failure summary, and balance impact without scrolling through
raw sections or diagrams.

**Why this priority**: The explain document exists to answer "what happened and
why did it fail?" quickly. If the first screen does not do that, the report
loses its primary value.

**Independent Test**: Generate `explain.md` for the committed invalid fixture
and verify the first visible sections are headline, verdict, parsed failures,
balance, and fees/resources before secondary detail sections.

**Acceptance Scenarios**:

1. **Given** a transaction with a meaningful title and a validation outcome,
   **When** the explain document is rendered, **Then** it begins with a
   one-line headline action summary above the verdict section.
2. **Given** a transaction with one or more validation failures, **When** the
   explain document is rendered, **Then** the failure section appears before
   lower-priority narrative sections and each failure is introduced by a
   human-readable sentence rather than a raw rule name alone.
3. **Given** a transaction with known input/output totals, **When** the explain
   document is rendered, **Then** the balance section appears before the
   observations, claims, and effects sections.

### User Story 2 - Distinguish Derived Facts from Self-Declared Claims (Priority: P2)

A reader can tell which parts of the report come from decoded ledger evidence
and which parts come only from transaction metadata.

**Why this priority**: Mainstream inspectors consistently warn when an
explanation is unverified. This report should not present metadata claims with
the same visual authority as ledger-derived facts.

**Independent Test**: Generate the invalid fixture report and verify that
metadata-declared destinations and similar self-declared content are visibly
flagged inline at the point where they are shown.

**Acceptance Scenarios**:

1. **Given** metadata-derived destinations or labels, **When** they are shown in
   the explain document, **Then** each is visibly marked as self-declared and
   not verified.
2. **Given** registry-resolved parties and ledger-derived sections, **When** the
   explain document is rendered, **Then** those sections remain distinct from
   self-declared claims rather than being blended into one undifferentiated
   list.

### User Story 3 - Expand Visual Detail Only When Needed (Priority: P3)

A reader can inspect topology and party diagrams on demand without having the
default reading flow dominated by Mermaid blocks.

**Why this priority**: The issue survey shows that diagrams are secondary to
the textual verdict and tables. The default document should optimize for fast
reading, not visual bulk.

**Independent Test**: Generate `explain.md` and verify the embedded Mermaid
sections are wrapped in collapsed detail blocks with readable summaries while
the main text remains fully visible without expanding them.

**Acceptance Scenarios**:

1. **Given** a rendered explain document with inline diagrams, **When** the file
   is opened, **Then** the diagram sections are collapsed by default behind
   explicit summaries.
2. **Given** a reader who wants the diagrams, **When** they expand a detail
   block, **Then** the same Mermaid content remains available without loss.

### Edge Cases

- Transactions may be valid, invalid, incomplete, or rejected for the supplied
  context; the headline and verdict must still read coherently.
- Some transactions may have no metadata claims, no scripts, or no execution
  units; the report must omit or simplify those sections without leaving broken
  placeholders.
- A failure summary may be absent even when the verdict is not valid; the
  report must still prioritize verdict and balance information.
- Multiple failures may be present; the section must keep them scannable rather
  than collapsing them into one paragraph.

## Requirements

### Functional Requirements

- **FR-001**: The explain document MUST render a one-line headline action
  summary above the verdict section.
- **FR-002**: The explain document MUST prioritize its section order so that
  headline, verdict, failure summary, balance, and fees/resources appear before
  lower-priority narrative or diagram sections.
- **FR-003**: Validation failures in the explain document MUST be introduced by
  human-readable failure sentences, while still preserving the raw rule name as
  supporting detail.
- **FR-004**: The explain document MUST include a fees/resources section showing
  the fee, transaction size, redeemer count, and committed execution-unit totals
  whenever those values are available in the current envelope.
- **FR-005**: Any self-declared metadata-derived destination or claim shown in
  the explain document MUST carry a visible self-declared warning at the point
  of display.
- **FR-006**: The single-file explain document MUST wrap embedded Mermaid
  sections in collapsed detail blocks by default.
- **FR-007**: The rendered markdown contract MUST remain deterministic for the
  same diagnosis input so that snapshot tests continue to be meaningful.
- **FR-008**: The repository documentation for `tx-deep-diagnosis` MUST describe
  the intended top-level section order so reviewers can tell whether future
  changes are accidental.

### Key Entities

- **Explain Document**: The single markdown report produced from one diagnosis
  result, intended for human reading.
- **Headline Action Summary**: The topmost one-line explanation of what the
  transaction appears to do and how it ended.
- **Failure Summary**: The ordered list of validation failures rendered in
  reader-friendly language with raw rule names retained as supporting detail.
- **Fees & Resources Panel**: The compact top-level summary of fee, size,
  redeemer count, and execution-unit totals.
- **Self-Declared Claim**: Any explanation element that comes from transaction
  metadata rather than verified ledger evidence.

## Success Criteria

### Measurable Outcomes

- **SC-001**: In the committed invalid golden fixture, `explain.md` begins with
  headline, verdict, validation failures, balance, and fees/resources before
  observations, claims, effects, warnings, and diagrams.
- **SC-002**: The same golden fixture shows a visible self-declared warning
  wherever metadata-derived destinations or labels are displayed.
- **SC-003**: All inline Mermaid sections in `explain.md` are collapsed behind
  detail summaries in the generated snapshot output.
- **SC-004**: Repository snapshot coverage detects the new ordering and wording
  changes without requiring manual post-processing.
- **SC-005**: The renderer change does not require new ledger fields beyond what
  is already present on the current `main` branch.

## Assumptions

- This phase only covers the work that is unblocked on the current `main`
  branch; features that require new `tx.intent` fields from issue #57 remain
  out of scope.
- The current envelope's existing title, validation failures, tx size, fee,
  redeemer details, and execution-unit data are sufficient for the scoped
  parity improvements.
- The directory-shaped explain artifacts remain supported; this feature focuses
  on the single-file markdown reading experience and shared section renderer.
