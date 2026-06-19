# Issue 104: Book Resolution In The Decoded Tree

## User Story

As a Cardano transaction investigator, I want imported books that are merged into the transaction RDF graph to resolve opaque decoded-tree nodes, so script hashes, addresses, datum/redeemer data, and related entities become familiar names or typed fields without protocol-specific renderer code.

## Functional Requirements

- FR1: The decoded-structure tree must query the transaction graph after selected overlay/blueprint book triples are merged.
- FR2: Any tree row whose backing graph entity has `rdfs:label` must surface that label in the row metadata while preserving the raw value.
- FR3: Address, datum, redeemer, script/hash, policy, and output leaves must remain raw when no loaded book provides matching triples.
- FR4: Resolution must be generic over RDF triples in the merged graph. The renderer must not hardcode Amaru, SundaeSwap, or other protocol-specific matching rules.
- FR5: At least one representative book must demonstrate that a previously opaque decoded-tree node resolves after the book is selected and applied.
- FR6: The browser test suite must include a Playwright regression that loads a book, applies it, and asserts a decoded-tree row displays the resolved familiar value.
- FR7: Existing subpath routing and refresh behavior must remain covered by Playwright.

## Non-Goals

- Local book persistence, import/export library UX, and catalog backends.
- Byte-to-node highlighting.
- Raw-CBOR mode.
- Protocol-specific renderer branches.

## Acceptance

- Without selected books, the decoded tree shows raw fallback values.
- With a representative book selected and applied, a previously opaque decoded-tree node shows a familiar label or typed field from merged triples.
- `just build-ui`, `just format-check`, `just hlint`, `just ui-check`, and `just test-playwright` pass locally.
- Preview is published and browser-smoked under `/lambdasistemi/cardano-ledger-inspector/pr-<N>/inspector/`.
