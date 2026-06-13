# Feature Specification: RDF-4 blueprint books

**Branch**: feat/rdf-blueprint-books
**Issue**: lambdasistemi/cardano-ledger-inspector#81

## User Story

As a browser workbench user inspecting a Conway transaction, I can import a
CIP-57 Plutus blueprint book, select the blueprint parts I want applied, and
see matching script datums/redeemers rendered as typed `cardano:` RDF fields
instead of only opaque CBOR/raw bytes.

## Functional Requirements

- **FR-001**: The WASI `tx.rdf`/`tx.graph` operation MUST accept optional
  blueprint books in `args` and preserve the current byte-stable output when no
  blueprint is selected.
- **FR-002**: A blueprint book is a CIP-57 `plutus.json` asset. The initial
  bundled example is `docs/inspector/protocols/sundaeswap-v3/plutus.json`.
- **FR-003**: WASI MUST parse each selected blueprint JSON through
  `tx-rdf-core`'s `Cardano.Tx.Blueprint.parseBlueprintJSON`, derive the
  script-hash index from validator `hash` fields, and pass the index to
  `Cardano.Tx.Graph.Emit.emit`.
- **FR-004**: Matching datums and redeemers MUST emit typed RDF predicates
  produced by `tx-rdf-core`'s blueprint decoder. Non-matching scripts and
  unselected blueprints MUST retain the existing opaque/raw RDF shape.
- **FR-005**: The browser Books UX MUST reuse RDF-3 import/select mechanics for
  blueprint books, expose the bundled SundaeSwap V3 blueprint, and apply only
  selected blueprint parts to the next RDF decode.
- **FR-006**: The browser MUST render decoded typed contract fields and expose
  them to the existing RDF-2 SPARQL lens engine.
- **FR-007**: Blueprint decoding remains fully client-side: browser state,
  the local WASI artifact, and the vendored blueprint asset are sufficient.
- **FR-008**: SHACL validation, remote catalogs, book signing, and registry
  trust roots are out of scope for this ticket.

## Success Criteria

- Importing/selecting the bundled SundaeSwap V3 blueprint and applying it to a
  matching fixture transaction renders typed order field rows in the browser.
- A SPARQL query over the returned Turtle can select at least one typed
  contract field predicate/value from the decoded datum or redeemer.
- Deselecting the blueprint and reapplying RDF removes the typed field rows.
- `just check-rdf`, `just ui-check`, `just test-playwright`, and `./gate.sh`
  pass locally before push.
- The PR is not marked complete until GitHub Build Gate CI is green.

