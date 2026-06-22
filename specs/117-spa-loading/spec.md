# Issue 117: SPA Loading

## User Story

As a browser workbench user, I want the inspector SPA to fetch its large wasm
modules as cacheable assets instead of embedded JavaScript bytes, so route
loads, repeat visits, and transaction decode startup are not dominated by a
10 MB JavaScript bundle.

## Requirements

- Stop inlining the Haskell inspector wasm and RDF shapes wasm into
  `index.js`.
- Emit `inspector.wasm` and `rdf_shapes_wasm_bg.wasm` as separate hashed
  assets shared by `/`, `/inspect`, `/settings`, and `/library`.
- Load the inspector wasm with streaming instantiate/compile where the server
  supports `application/wasm`, with a fallback for servers that do not.
- Load the RDF shapes wasm asynchronously instead of constructing a synchronous
  `WebAssembly.Module` from embedded bytes.
- Precompress emitted HTML, JavaScript, CSS, and wasm assets with gzip-9 and
  brotli at build time.
- Configure the nginx PR preview to serve static gzip/brotli assets and cache
  hashed assets immutably.
- Document that GitHub Pages still provides the de-inline, streaming, and
  cacheability wins, while brotli/static-precompressed serving is only fully
  available on the nginx preview host.

## Acceptance

- `index.js` no longer contains embedded wasm bytes, and per-route copies no
  longer duplicate the 10 MB wasm payload.
- The packaged UI contains one shared hashed inspector wasm asset and one
  shared hashed RDF shapes wasm asset.
- Playwright observes the wasm assets fetched over HTTP with 200 responses
  while decode and RDF/SPARQL flows still pass.
- The non-root subpath test covers direct load, refresh, and navigation for
  `/inspect`, `/settings`, and `/library`.
- `nix build .#packages.x86_64-linux.tx-inspector-ui`, Haskell format/lint,
  and Playwright pass locally before push.
- The draft PR remains draft until local acceptance, CI, preview publish, and
  browser smoke are verified.
