# Feature Specification: Transaction-scoped Structure resolution demo

**Feature Branch**: `feat/139-structure-resolution-demo`
**Created**: 2026-07-15
**Status**: Ready for implementation
**Input**: GitHub issue #139, “Demonstrate transaction-scoped book resolution in Structure”, its scoping comment, parent epic #97, and merged prerequisite #144.

## User Scenarios & Testing

### User Story 1 — Resolve a required signer inline (Priority: P1)

As a transaction investigator, I load a bundled real Conway transaction and
see an opaque required-signer credential hash in Structure. After applying the
bundled Amaru treasury book, that same transaction row gains the familiar
owner label, its RDF type, and the source-book cue while the original hash
remains visible and copyable.

**Why this priority**: This is the visible proof that open books can explain a
transaction-specific credential. It deliberately exercises #144's generic
hex-suffix join between a book's `urn:cardano:id:key:<hex>` identity and the
emitter's `urn:cardano:id:PaymentKey:<hex>` identity; an address-only example
would not prove that fix.

**Independent Test**: From a clean browser store, deselect the Amaru treasury
book, load the bundled owner-key example, observe the raw required-signer hash,
then select/apply the book and observe the exact owner label, type, source, raw
hash, copy action, and transaction-scoped count without repeating the full
decode pipeline.

**Acceptance Scenarios**:

1. **Given** the committed
   `specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex`
   transaction and the Amaru book deselected, **when** the bundled example is
   loaded, **then** Structure exposes required signer
   `8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1` as a raw,
   copyable transaction identifier without an owner label.
2. **Given** that decoded transaction, **when** the bundled Amaru treasury book
   is selected and applied, **then** the same Structure row displays “Amaru
   Network Compliance owner key”, its RDF-derived owner type, and “Amaru
   treasury 2026 overlay”, while preserving the raw hash and copy action.
3. **Given** selected books containing many unrelated labels, **when** the
   resolution lenses are evaluated, **then** the Structure resolved count is
   computed only from distinct matched transaction entities and Graph / RDF
   identifies actual transaction matches separately from book-only vocabulary.
4. **Given** an already decoded example, **when** selected books are applied
   again, **then** the resolution remains stable and the full decode operation
   is not invoked again.

## Architectural Invariants

- Resolution remains a generic RDF/SPARQL join. Renderer and fixture-selection
  code MUST NOT branch on Amaru, SundaeSwap, `PaymentKey`, or another protocol
  to decide whether identities match.
- The browser projects the canonical Haskell/WASM `tx.rdf` graph; it MUST NOT
  decode transaction CBOR or invent ledger semantics.
- Raw on-chain identifiers remain visible and copyable after resolution.
- Book selection changes only browser-local RDF overlays and views. It does not
  alter ledger decode semantics or depend on hidden prior calls.
- The generic suffix-match query introduced by #144 remains the source of the
  credential association; this ticket surfaces its result in Structure rather
  than replacing or specializing it.

## Functional Requirements

- **FR-001**: Examples MUST include a bundled owner-key resolution example
  sourced from the existing committed SundaeSwap disbursement fixture.
- **FR-002**: The decoded Structure projection MUST represent each
  `cardano:hasRequiredSigner` target as a child of `required_signers`, using its
  `cardano:bytesHex` value as the raw/copy value and its emitted identifier as
  the entity identity.
- **FR-003**: Structure label lookup MUST consume #144's generic credential
  match result so a generic book credential resolves a type-specific
  transaction credential by hash suffix.
- **FR-004**: A resolved Structure row MUST show the familiar label, an
  RDF-derived type cue when available, and a selected overlay-book source cue.
- **FR-005**: A resolved Structure row MUST keep the raw identifier visible and
  provide its existing copy action.
- **FR-006**: “N identifiers resolved” MUST count distinct transaction entities
  represented in Structure, not labels or vocabulary entries in selected
  books.
- **FR-007**: Graph / RDF MUST visibly distinguish a label attached to a matched
  transaction entity from an unrelated label supplied only by book vocabulary.
- **FR-008**: Re-applying books MUST re-run the RDF/lens path without invoking
  the full `tx.inspect` decode path again.
- **FR-009**: No protocol-specific matching rule or renderer branch may be
  introduced.
- **FR-010**: Existing address resolution and resolved-label behavior MUST
  remain green.

## Committed Demonstration Pair

- **Transaction**:
  `specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex`
  (10,727 bytes of committed hex text; already used by the #144 regression).
- **Book**: bundled “Amaru treasury 2026 overlay”, generated from
  `docs/inspector/protocols/amaru-treasury/journal-2026.json`.
- **Exact proof credential**:
  `8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1`, emitted as
  `urn:cardano:id:PaymentKey:<hex>` and named by the book as “Amaru Network
  Compliance owner key”.
- **Second deterministic match**:
  `f3ab64b0f97dcf0f91232754603283df5d75a1201337432c04d23e2e`, named “Amaru
  Ops And Use Cases owner key”.

## Success Criteria

- **SC-001**: One focused Firefox Playwright scenario proves the exact
  before/after owner-key resolution, raw-value copyability, source/type cues,
  transaction-scoped count, Graph / RDF distinction, and re-query behavior.
- **SC-002**: The focused scenario uses only committed repository data and no
  provider request, external checkout, or runtime network dependency.
- **SC-003**: `nix develop --quiet -c just ci` passes.
- **SC-004**: The UX judge resolution scenario passes with the credential-hash
  example visible from Examples.

## Acceptance Criteria (verbatim from issue #139)

- [ ] A committed transaction/book pair produces at least one deterministic transaction-entity match.
- [ ] Without the book, the tree shows the raw identifier; after applying it, the same row shows familiar label, optional type, and source-book chip.
- [ ] The raw value remains visible or one action away and copyable.
- [ ] “N identifiers resolved” counts transaction entities, not the selected overlay catalog.
- [ ] Graph/RDF distinguishes matched transaction labels from unrelated vocabulary labels in the book.
- [ ] Playwright asserts one exact before/after resolution and proves the result survives re-query without a re-decode.
- [ ] No protocol-specific matching or renderer branch is introduced.
- [ ] `nix develop --quiet -c just ci` and the UX judge resolution scenario pass.

## Non-Goals

- General book authoring (#108), a remote catalog, or book format changes.
- A full credential-battery audit (#145).
- Modifying the generic suffix-match semantics fixed by #144.
- Browser-side CBOR decoding, ledger validation changes, or provider work.
- Byte highlighting or protocol-specific presentation components.
