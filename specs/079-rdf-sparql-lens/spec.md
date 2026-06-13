# Feature Specification: RDF SPARQL Lens

As a browser workbench user, I can decode a Conway transaction and see a
client-side named SPARQL lens over the emitted `cardano:` RDF graph, so RDF
composability can be proven in the page before arbitrary user SPARQL, books,
or SHACL validation are added.

## Scope

- Add `lambdasistemi/rdf-shapes-wasm` as a pinned flake input at commit
  `1240e4e58061836264d955b70c49c7195480f3b4`.
- Vendor the input's `packages.${system}.wasm-pkg` output into the inspector
  UI bundle beside the existing WASI inspector artifact.
- Initialize the wasm-bindgen engine synchronously from inlined `.wasm` bytes
  with `initSync`; no runtime network fetch is allowed.
- Add a PureScript FFI boundary for `query(graph_ttl, sparql)`.
- Add one fixed named SPARQL lens panel over the RDF-1 Turtle graph and render
  its result rows.

## Out of Scope

- User-editable SPARQL.
- SHACL validation or `validate(data_ttl, shapes_ttl)` UI.
- RDF books or multi-graph book selection.
- Any ledger semantics outside the existing Haskell/WASI `tx.rdf` emission.

## Functional Requirements

- FR-001: The page MUST load both wasm modules fully client-side: the existing
  WASI inspector and the new wasm-bindgen `rdf-shapes-wasm` engine.
- FR-002: The `rdf-shapes-wasm` `.wasm` MUST be inlined into the bundled
  JavaScript by esbuild; the browser MUST NOT fetch it at runtime.
- FR-003: The lens MUST run a fixed named SPARQL query over the emitted
  `cardano:` Turtle string after a successful decode.
- FR-004: The UI MUST render the named lens title and table rows, and MUST
  surface a concise error if the query engine rejects the graph or query.
- FR-005: Existing inspector operations, RDF graph rendering, and Playwright
  fixture flows MUST remain intact.

## Success Criteria

- `nix build .#tx-inspector-ui` completes with both wasm runtimes embedded.
- `just check-rdf` still proves deterministic `cardano:` Turtle emission.
- `just ui-check` compiles the PureScript workbench.
- `just test-playwright` proves the named SPARQL lens appears and renders rows.
