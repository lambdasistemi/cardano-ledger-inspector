# Implementation Plan: Export the protocol registry as a reusable flake output

## Tech stack

Nix (flake-parts, nixpkgs `runCommand`), the existing haskell.nix
`tx-deep-diagnosis` exe component (`nix/host/tx-deep-diagnosis-native`),
`docs/inspector/protocols` as the unchanged source of truth.

## Approach

`docs/inspector/protocols` is already cabal's `data-dir` target for
`tx-deep-diagnosis` (`apps/tx-deep-diagnosis/tx-deep-diagnosis.cabal`); the
CLI only bundles the files it lists under `data-files`, not the whole tree.
The flake output packages the whole tree directly from the same source path
(`./docs/inspector/protocols`), so it can never structurally diverge except
if someone edits the copy step itself — which the drift check catches.

Two additions to `flake.nix`, no other files touched:

1. `protocolRegistry` — a `pkgs.runCommand` derivation that copies
   `./docs/inspector/protocols` verbatim into `$out`, exposed as
   `packages.<system>.protocol-registry`.
2. `protocol-registry-drift-check` — a `pkgs.runCommand` check that locates
   `tx-deep-diagnosis`'s built-in data directory via the haskell.nix
   `.data` derivation output (`hostTargets.tx-deep-diagnosis.data`), and for
   every file the CLI actually bundles, asserts it exists at the same
   relative path under `protocolRegistry` with identical bytes (`cmp -s`).
   Exposed as `checks.<system>.protocol-registry-drift-check`.

No new flake inputs. No changes to `apps/tx-deep-diagnosis/*.cabal`,
`nix/host/*`, or any UI code.

## Slices

### Slice 1 — `protocol-registry` package + drift check (T149)

- Add `protocolRegistry` binding and wire it as `packages.protocol-registry`.
- Add `protocol-registry-drift-check` binding and wire it into `checks`.
- Proof: `nix build .#protocol-registry` succeeds and matches
  `docs/inspector/protocols` by diff; `nix build
  .#checks.x86_64-linux.protocol-registry-drift-check` succeeds; a
  deliberately corrupted `protocolRegistry` (manual local edit, reverted)
  makes the drift check fail closed; `tx-deep-diagnosis`'s existing checks
  (`tx-explain-render-smoke`, `tx-deep-diagnosis-emit-explain-smoke`) and the
  `tx-deep-diagnosis` package itself still build to the same unaffected
  output paths.

One slice — this is a single bisect-safe commit.
