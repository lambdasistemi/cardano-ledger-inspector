# Tasks: RDF SPARQL Lens

## Slice 1 - Vendored Query Engine

- [ ] T079-S1 Add the pinned `rdf-shapes-wasm` flake input and lock update.
- [ ] T079-S1 Pass `wasm-pkg` into the UI derivation and copy the wasm-bindgen bundle into `src/assets`.
- [ ] T079-S1 Initialize `rdf-shapes-wasm` with inlined bytes in `bootstrap.js`.
- [ ] T079-S1 Add the PureScript/JavaScript FFI for `query(graph_ttl, sparql)`.
- [ ] T079-S1 Run `nix develop --quiet -c just build-ui` and `nix develop --quiet -c just ui-check`.
- [ ] T079-S1 Commit as `feat: vendor rdf shapes wasm query engine`.

## Slice 2 - Named SPARQL Lens UI

- [ ] T079-S2 Add fixed named lens state, query invocation, normalization, and error handling.
- [ ] T079-S2 Render the SPARQL lens panel with result rows over the RDF graph.
- [ ] T079-S2 Extend Playwright coverage proving the fixed lens renders rows after fixture decode.
- [ ] T079-S2 Run `nix develop --quiet -c just check-rdf`, `nix develop --quiet -c just test-playwright`, and `./gate.sh`.
- [ ] T079-S2 Commit as `feat: render rdf sparql lens`.
