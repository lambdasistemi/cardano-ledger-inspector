# Plan

## Scope

This is a browser packaging and loading change. Conway ledger semantics,
operation envelopes, provider adapters, and PureScript application state stay
unchanged.

## Implementation Shape

- Update `docs/inspector/src/bootstrap.js` to import wasm URLs emitted by
  esbuild's file loader, resolve them against `document.baseURI`, and use
  `WebAssembly.instantiateStreaming` / `compileStreaming` with an
  `arrayBuffer` fallback.
- Initialize `rdf_shapes_wasm.js` asynchronously from the emitted RDF shapes
  wasm URL. If the wasm-bindgen generated module does not expose an async init
  shape compatible with the current package, adapt only the bootstrap glue and
  keep the public `globalThis.rdfShapes` API stable for PureScript FFI.
- Update `nix/wasm-ui.nix` to use esbuild's wasm file loader, hashed asset
  names, public-path-safe relative URLs, one shared asset copy in the package
  root, and gzip/brotli precompression.
- Update the Pages and PR preview packaging only where needed to preserve the
  `/inspector/` deployment shape, assert `.gz`/`.br` siblings for both wasm
  assets in the package, and document the host compression/cache limits.
- Add or extend Playwright coverage to assert separate wasm asset fetches,
  non-root subpath routing, decode, and RDF/SPARQL behavior.
- Keep live preview smoke strict for the host-independent wasm asset contract:
  the hashed wasm URL exists, returns HTTP 200, and serves
  `Content-Type: application/wasm`.
- Treat live brotli/gzip_static serving and immutable cache headers as
  external shared-host infrastructure. Preview probes may report advisory
  warnings, but they are not a #117 completion gate.

## Slices

### Slice 1: Split And Stream Wasm Assets

Driver and cross-checker own one vertical slice:

- `docs/inspector/src/bootstrap.js`
- `docs/inspector/tests/tx-identify.spec.mjs`
- `nix/wasm-ui.nix`
- `.github/workflows/pages.yml`
- `.github/workflows/pr-preview.yml`
- `gh-docs/installation.md`
- `gh-docs/architecture.md`

Expected proof:

- RED Playwright assertion fails against the current inline wasm build because
  no separate wasm asset is fetched.
- GREEN emits hashed wasm assets, streams/falls back correctly, and passes the
  decode plus RDF/SPARQL assertions under a non-root subpath. The package also
  contains `.gz` and `.br` siblings for both wasm assets.
- `./gate.sh` passes before the driver commits.
- The commit body contains `Tasks: T117-S1`.

## Finalization

The ticket orchestrator reviews the implementation commit, verifies the worker
protocol, reruns the gate, amends task checkboxes into the same commit, pushes
the draft PR, verifies CI and preview smoke, then reports `COMPLETE` only with
PR, SHA, and preview evidence.
