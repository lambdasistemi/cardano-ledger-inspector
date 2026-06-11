# Feature Specification: Attach a VKey Witness to Transaction CBOR

**Feature Branch**: `011-tx-witness-attach`

**Created**: 2026-05-04

**Status**: Draft

**Input**: User description: "Add a ledger operation that accepts transaction CBOR plus a generated vkey witness CBOR payload, patches that witness into the transaction witness set, returns the signed transaction CBOR, reports whether the witness was inserted or replaced, and exposes stable diagnostics for malformed or unsupported request inputs."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Attach or Replace a VKey Witness (Priority: P1)

A caller with a decoded transaction body hash and a generated vkey witness can
ask the ledger layer to patch that witness into the transaction CBOR and get
back a new signed transaction artifact.

**Why this priority**: This is the whole point of the issue. The browser and
CLI hosts both need one authoritative ledger-shaped operation for the witness
patch step.

**Independent Test**: Run the new operation with a well-formed witness against
an existing transaction, then re-run it with the same witness against the
patched transaction and confirm the first call inserts while the second call
replaces without changing the transaction body identity.

**Acceptance Scenarios**:

1. **Given** a well-formed transaction and a well-formed vkey witness whose
   verification key is not already present, **When** the caller requests
   witness attachment, **Then** the result returns a patched transaction CBOR
   artifact and reports `inserted`.
2. **Given** a well-formed transaction whose witness set already contains a
   vkey witness for the same verification key, **When** the caller requests
   witness attachment, **Then** the result replaces the prior vkey witness
   instead of duplicating it and reports `replaced`.
3. **Given** a transaction whose witness set contains bootstrap witnesses,
   scripts, redeemers, datums, or other non-vkey content, **When** the caller
   patches a vkey witness, **Then** the non-target witness-set content remains
   present in the returned transaction artifact.

---

### User Story 2 - Reject Malformed Witness Attachment Inputs (Priority: P2)

A caller can distinguish request-level transaction decoding failures from
operation-level witness-input failures and get stable structured diagnostics for
the latter.

**Why this priority**: The operation is only useful if hosts can surface clear
rejection reasons instead of guessing whether the failure came from the
transaction, the witness payload, or unsupported request structure.

**Independent Test**: Invoke the operation with malformed or unsupported
`vkey_witness_cbor_hex` values after the outer request still decodes, and
verify the result reports `rejected` with actionable `errors`.

**Acceptance Scenarios**:

1. **Given** a decoded ledger-operation request that omits the witness payload,
   **When** the caller requests attachment, **Then** the result reports
   `rejected` and identifies the missing argument.
2. **Given** a decoded ledger-operation request whose witness payload is not
   valid hex or not a valid Conway/Shelley vkey witness CBOR item, **When** the
   caller requests attachment, **Then** the result reports `rejected` with a
   stable witness-input diagnostic.
3. **Given** a decoded ledger-operation request whose witness payload decodes
   but is not usable for vkey attachment, **When** the caller requests
   attachment, **Then** the result reports `rejected` and does not emit a fake
   signed transaction artifact.

### Edge Cases

- Transaction hex, transaction CBOR, malformed operation envelopes, and unknown
  operations stay on the existing command-level error boundary.
- The operation may re-encode collections with canonical CBOR lengths as long
  as the resulting transaction remains a valid ledger transaction encoding.
- The supplied witness may be well-formed but unrelated to the transaction
  body; this operation patches witness-set structure and does not validate
  signature correctness.
- Transactions with no prior vkey witness collection still need a new witness
  set entry inserted under the vkey class.
- Transactions that already contain the same verification key witness must not
  accumulate duplicate entries for that key.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST expose a dedicated ledger operation for attaching
  a vkey witness to transaction CBOR.
- **FR-002**: The operation MUST accept the current transaction as canonical
  `tx_cbor` on every call.
- **FR-003**: The operation MUST accept a generated vkey witness payload via
  `args.vkey_witness_cbor_hex`.
- **FR-004**: The operation MUST return a patched transaction artifact as hex
  and MUST identify whether the witness was inserted or replaced.
- **FR-005**: The operation MUST preserve the transaction body and all
  non-target witness-set content while mutating only the vkey witness set.
- **FR-006**: The operation MUST replace an existing vkey witness for the same
  verification key instead of duplicating it.
- **FR-007**: The operation MUST be deterministic for identical `tx_cbor` and
  identical witness payload input.
- **FR-008**: Once the outer request is decoded, malformed or unsupported
  witness-input failures MUST be represented as a structured successful result
  payload, not as command-level process failures.
- **FR-009**: The operation MUST keep secret-key handling out of this
  repository; it accepts detached witness material only.
- **FR-010**: The operation MUST remain scoped to vkey witness attachment and
  replacement only. Bootstrap witness mutation, script witness synthesis, and
  submission remain out of scope.

### Key Entities *(include if feature involves data)*

- **Candidate Transaction**: The authoritative transaction document represented
  as `tx_cbor`.
- **VKey Witness Payload**: A generated verification-key witness represented as
  CBOR hex for a single witness pair.
- **Witness Attachment Result**: The structured outcome describing whether the
  patch was applied, whether it inserted or replaced, the returned transaction
  CBOR artifact, and any warnings or errors.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A smoke check can attach a witness to a known fixture
  transaction, re-run the operation with the same witness, and observe
  `inserted` then `replaced`.
- **SC-002**: Re-inspecting the patched transaction shows the same transaction
  identity and an updated vkey witness count.
- **SC-003**: Structured rejected results identify missing or malformed witness
  arguments without producing a patched transaction artifact.
- **SC-004**: The public contract, schemas, OpenAPI, and CI all expose the new
  operation before downstream UI or CLI hosts depend on it.

## Assumptions

- The transaction itself already decodes as a Conway transaction before this
  operation runs.
- The supplied witness payload is detached witness material generated
  elsewhere.
- Canonical ledger re-encoding is acceptable even when the original bytes used
  different definite/indefinite CBOR collection forms.
