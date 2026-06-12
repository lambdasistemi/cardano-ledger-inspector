# W2 Plan

## Scope

Move `cardano-ledger-inspector` onto
`lambdasistemi/cardano-ledger-wasm` at
`d7b2b2c7317e42d590826f3d70f8d07158408992`. The external repository owns the
ledger kernel and exported `lib.wasm` builder/fork metadata; this repository
keeps the app surfaces, browser workbench, native diagnosis CLI, Extism host,
fixtures, OpenAPI, and user-facing documentation.

## Slice 1 - external pin and WASM builder source

Add the external flake input and Cabal `source-repository-package` pin using
the computed nix32 hash. Rewire `flake.nix` so `self.lib.wasm` delegates to
`cardanoLedgerWasm.lib.wasm`, update `nix/wasm-targets.nix` only as needed,
remove the local builder/fork files, and add a drift check that compares:

- Cabal SRP location/tag/sha256.
- Nix flake input revision.
- External `cardanoLedgerWasm.lib.wasm.forks.pins.plutus` against the expected
  W2 fork pin.

This slice may update `flake.lock` and `gate.sh` to include the new check.

## Slice 2 - consumer retargeting and local kernel removal

Retarget the local Haskell packages so `wasm-tx-inspector`,
`tx-deep-diagnosis`, and `wasm-extism-spike` depend on
`cardano-ledger-wasm` for the `Conway.Inspector` module family. Remove the
local ledger operation modules from `libs/cardano-ledger-inspector` or reduce
the local package to a non-kernel app wrapper if Cabal structure requires it.
The native and WASM entry points must keep their public CLI/JSON behavior.

## Slice 3 - runtime fixture proof and final gate

Run the fixture smokes against the pinned external kernel, including
`wasm-tx-inspector`, Extism conformance, and native diagnosis checks. Extend
the gate only if the existing gate misses a required runtime fixture proof.
Update PR metadata, mark all tasks done, and leave the PR ready for final
review once the gate is green.

## Risk Notes

- The external flake currently exports the same `lib.wasm` API shape as the
  local inspector builder, so the Nix wiring should be a small import/input
  change.
- If the external fork metadata does not carry the expected W2 Plutus fork,
  the drift check must fail loudly and the driver should park with a Q-file
  instead of weakening the acceptance criteria.
- `source-repository-package` hashes must stay nix32; SRI format is rejected
  because haskell.nix fetchgit fixed-output derivations have failed with SRI
  in this workflow.
