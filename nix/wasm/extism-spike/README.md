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
| `extism call` executes the plugin end-to-end | ❌ (wazero, see below) |

## Runtime status

`pkgs.extism-cli` (1.6.3, July 2024) embeds a wazero version that predates
[wazero PR #2403](https://github.com/tetratelabs/wazero/pull/2403)
(merged Aug 2025), which adds wasm tail-call support. GHC 9.12's
`wasm32-wasi` codegen relies on tail calls. Result:

```
hs_init_ghc → initAdjustors → allocHashTable
Error: failed to initialize runtime: wasm error: out of bounds memory access
```

The trap is in the host's wazero, not in the plugin. Direct `wasmtime
--invoke` confirms the plugin imports the standard Extism host functions
(`extism:host/env::input_length`, etc.) — the binary is well-formed.

End-to-end execution requires a Wasmtime-backed host:

- Rust [extism](https://crates.io/crates/extism) (libextism, Wasmtime)
- Haskell [extism](https://hackage.haskell.org/package/extism) (host SDK,
  links libextism)
- A future `extism-cli` release that picks up tail-call-capable wazero

## Next steps

1. Add a native Haskell host program using the `extism` Hackage package
   to load the spike plugin and call `tx_identify`. Run the existing
   `tx-identify-smoke` shape assertions on its output.
2. Promote `tx_identify` to a versioned contract — same export name on
   any future Amaru-PDK plugin.
3. Add `tx_validate` and `apply_tx` exports once the contract shape is
   stable.
