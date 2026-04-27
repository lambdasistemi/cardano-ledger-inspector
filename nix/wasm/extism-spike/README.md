# Extism PDK spike

Proof-of-concept: package one ledger operation (Conway tx → small
identification JSON) as an [Extism](https://extism.org) plugin instead of
the WASI reactor used by `wasm-tx-inspector`. The motivation is
language-agnostic conformance testing — a Rust ledger (Amaru) packaged as
an Extism plugin with the same export names + byte contract can be
diff-tested against this Haskell ledger by feeding identical inputs to
both.

## What's here

- `wasm-extism-spike/` — Haskell package depending on `extism-pdk` and the
  Conway ledger libs. Single foreign export: `tx_identify`.
- `cabal-wasm.project` — same fork overrides as `tx-inspector` plus
  `allow-newer` punches for `extism-pdk` / `extism-manifest` /
  `messagepack` / `json` against bytestring/containers/binary.

## Build

```bash
just build-extism-spike
just check-extism-spike
```

The check is **structural**: it asserts `tx_identify` and `hs_init` are
exported and the wasm module is valid. End-to-end runtime invocation is
deliberately not part of the smoke (see "Runtime status" below).

## Spike outcome

| Hypothesis | Result |
|---|---|
| `extism-pdk` co-exists with the Conway closure under `wasm32-wasi-ghc 9.12` | ✅ |
| Cabal solver accepts the combined dep set at the inspector's index-state | ✅ |
| Resulting `.wasm` is a valid Extism plugin shape (named exports + WASI) | ✅ |
| Plugin runs end-to-end against real Conway fixture (libextism + Wasmtime) | ✅ |
| Plugin runs through `pkgs.extism-cli` (Go, wazero) | ❌ (see below) |

End-to-end response on the canonical Conway fixture:

```json
{"era":"Conway","fee_lovelace":"319463","input_count":1,"output_count":5,
 "tx_id":"2e614d78...49da6f3","tx_size_bytes":1918}
```

## Two host paths — only one currently works

**Works: native Haskell host (`nix/host/extism-spike-host`).**
Uses the [`extism`](https://hackage.haskell.org/package/extism) Hackage
package, which links libextism (Rust + Wasmtime). libextism is fetched
prebuilt from the upstream release in `nix/host/libextism.nix`. This is
the production conformance-harness path. Run with
`just check-extism-spike`.

**Blocked: `pkgs.extism-cli` (Go, wazero).** Version 1.6.3 (July 2024)
embeds a wazero that predates
[wazero PR #2403](https://github.com/tetratelabs/wazero/pull/2403)
(Aug 2025), which added wasm tail-call support. GHC 9.12's wasm32-wasi
codegen relies on tail calls, so `extism call` traps in wazero during
GHC RTS init:

```
hs_init_ghc → initAdjustors → allocHashTable
Error: failed to initialize runtime: wasm error: out of bounds memory access
```

The trap is in the host's wazero, not in the plugin — same `.wasm`
runs fine under Wasmtime via the Haskell host. A future `extism-cli`
release that picks up tail-call-capable wazero will work without
plugin changes.

## Next steps

1. Promote `tx_identify` to a versioned contract — same export name on
   any future Amaru-PDK plugin.
2. Add `tx_validate` and `apply_tx` exports once the contract shape is
   stable.
3. Build the diff harness: same fixture vector → both plugins → byte
   compare on serialized output.
