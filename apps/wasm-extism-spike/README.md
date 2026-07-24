# Extism PDK spike

Proof-of-concept: package ledger operations as
[Extism](https://extism.org) plugin exports instead of the WASI reactor
used by `wasm-tx-inspector`. The motivation is language-agnostic
conformance testing — a Rust ledger (Amaru) packaged as an Extism plugin
with the same export names + byte contract can be diff-tested against
this Haskell ledger by feeding identical inputs to both.

## What's here

- `wasm-extism-spike/` — Haskell package depending on `extism-pdk` and
  the inspector library. The foreign exports — `tx_identify`,
  `tx_intent`, `tx_review`, `tx_validate`, and `tx_evaluate_scripts` — all
  delegate to the local wrapper's `runLedgerOperationInput`. The Extism
  response is therefore byte-identical to the WASI reactor's response on the
  same input, which is exactly what conformance vs another implementation
  needs.
- `cabal-wasm.project` — same fork overrides as `tx-inspector` plus
  `allow-newer` punches for `extism-pdk` / `extism-manifest` /
  `messagepack` / `json` against bytestring/containers/binary. Lists
  both `.` (this package) and `../../libs/cardano-ledger-inspector`
  as path packages.

## Build

```bash
just build-extism-spike
just check-extism-spike
```

`check-extism-spike` runs `tx_identify`, `tx_intent`, `tx_review`,
`tx_validate`, and `tx_evaluate_scripts` against canonical Conway fixtures.
Registered and unknown-script `tx.intent` and `tx.review` requests are compared
**byte-for-byte** across the WASI reactor, native wrapper runner, and Extism
plugin, with semantic assertions for typed metadata, registered
datum/redeemer/deployment meaning, and unknown raw fallback.

## Spike outcome

| Hypothesis | Result |
|---|---|
| `extism-pdk` co-exists with the Conway closure under `wasm32-wasi-ghc 9.12` | ✅ |
| Cabal solver accepts the combined dep set at the inspector's index-state | ✅ |
| Resulting `.wasm` is a valid Extism plugin shape (named exports + WASI) | ✅ |
| Plugin runs end-to-end (libextism + Wasmtime, `tx_identify`, `tx_intent`, `tx_review`, `tx_validate`, and `tx_evaluate_scripts`) | ✅ |
| Registered and unknown-script `tx.intent` responses are byte-identical across WASI, native, and Extism | ✅ |
| Registered and unknown-registry `tx.review` responses are byte-identical across WASI, native, and Extism | ✅ |
| Plugin runs through `pkgs.extism-cli` (Go, wazero) | ❌ (see below) |

## Two host paths — only one currently works

**Works: native Haskell host (`nix/host/extism-spike-host`).**
Uses the [`extism`](https://hackage.haskell.org/package/extism) Hackage
package, which links libextism (Rust + Wasmtime). libextism is fetched
prebuilt from the upstream release in `nix/host/libextism.nix`. This is
the production conformance-harness path. Invocation:

```
extism-spike-host PATH-TO-WASM [FUNCTION] < envelope.json > response.json
```

`FUNCTION` defaults to `tx_identify`; pass `tx_validate` or
`tx_intent` or `tx_review` or `tx_evaluate_scripts` for the other implemented
operations. The envelope is the same JSON the WASI reactor accepts on stdin.

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

1. Promote the current operation exports to a versioned contract — same
   export names on any future Amaru-PDK plugin.
2. Add `apply_tx` once the contract shape is stable.
3. Build the diff harness: same fixture vector → both plugins → byte
   compare on serialized output.
