# Feature Specification: Export the protocol registry as a reusable flake output

**Feature Branch**: `feat/149-protocol-registry-flake-output`
**Created**: 2026-07-14
**Status**: Ready for implementation
**Input**: GitHub issue #149, "Export the protocol registry as a reusable
flake output". Child of epic lambdasistemi/cardano-swiss-knife#20.

## User Scenarios & Testing

### User Story 1 — Build the registry as a standalone flake output (Priority: P1)

As a downstream consumer, I `nix build .#protocol-registry` and observe a
derivation containing the complete protocols registry, byte-identical to
what tx-deep-diagnosis bundles.

**Why this priority**: The registry today is only reachable by vendoring
the CLI (via cabal `data-dir`) or by hand-copying `docs/inspector/protocols`.
An external consumer (the csk workbench, epic child #17) needs it as a flake
input without vendoring the CLI or the source tree.

**Independent Test**: `nix build .#protocol-registry --print-out-paths`
succeeds and the output tree matches `docs/inspector/protocols` file for
file.

**Acceptance Scenarios**:

1. **Given** the flake at this branch, **when** `nix build
   .#protocol-registry` runs, **then** the derivation exists and contains
   every file under `docs/inspector/protocols` (registry.json, per-protocol
   pin/plutus/journal files, `cardano-rdf/shapes.ttl`, docs).
2. **Given** the existing `tx-deep-diagnosis` package (cabal `data-dir:
   ../../docs/inspector/protocols`), **when** its checks
   (`tx-explain-render-smoke`, `tx-deep-diagnosis-emit-explain-smoke`) build,
   **then** they pass unchanged — the CLI's data-dir bundling is untouched.
3. **Given** a future edit that makes the CLI's bundled data and
   `packages.protocol-registry` diverge (content or presence), **when** the
   `protocol-registry-drift-check` flake check builds, **then** it fails
   closed with a diagnostic naming the drifted file.

## Non-goals

- No registry relocation out of the repo.
- No CLI flag or behavior changes.
- No UI changes.

## Pinned decision

The flake output name is exactly `packages.<system>.protocol-registry`
(epic-owner pinned; child #17 in cardano-swiss-knife consumes this name).
