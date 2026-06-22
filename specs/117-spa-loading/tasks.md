# Tasks

## Slice 1 - Split And Stream Wasm Assets

- [ ] T117-S1 Add RED Playwright coverage proving wasm is fetched as separate
  HTTP assets and decode/RDF still work under a non-root subpath.
- [ ] T117-S1 Change the UI bootstrap and Nix esbuild packaging to emit hashed
  `inspector.wasm` and `rdf_shapes_wasm_bg.wasm` assets instead of embedding
  wasm bytes in `index.js`.
- [ ] T117-S1 Stream instantiate/compile the inspector wasm and asynchronously
  initialize RDF shapes wasm with a non-streaming fallback.
- [ ] T117-S1 Add gzip-9 and brotli precompression for emitted browser assets.
- [ ] T117-S1 Update preview serving/workflow/docs for static gzip/brotli,
  immutable hashed assets, and GitHub Pages compression limits.
- [ ] T117-S1 Run `./gate.sh`, commit one bisect-safe slice, and stop before
  push.

## Finalization

- [ ] T117-F1 Orchestrator review: verify diff scope, commit trailer, worker
  RED/GREEN protocol, local gate, and task amendment.
- [ ] T117-F2 Push branch and keep a draft PR linked to #117.
- [ ] T117-F3 Verify CI, preview publish, live preview brotli/static gzip, and
  browser smoke before reporting COMPLETE.
