# Implementation Plan: RDF SPARQL Lens

## Technical Shape

The existing browser workbench already embeds the Haskell WASI reactor through
`docs/inspector/src/bootstrap.js` and calls `tx.rdf` after decode. This ticket
adds the Rust wasm-bindgen runtime from `rdf-shapes-wasm` alongside it:

1. Add the flake input and pass `rdfShapesWasm.packages.${system}.wasm-pkg` to
   `nix/wasm-ui.nix`.
2. Copy `rdf_shapes_wasm.js` and `rdf_shapes_wasm_bg.wasm` into
   `docs/inspector/src/assets` during the UI Nix build.
3. Bundle `rdf_shapes_wasm_bg.wasm` with esbuild's `--loader:.wasm=binary` and
   call `initSync({ module: new WebAssembly.Module(wasmBytes) })`.
4. Expose `globalThis.rdfShapes.query(graphTtl, sparql)` through a small
   PureScript FFI module.
5. After `tx.rdf` succeeds, run one fixed named SPARQL query over the Turtle
   and store normalized rows in UI state.
6. Render a compact lens panel adjacent to the RDF graph panel and assert it
   with Playwright.

This repo does not have a `just ci` recipe; the local ticket gate uses the
actual repo recipes that cover this change: `just build-ui`, `just check-rdf`,
`just ui-check`, and `just test-playwright`.

## Slice 1 - Vendored Query Engine

Owned by driver/navigator. Add the pinned flake input, wire the wasm-pkg into
the UI derivation, initialize the wasm-bindgen bundle in `bootstrap.js`, and
add a thin query FFI.

Focused proof:

```bash
nix develop --quiet -c just build-ui
nix develop --quiet -c just ui-check
```

## Slice 2 - Named SPARQL Lens UI

Owned by driver/navigator. Run a fixed named query over the RDF-1 Turtle graph,
normalize its rows, render them, and extend Playwright coverage.

Focused proof:

```bash
nix develop --quiet -c just check-rdf
nix develop --quiet -c just test-playwright
./gate.sh
```
