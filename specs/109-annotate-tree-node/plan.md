# Plan

## Context

#102 renders the decoded RDF tree from `docs/inspector/src/FFI/RdfShapes.js`. #104 resolves decoded-tree rows by matching local book labels against identifier predicates such as `cardano:bech32`, `cardano:bytesHex`, `cardano:fromTxOutRef`, and `cardano:hasRawBytes`. #106 stores parsed books in `localStorage`, exports/imports that store, and wires selected books into the inspect page's merge path.

#109 should use those merged paths rather than inventing new resolution rules. The only new behavior is authoring a valid local book entry from a concrete decoded-tree node.

## Design

- Extend decoded-tree row data enough for annotation targets. The UI needs the display row plus the canonical identifier predicate/value to emit Turtle. Prefer deriving this in `RdfShapes.js`, where the SPARQL bindings already know bech32, bytes hex, UTxO references, and raw bytes.
- Keep predicate inference generic and data-driven by row kind and available RDF bindings. Do not branch on a protocol, contract, address, or fixture-specific value.
- Add a small book-authoring helper around the existing store shape. It should produce a parseable overlay Turtle fragment and append it to either:
  - a chosen existing local book, or
  - a new selected local book created inline.
- The generated book source remains ordinary Turtle. Existing export/import and selected-book merge logic should not need a parallel path.
- Use `ApplySelectedBooks`-equivalent lens recomputation after saving so the selected book merge is visible immediately.
- Keep the UI compact inside each decoded-tree row. A button opens inline controls/dialog state; it must not push rows into unstable widths on mobile.

## Slice 1 - Decoded-Tree Annotation Flow

Implement the full vertical path in one bisect-safe commit.

Owned files:
- `docs/inspector/src/Main.purs`
- `docs/inspector/src/FFI/RdfShapes.js`
- `docs/inspector/src/FFI/RdfShapes.purs`
- `docs/inspector/src/FFI/BookStore.js`
- `docs/inspector/src/FFI/BookStore.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

Expected behavior:
- A supported opaque decoded-tree row exposes `Label this as...`.
- The flow can append to an existing selected book and can create a new selected local book inline.
- Generated Turtle parses via the existing overlay book parser and carries a label plus inferred identifier predicate.
- Saving updates `localStorage`, visible book summary data, and decoded-tree resolution immediately.
- Export/import round-trip preserves the annotation.
- Subpath navigation/deep-link/refresh coverage remains green.

## Finalization

After the slice lands, run the full gate locally. The PR stays draft until CI, preview publication, and browser smoke at the preview URL are verified.
