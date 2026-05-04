# Feature Specification: Formalize tx.intent Scripts Detail

**Feature Branch**: `012-intent-scripts-contract`  
**Created**: 2026-05-04  
**Status**: Draft  
**Input**: GitHub issue #57: "tx.intent: information audit — fields decoded by the ledger but dropped from the envelope"

## User Scenarios & Testing

### User Story 1 - API consumers can rely on structured redeemer detail (Priority: P1)

An API consumer calling `tx.intent` needs a documented shape for the existing
`scripts[]` array so it can read redeemer purpose, committed ex-units, and
targeting detail without reverse-engineering implementation code.

**Why this priority**: the runtime already emits this data and the explain
renderer already uses it, so the current problem is contract drift that makes a
real capability look unofficial.

**Independent Test**: run `tx.intent` on the committed Conway fixture and
verify the result contract documents `scripts[]` and the smoke check asserts the
minting redeemer entry shape.

**Acceptance Scenarios**:

1. **Given** a transaction with one or more redeemers, **When** `tx.intent`
   succeeds, **Then** the public schema permits a top-level `scripts[]` array
   whose rows expose redeemer purpose, body index, committed ex-units, and the
   redeemer CBOR.
2. **Given** a spending redeemer row, **When** consumers read `scripts[]`,
   **Then** the contract allows an `input` reference that points at the targeted
   canonical input.
3. **Given** a non-spending redeemer row such as minting or rewarding, **When**
   consumers read `scripts[]`, **Then** the contract does not require a fake
   `input` object.

### User Story 2 - Human reviewers can trace current contract prose to live payloads (Priority: P2)

A reviewer reading the ledger-functional API contract needs the example and
field notes to match the live `tx.intent` payload so they can trust that the
markdown explanation is grounded in a supported API field.

**Why this priority**: the runtime and renderer already expose the data, but the
public docs still imply redeemer detail belongs only to other operations.

**Independent Test**: inspect the updated contract example and confirm it shows
the committed fixture's `minting` redeemer row with committed ex-units and
redeemer CBOR.

**Acceptance Scenarios**:

1. **Given** the `tx.intent` section of the ledger-functional API docs,
   **When** a reader looks for redeemer detail, **Then** the example includes a
   representative `scripts[]` entry from the committed fixture.
2. **Given** the prose below the example, **When** a reader compares it with
   the schema, **Then** the docs describe which `scripts[]` fields are universal
   and which are purpose-specific.

## Edge Cases

- Transactions with zero redeemers must still allow `scripts: []`.
- Spending redeemers may include `input`, but minting / rewarding /
  certifying / voting / proposing redeemers must not be forced to invent one.
- The contract must preserve the exact lowercase purpose names already emitted
  by the runtime (`spending`, `minting`, `certifying`, `rewarding`, `voting`,
  `proposing`).

## Requirements

### Functional Requirements

- **FR-001**: The `tx.intent` result schema MUST define a top-level `scripts`
  array for structured redeemer detail.
- **FR-002**: Each `scripts[]` row MUST include `purpose`, `index`,
  `redeemer_cbor_hex`, and `ex_units_committed`.
- **FR-003**: The schema MUST model `ex_units_committed` as an object with
  string `memory` and `steps` fields.
- **FR-004**: The schema MUST allow a spending redeemer row to include an
  `input` object with `tx_id` and `index`.
- **FR-005**: The schema MUST NOT require `input` on non-spending redeemer
  rows.
- **FR-006**: The ledger-functional API contract example and surrounding prose
  MUST document the `scripts[]` shape in the same PR.
- **FR-007**: `tx-intent-smoke` MUST assert that the committed Conway fixture
  returns a structured `scripts[]` array with at least one minting redeemer row
  carrying committed ex-units and redeemer CBOR.

### Key Entities

- **Intent script row**: one redeemer entry under `tx.intent.scripts[]`,
  carrying purpose, index, optional input reference, committed ex-units, and
  redeemer CBOR.
- **Input reference**: the canonical input targeted by a spending redeemer,
  represented as `{ tx_id, index }`.
- **Committed ex-units**: the redeemer budget committed in the body, expressed
  as memory and steps strings.

## Success Criteria

### Measurable Outcomes

- **SC-001**: The public `tx-intent-result.schema.json` accepts the existing
  redeemer rows emitted by the committed fixtures without relying on opaque
  `additionalProperties` alone.
- **SC-002**: The `tx.intent` API contract shows a concrete `scripts[]` example
  from the committed Conway fixture.
- **SC-003**: `nix build .#checks.x86_64-linux.tx-intent-smoke` fails if
  `scripts[]` disappears, if the minting redeemer loses committed ex-units, or
  if the redeemer CBOR field disappears.
