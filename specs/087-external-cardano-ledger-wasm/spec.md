# W2: Inspector consumes external cardano-ledger-wasm

## User Story

As a Cardano ledger inspector maintainer, I want this repository to consume
the external `lambdasistemi/cardano-ledger-wasm` kernel as the single source
of truth, so the inspector, native diagnosis CLI, and Extism spike cannot
drift from the shared WASM ledger kernel or its wasm-specific dependency
forks.

## Functional Requirements

- FR-001: `cabal.project` must pin
  `https://github.com/lambdasistemi/cardano-ledger-wasm` at
  `d7b2b2c7317e42d590826f3d70f8d07158408992` using nix32
  `--sha256: 1278gxgq64y5sgzhfj8an2fvxz7xp0plwv0qxky4wgws961442l5`.
- FR-002: the flake must consume the external `cardano-ledger-wasm` flake's
  exported WASM builder and fork metadata instead of importing the inspector's
  local `nix/wasm` builder/fork source.
- FR-003: the inspector must not retain its own
  `nix/wasm/forks.json` or `nix/wasm/mkCardanoLedgerWasm.nix`.
- FR-004: `wasm-tx-inspector`, `tx-deep-diagnosis`, and the Extism spike must
  link the external kernel through the stable module paths kept by W1.
- FR-005: the existing fixture-driven smoke checks must pass against the pinned
  external kernel with byte-identical behavior.
- FR-006: if both Cabal and Nix carry the `cardano-ledger-wasm` pin, a local
  drift check must fail when the Cabal pin, Nix input, or external fork metadata
  disagree.

## Acceptance

- The PR builds from the external kernel and no longer carries the local ledger
  operation implementation as the behavior source.
- The local WASM builder/fork machinery is removed or unreachable; fork data
  comes from the external flake.
- The existing `just test` smoke path, including fixture checks under
  `specs/001-ledger-functional-layer/fixtures`, passes.
- The external Plutus fork pin is explicitly verified as part of the gate; any
  mismatch is reported as a blocking drift failure, not silently accepted.
