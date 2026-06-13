# Tasks: RDF-4 blueprint books

## Slice 1 - WASI Blueprint Decode

- [ ] T081-S1 Extend `tx.rdf`/`tx.graph` request parsing to accept optional
  selected blueprint book JSON in `args.blueprints[]`.
- [ ] T081-S1 Parse CIP-57 JSON through `Cardano.Tx.Blueprint`, derive the
  script-hash blueprint index from validator `hash` fields, and pass it to
  `Cardano.Tx.Graph.Emit.emit`.
- [ ] T081-S1 Preserve existing no-blueprint RDF output and malformed-blueprint
  failures as `malformed_ledger_operation` diagnostics.
- [ ] T081-S1 Extend the RDF result schema and `tx-rdf-smoke` with
  no-blueprint selectivity and bundled SundaeSwap blueprint typed-field
  assertions.
- [ ] T081-S1 Run `just check-rdf` and `./gate.sh`.
- [ ] T081-S1 Commit as `feat: decode rdf blueprint books in wasi`.

## Slice 2 - Browser Books UX And Typed Lens

- [ ] T081-S2 Extend the RDF-3 Books import model so pasted/bundled CIP-57
  `plutus.json` imports as selectable blueprint parts while overlay Turtle
  behavior remains unchanged.
- [ ] T081-S2 Add a bundled SundaeSwap V3 blueprint book action sourced from
  `docs/inspector/protocols/sundaeswap-v3/plutus.json`.
- [ ] T081-S2 Send selected blueprint parts to `tx.rdf`, expose an apply/re-run
  state transition for current transaction CBOR, and preserve selectivity for
  unselected blueprints.
- [ ] T081-S2 Add a named SPARQL typed-fields lens and render decoded contract
  field rows from the returned Turtle.
- [ ] T081-S2 Extend Playwright coverage for import/select/apply, typed field
  rendering/queryability, and deselect/reapply removal.
- [ ] T081-S2 Run `nix develop --quiet -c just ui-check`,
  `nix develop --quiet -c just test-playwright`, and `./gate.sh`.
- [ ] T081-S2 Commit as `feat: render rdf blueprint book fields`.

