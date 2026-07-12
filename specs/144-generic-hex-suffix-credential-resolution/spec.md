# Feature Specification: Generic hex-suffix credential resolution

**Feature Branch**: `feat/144-generic-hex-suffix-resolution`  
**Created**: 2026-07-12  
**Status**: Ready for implementation  
**Input**: GitHub issue #144, “Generic hex-suffix credential resolution query (fix book/emitter IRI mismatch)”.

## User Scenarios & Testing

### User Story 1 — Resolve a named credential across IRI types (Priority: P1)

An inspector user loads the existing Amaru treasury resolution book and a
Conway transaction containing a credential whose identifier uses a
credential-specific leaf type. They see the human label from the book even
though the book stored the same hash under a generic bucket.

**Why this priority**: The current identifier spelling mismatch makes valid,
already-curated owner labels invisible to the transaction inspection flow.

**Independent Test**: With the unmodified bundled Amaru treasury book and the
scoped real Conway transaction, the resolved-label lens reports both owner
labels and the transaction credential identifiers that matched them.

**Acceptance Scenarios**:

1. **Given** a selected book declares `urn:cardano:id:key:<hex>` with a label
   and the transaction graph declares `urn:cardano:id:PaymentKey:<hex>`,
   **when** the resolved-label lens runs, **then** it returns the book label
   and the transaction identifier as the match.
2. **Given** the real scoped transaction and the bundled, unmodified Amaru
   treasury overlay, **when** the Graph / RDF result is shown, **then** the
   labels “Amaru Network Compliance owner key” and “Amaru Ops And Use Cases
   owner key” resolve for hashes
   `8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1` and
   `f3ab64b0f97dcf0f91232754603283df5d75a1201337432c04d23e2e`.
3. **Given** a resolution that already matches under the existing query,
   **when** the extended lens runs, **then** that resolution remains visible
   with its prior label and match value.

### Edge Cases

- A label with no transaction identifier sharing its final hash segment is not
  presented as a resolved credential.
- Two differently typed credentials may share identical hash bytes. Their
  bucket/leaf type is intentionally not used to disambiguate this lookup; the
  documented result may therefore be ambiguous. Resolving that collision is
  outside this ticket.
- Non-credential overlay labels retain their current resolution behavior.

## Requirements

### Functional Requirements

- **FR-001**: The inspector MUST resolve a transaction identifier of the form
  `urn:cardano:id:<AnyLeafType>:<hex>` to a book identifier of the form
  `urn:cardano:id:<AnyBucket>:<hex>` by its final hexadecimal segment, rather
  than requiring complete identifier equality.
- **FR-002**: The resolved-label result MUST expose the concrete transaction
  identifier that matched each book label.
- **FR-003**: Existing labels and resolutions that already appear in the
  resolved-label lens MUST continue to appear correctly.
- **FR-004**: The bundled Amaru treasury overlay and the tx-graph emitter MUST
  remain unchanged.
- **FR-005**: A regression test MUST exercise the two scoped owner hashes from
  the real Conway transaction against the unmodified bundled overlay.
- **FR-006**: The query-level documentation MUST state that equal hash bytes
  across differently typed credentials are an accepted ambiguous-match
  limitation of this ticket.

### Key Entities

- **Book credential identifier**: A labelled identity in a selected resolution
  book, categorised by a broad bucket such as key or script.
- **Transaction credential identifier**: A graph identity emitted for a
  concrete credential leaf type in the transaction being inspected.
- **Credential hash suffix**: The hexadecimal portion shared by the two
  identifier forms and used as the lookup key.

## Success Criteria

### Measurable Outcomes

- **SC-001**: The regression asserts both scoped Amaru owner labels and both
  concrete matched transaction identifiers in one real transaction flow.
- **SC-002**: The existing resolved-label regression remains green without
  changing the overlay book or emitter data.
- **SC-003**: The focused UI build and regression test complete successfully
  through the ticket gate.

## Assumptions

- Resolution books and transaction graphs continue to use colon-delimited
  `urn:cardano:id:` identifiers whose final segment is the canonical hash.
- The selected overlay is the authority for the human-facing label.
- Type-aware collision disambiguation is a separate product decision and is
  explicitly not introduced here.
