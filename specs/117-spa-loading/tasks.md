# Tasks

## Slice 1 - Split And Stream Wasm Assets

- [X] T117-S1 Add RED Playwright coverage proving wasm is fetched as separate
  HTTP assets and decode/RDF still work under a non-root subpath.
- [X] T117-S1 Change the UI bootstrap and Nix esbuild packaging to emit hashed
  `inspector.wasm` and `rdf_shapes_wasm_bg.wasm` assets instead of embedding
  wasm bytes in `index.js`.
- [X] T117-S1 Stream instantiate/compile the inspector wasm and asynchronously
  initialize RDF shapes wasm with a non-streaming fallback.
- [X] T117-S1 Add gzip-9 and brotli precompression for emitted browser assets.
- [X] T117-S1 Update preview/pages workflows and docs so package assertions
  require `.gz`/`.br` wasm siblings while live gzip/brotli/cache serving is
  treated as shared-host infrastructure.
- [X] T117-S1 Run `./gate.sh`, commit one bisect-safe slice, and stop before
  push.

## Finalization

- [X] T117-F1 Orchestrator review: verify diff scope, commit trailer, worker
  RED/GREEN protocol, local gate, and task amendment.
- [X] T117-F2 Push branch and keep a draft PR linked to #117.
- [X] T117-F3 Verify CI, preview publish, browser smoke, and non-blocking live
  preview compression/cache notes before reporting COMPLETE.
