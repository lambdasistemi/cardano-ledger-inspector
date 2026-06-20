# Annotate Decoded-Tree Nodes Into Local Books

## User Story

As a transaction inspector user who recognizes an opaque decoded-tree value, I want to label that node in the app so that the label is saved into a local book, applied immediately, and exportable without hand-writing Turtle.

## Scope

- Add a per-node `Label this as...` affordance to opaque decoded-tree leaves.
- Let the user enter a label, choose an existing local book, or create a new local book inline.
- Infer the RDF identifier predicate from the decoded-tree row kind, using the predicates already matched by `docs/inspector/src/FFI/RdfShapes.js`.
- Append guaranteed-valid Turtle to the target local book with `rdfs:label`, the inferred `cardano:` identifier predicate, and optional `a <type>`.
- Save through the existing #106 local book store and keep export/import round-trip behavior intact.
- Recompute the RDF lenses immediately so the annotated node renders as resolved without requiring a manual `Apply selected books` click or reload.

## Functional Requirements

- FR-001 Opaque decoded-tree rows for supported node kinds expose `Label this as...`; already-resolved rows and non-identifier scalar rows do not need the affordance.
- FR-002 Supported identifier mappings include at least:
  - address rows -> `cardano:bech32` using the bech32 address from RDF, while preserving the current raw hex display fallback.
  - script-hash, policy, datum hash, verification-key-like hash rows -> `cardano:bytesHex`.
  - input/UTxO reference rows -> `cardano:fromTxOutRef`.
  - datum raw bytes rows -> `cardano:hasRawBytes`.
- FR-003 The annotation flow rejects empty labels and unsupported/empty identifiers before saving.
- FR-004 The generated Turtle contains stable prefixes for `cardano:`, `rdfs:`, and a local namespace, and parses through the existing overlay-book parser.
- FR-005 Appending to an existing book preserves its prior source text, parts, selected state, and export shape.
- FR-006 Creating a new book inline creates a selected, non-seed local book in the same store envelope used by `/library`.
- FR-007 After save, the decoded tree re-runs against the merged graph and the annotated node renders the new label immediately.
- FR-008 Export selected/all books and JSON import retain the generated annotation.
- FR-009 Existing `/inspect`, `/settings`, and `/library` routes continue to navigate, refresh, and deep-link under a non-root deployment prefix.

## Non-Goals

- Standalone manual book authoring forms in `/library`; that is a separate #108 child.
- User-authored arbitrary Turtle editing in the annotation dialog.
- New RDF vocabulary, resolver semantics, or protocol-specific labels.
- Backend persistence or remote book publishing.

## Acceptance

- A Playwright flow decodes a genuine fixture, labels an opaque decoded-tree address row, observes the row resolve immediately, exports the book, imports it into a clean context, and observes the label resolve again.
- The flow also proves inline new-book creation or selected-book append, whichever is not covered by the first path.
- The non-root subpath Playwright coverage still asserts navigation, refresh, and fixture decode under the preview-style prefix.
- `nix build .#packages.x86_64-linux.tx-inspector-ui`, format check, hlint, and Playwright are green locally.
