# Plan

## Context

The merged decode-to-tree work already has a decoded-tree SPARQL layer in `docs/inspector/src/FFI/RdfShapes.js` and a renderer in `docs/inspector/src/Main.purs`. The current state computes resolved-label and SHACL lenses from `mergedRdfTurtle`, but the decoded-tree lens is still computed from the raw transaction RDF. That prevents selected books from affecting the tree.

## Design

Use the same merged graph already used by the overlay lenses as the decoded-tree input. Extend the decoded-tree queries and row construction only where a row has a generic graph identity to resolve:

- preserve the raw transaction value in `raw`;
- show `rdfs:label` / RDF type metadata when present;
- add generic OPTIONAL joins from value nodes, addresses, hashes, datums, redeemers, scripts, and outputs to book-provided labeled entities;
- keep fallback rows unchanged when the optional joins are absent.

No protocol-specific renderer branch is allowed. Book-specific facts must arrive as RDF triples from `OverlayBook` parsing or blueprint application.

## Slice Breakdown

## Slice 1 - Generic Decoded-Tree Resolution

Owned files:

- `docs/inspector/src/Main.purs`
- `docs/inspector/src/FFI/RdfShapes.js`
- `docs/inspector/src/FFI/RdfShapes.purs`
- `docs/inspector/tests/tx-identify.spec.mjs`

Tasks:

- Add a failing Playwright regression proving a selected book resolves a decoded-tree row while the unbooked tree keeps raw fallback.
- Feed the decoded-tree query with merged RDF after selected books are applied.
- Extend the SPARQL/normalization layer generically enough for address/hash/datum/redeemer/output rows to pick up `rdfs:label` and type metadata from the merged graph.
- Preserve raw values in the row data and visible fallback behavior.
- Keep the existing preview subpath test green.

Focused gate:

- `just test-playwright`
- `just build-ui`
- `just format-check`
- `just hlint`
- `just ui-check`

Commit:

- `feat: resolve decoded tree rows from books`
- `Tasks: T1041, T1042`

## Finalization

The ticket orchestrator verifies the slice commit, pushes the draft PR, waits for CI, smokes the PR preview under the non-root `/inspector/` path, then drops `gate.sh` only when ready for epic-owner review.
