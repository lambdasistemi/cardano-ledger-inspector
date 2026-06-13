# Feature Specification: RDF Transaction Graph

## User Story

As a browser workbench user, I can decode a Conway transaction and inspect the canonical `cardano:` RDF graph emitted from the same WASI ledger artifact, so the RDF composability epic has an end-to-end browser baseline before books or SPARQL are added.

## Scope

- Add the pinned `tx-rdf-core` dependency from `lambdasistemi/cardano-ledger-rdf` commit `6769e28535aafee20743710ebdff53e652e8a22b`, subdir `tx-rdf-core`, with nix32 hash `0m1yj9cdzdh1bcrz1wn5d34fw8y6rh7gl624qh5h3idyni8jdqnw`.
- Expose a new ledger operation accepted as `tx.rdf` and `tx.graph`.
- The operation decodes the supplied transaction CBOR and returns deterministic Turtle using the `cardano:` vocabulary.
- The browser workbench renders the emitted Turtle for a pasted or fetched transaction.

## Out Of Scope

- RDF books.
- SPARQL querying.
- External provider fetches for referenced producer transactions.
- Replacing existing inspect, identify, intent, witness, validate, or evaluate operations.

## Functional Requirements

- FR-001: `tx.rdf` and `tx.graph` MUST use the same JSON stdin/stdout envelope convention as the existing WASI ledger operations.
- FR-002: The emitted result MUST include raw Turtle text under a stable JSON field that the browser can render directly.
- FR-003: The operation MUST decode the supplied transaction bytes through the ledger/RDF Haskell path, not through browser-side JSON transforms.
- FR-004: The Turtle output MUST be deterministic for `specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex`.
- FR-005: The UI MUST call the new operation during decode and render the Turtle when the WASI operation succeeds.
- FR-006: Existing operations and UI panels MUST continue to work.

## Acceptance

- `just check-rdf` proves the fixture transaction emits deterministic Turtle containing `@prefix cardano:` and transaction graph content.
- `just build-wasm`, `just ui-check`, and the local gate pass.
- Browser Playwright coverage confirms the RDF graph panel appears for the fixture.
