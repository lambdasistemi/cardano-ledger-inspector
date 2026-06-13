# Feature Specification: RDF-3 overlay books

**Issue**: cardano-ledger-inspector#80
**Branch**: feat/rdf-overlay-books
**Status**: Draft

## User Story

As a browser workbench user inspecting a Conway transaction, I can import a
local overlay book, select which overlay parts to merge, and see resolved human
labels for transaction entities without uploading anything or relying on a
server-side join.

## Functional Requirements

- **FR-001**: The workbench exposes a Books panel after a valid transaction RDF
  graph is available.
- **FR-002**: A book import accepts pasted Turtle and a paste/file shape derived
  from `docs/inspector/protocols/amaru-treasury/journal-2026.json`.
- **FR-003**: The Amaru treasury journal is reframed as a bundled overlay book
  in the repository, emitted as Turtle keyed by canonical Cardano IRIs.
- **FR-004**: The user can select individual overlay parts before merge. An
  unselected part contributes no triples to the resolved graph and no rows to
  the resolved-labels lens.
- **FR-005**: Merging is plain RDF union by IRI. The implementation must not
  special-case the transaction JSON or manually join labels outside SPARQL.
- **FR-006**: A named resolved-labels lens runs through
  `rdf-shapes-wasm query()` over the merged Turtle and renders label, role,
  identifier, and matched entity rows.
- **FR-007**: The feature stays fully client-side. Imported data is held in page
  state/local browser controls only; there is no upload path.
- **FR-008**: Existing transaction RDF graph rendering and the RDF-2 transaction
  outputs lens continue to work.

## Acceptance Criteria

- Importing the bundled Amaru overlay and selecting one scope/role part merges
  that part into the in-page `cardano:` graph and renders its resolved label.
- Deselecting that part removes its labels from the merged graph and from the
  resolved-labels lens.
- The resolved-labels lens is a SPARQL query over Turtle, joining by canonical
  IRIs and `cardano:bech32` / `cardano:fromTxOutRef` / identifier predicates
  where present.
- `nix develop --quiet -c just check-rdf`,
  `nix develop --quiet -c just ui-check`, `just build-ui`, and
  `nix develop --quiet -c just test-playwright` pass.

## Out Of Scope

- Blueprint books, CIP-57 datum/redeemer decoding, and SHACL validation.
- Book signing, distribution trust roots, remote catalogs, and upload/sync.
- Raw arbitrary SPARQL editing in the UI.
