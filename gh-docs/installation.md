# Installation

## Release artifacts

Tagged releases are produced by
[release-please](https://github.com/googleapis/release-please) from
conventional-commit history. Each release attaches:

| Asset | Contents |
| --- | --- |
| `cardano-ledger-reference-<tag>.wasm` | Extism plugin exposing `tx_identify`, `tx_intent`, `tx_validate`, and `tx_evaluate_scripts`. Its `tx_intent` bytes are checked against both the WASI reactor and native wrapper for registered and unknown scripts. Load it with any Wasmtime-backed [Extism host SDK](https://extism.org/docs/concepts/host-sdk). The Go SDK does not work yet because its bundled wazero predates wasm tail-call support. |
| `wasm-tx-inspector-<tag>.wasm` | The same Conway ledger packaged as a WASI reactor (stdin/stdout JSON), for shell-driven debugging and external hosts such as cardano-swiss-knife. |
| `ledger-functional-openapi-<tag>.tar.gz` | OpenAPI contract for the JSON envelope. |
| `SHA256SUMS-<tag>.txt` | Checksums for the assets above. |

Download from
[the releases page](https://github.com/lambdasistemi/cardano-ledger-inspector/releases).

## Build with Nix

All artifacts are flake outputs and can be built without a checkout:

```bash
nix build github:lambdasistemi/cardano-ledger-inspector#packages.x86_64-linux.wasm-tx-inspector
nix build github:lambdasistemi/cardano-ledger-inspector#packages.x86_64-linux.protocol-registry
nix build github:lambdasistemi/cardano-ledger-inspector#packages.x86_64-linux.tx-deep-diagnosis
```

The native CLI also runs directly; its protocol registry is bundled into
the binary, so no checkout is needed:

```bash
nix run github:lambdasistemi/cardano-ledger-inspector#tx-deep-diagnosis -- \
  --cbor my-tx.hex --format explain
```

Flake outputs are exposed for `x86_64-linux` and `aarch64-darwin`; CI
exercises the Linux outputs.

## CI artifacts (per-run, ephemeral)

Every `CI` workflow run uploads `wasm-tx-inspector` and
`ledger-functional-openapi` artifacts (each with `SHA256SUMS`) retained
for 30 days. Use these for inspecting a specific PR; use a tagged release
for anything you depend on. See
[CI workflow runs](https://github.com/lambdasistemi/cardano-ledger-inspector/actions/workflows/ci.yml).

## Browser workbench

The browser product needs no installation and lives in cardano-swiss-knife:

<https://lambdasistemi.github.io/cardano-swiss-knife/>

It consumes this repository's `wasm-tx-inspector` and
`protocol-registry` flake outputs. The former inspector URL in this
repository redirects to that workbench.
