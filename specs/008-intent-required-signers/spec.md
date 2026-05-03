# Feature Specification: tx.intent Required Signer Coverage

**Feature Branch**: `008-intent-required-signers`
**Created**: 2026-05-03
**Status**: Draft
**Input**: GitHub issue #57: "tx.intent: information audit — fields decoded by the ledger but dropped from the envelope", scoped to the missing full required-signer list on current `main`

## User Scenarios & Testing

### User Story 1 - See Every Declared Required Signer (Priority: P1)

An API consumer calls `tx.intent` and can see every signer hash the
transaction body declares as required, not only the subset that is missing.

**Why this priority**: The current intent envelope only exposes
`missing_vkey_witnesses`, so readers cannot see who the transaction claims
authority from when all signers are present, or even which declared signers are
already satisfied in partially signed transactions.

**Independent Test**: Run `tx-intent-smoke` and verify the signing object
always includes explicit signer arrays, then render the committed SundaeSwap
fixture and verify the non-empty declared required-signer list appears in the
stored diagnosis envelope.

**Acceptance Scenarios**:

1. **Given** a transaction body with declared required signers, **When**
   `tx.intent` runs, **Then** the response includes one structured row per
   declared required signer.
2. **Given** a transaction body with no declared required signers, **When**
   `tx.intent` runs, **Then** the response still includes `required_signers: []`
   rather than omitting the field.

### User Story 2 - Tell Whether Each Required Signer Is Already Witnessed (Priority: P2)

A reader can tell for each declared required signer whether it is already
covered by a vkey witness, a bootstrap witness, or is still missing.

**Why this priority**: The authorization story is incomplete without coverage
status. A full signer list with no witnessed/missing distinction still leaves
the reader to cross-join multiple arrays manually.

**Independent Test**: Render the current invalid golden fixture and verify the
report includes a `Declared required signers` table whose detail column marks
each signer as present or missing.

**Acceptance Scenarios**:

1. **Given** a declared required signer whose hash matches a vkey witness,
   **When** `tx.intent` runs, **Then** its row is marked as present via vkey
   witness.
2. **Given** a declared required signer whose hash matches a bootstrap witness,
   **When** `tx.intent` runs, **Then** its row is marked as present via
   bootstrap witness.
3. **Given** a declared required signer whose hash matches neither witness
   source, **When** `tx.intent` runs, **Then** its row is marked missing.

### Edge Cases

- Transactions with zero declared required signers must keep the response shape
  deterministic.
- A signer may be witnessed via bootstrap rather than vkey witness.
- The renderer must tolerate older diagnosis envelopes that predate the new
  signer arrays.

## Requirements

### Functional Requirements

- **FR-001**: `tx.intent.signing` MUST include `required_signers`.
- **FR-002**: Each `required_signers[]` item MUST include the signer hash, its
  source, and witness coverage status.
- **FR-003**: `tx.intent.signing` MUST include explicit
  `present_vkey_witnesses` and `present_bootstrap_witnesses` arrays.
- **FR-004**: The `tx.intent` contract documentation and OpenAPI example MUST
  document the expanded `signing` shape in the same PR.
- **FR-005**: The explain report MUST surface a `Declared required signers`
  table derived from the new `tx.intent` data.
- **FR-006**: Older stored diagnosis envelopes without the new arrays MUST
  still render successfully.

### Key Entities

- **Declared Required Signer**: One hash listed in `tx_body.required_signers`.
- **Signer Coverage Status**: Whether a declared signer is already satisfied by
  a vkey witness, a bootstrap witness, or is currently missing.
- **Declared Required Signers Section**: The report table that shows every
  declared signer together with its coverage status.

## Success Criteria

### Measurable Outcomes

- **SC-001**: `tx-intent-smoke` asserts that the expanded signer arrays are
  always present, even when empty.
- **SC-002**: The stored SundaeSwap diagnosis envelope and golden markdown
  outputs show the full declared required-signer set, not only the missing
  subset.
- **SC-003**: Snapshot and OpenAPI checks stay deterministic and pass without
  manual post-processing.

## Assumptions

- This branch is another focused slice of issue #57, not a full closure.
- The current SundaeSwap fixture is sufficient to verify the non-empty case.
- Reusing the existing `sections[]` table shape is preferred over inventing a
  renderer-only special case.
