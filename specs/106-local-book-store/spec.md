# Local Book Store + Export/Import

## User Story

As a Cardano transaction inspector user, I want to keep my own RDF,
blueprint, and SHACL books in the browser so that selecting them in the
library resolves decoded transaction trees without repasting the same
book material every session.

## Functional Requirements

- FR-001 `/library` lists the local book store from `localStorage`.
- FR-002 On first run, the store is seeded with the bundled Amaru overlay,
  SundaeSwap V3 blueprint, and Cardano RDF SHACL books as removable entries.
- FR-003 Users can add a book from pasted text, a file, or a URL.
- FR-004 Imported text is parsed with the existing `OverlayBook.parse`
  path and stores the parsed book plus the original source text required
  for export/import round-trips.
- FR-005 Users can rename, delete, and select/deselect each book for merge.
- FR-006 Store changes persist across reloads.
- FR-007 Users can export all books or selected books to a JSON file.
- FR-008 Users can import that JSON file and recover the exported books and
  selected state.
- FR-009 The inspect page Books panel reads from the local store, not from
  hardcoded load buttons.
- FR-010 Selected store books merge into the RDF graph and resolve decoded
  tree rows through the #104 resolution path.
- FR-011 Subpath deployment keeps `/inspect`, `/settings`, and `/library`
  navigation, refresh, and deep links working under a non-root prefix.

## Non-Goals

- Backend catalog of famous books.
- Raw-CBOR mode.
- Byte-to-node highlighting.
- New ledger or RDF semantics outside the existing overlay/blueprint/SHACL
  parsing and merge behavior.

## Acceptance

- `/library` supports add, select, rename, delete, export, and import.
- Exported store JSON imports into a clean browser context with the same
  book names and selections.
- A store-selected book resolves at least one decoded-tree node on a
  genuine fixture transaction.
- `nix build .#packages.x86_64-linux.tx-inspector-ui`, format/hlint, and
  Playwright are green locally.
- PR preview is published and browser-smoked under
  `/lambdasistemi/cardano-ledger-inspector/pr-<N>/inspector/`.
