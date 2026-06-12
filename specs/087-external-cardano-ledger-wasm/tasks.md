# W2 Tasks

## Slice 1 - external pin and WASM builder source

- [x] T087-S1 Add the pinned `cardano-ledger-wasm` SRP to `cabal.project` with nix32 hash.
- [x] T087-S1 Add the pinned flake input and lock it at the same revision.
- [x] T087-S1 Rewire `flake.nix` to consume the external `lib.wasm` export.
- [x] T087-S1 Delete local `nix/wasm/forks.json` and `nix/wasm/mkCardanoLedgerWasm.nix`.
- [x] T087-S1 Add or extend a drift check for Cabal pin, Nix pin, and external fork metadata.
- [x] T087-S1 Run focused Nix evaluation/build proof and commit one bisect-safe slice.

## Slice 2 - consumer retargeting and local kernel removal

- [x] T087-S2 Retarget local Haskell packages to depend on `cardano-ledger-wasm` for the ledger kernel modules.
- [x] T087-S2 Remove the inspector-owned `Conway.Inspector` implementation as a behavior source.
- [x] T087-S2 Keep `wasm-tx-inspector`, `tx-deep-diagnosis`, and Extism entry points behavior-compatible.
- [x] T087-S2 Run focused Cabal/Nix build proof and commit one bisect-safe slice.

## Slice 3 - runtime fixture proof and final gate

- [x] T087-S3 Run fixture smokes for WASI, Extism, and native diagnosis against the external kernel.
- [x] T087-S3 Extend `gate.sh` only for missing required runtime proof.
- [x] T087-S3 Run the full gate, update PR metadata, and prepare for final review.
