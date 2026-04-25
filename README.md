# cardano-ledger-wasi

Cardano ledger operations compiled to WASI, with a browser transaction
workbench that exercises the same Haskell ledger code.

This repository was split out of
[`lambdasistemi/cardano-node-clients`](https://github.com/lambdasistemi/cardano-node-clients)
so the WASI ledger operation layer can evolve independently from the node-client
library.

## What Is Here

- `nix/wasm/` — reusable Nix machinery for compiling selected Cardano ledger
  Haskell packages to `wasm32-wasi`.
- `nix/wasm/tx-inspector/` — Haskell WASI executable that accepts transaction
  CBOR and ledger operation requests on stdin.
- `docs/inspector/` — PureScript/Halogen browser workbench embedding the WASI
  artifact with `@bjorn3/browser_wasi_shim`.
- `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md` —
  current JSON-control / CBOR-data operation contract.

## Build

```bash
nix build .#packages.x86_64-linux.wasm-tx-inspector
nix build .#packages.x86_64-linux.tx-inspector-ui
```

The built browser bundle is in `./result/{index.html,index.js}` after the UI
build.

## Development

```bash
just --list
just build-wasm
just build-ui
```

The first full WASI ledger build can take a long time because Cabal populates a
fresh dependency cache. Haskell-only edits inside the tx inspector use the
split `prebuiltDeps` path and rebuild much faster after the cache exists.

## Live Preview

Current preview: <https://cardano-tx-inspector.surge.sh>

## License

See `LICENSE`.
