# Implementation Plan: tx-deep-diagnosis Runtime --emit-explain

**Branch**: `009-cli-emit-explain` | **Date**: 2026-05-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-cli-emit-explain/spec.md`

## Status

- **Completed**: Scope selection, code-path audit, shared emitter refactor,
  runtime CLI flag wiring, smoke coverage, and docs update.
- **Current**: Prepare the branch for review and open the issue-63 PR.
- **Blockers**: None.

## Summary

Implement the runtime `--emit-explain` flag that the earlier explain-artifacts
spec promised but the CLI never shipped. The snapshot harness already knows how
to assemble the artifact bundle; this slice moves that orchestration into a
reusable library module so both runtime and tests share one source of truth.

## Technical Context

**Language/Version**: Haskell2010 via the repository's existing GHC/Nix setup

**Primary Dependencies**: existing `tx-deep-diagnosis` renderers,
`optparse-applicative`, `directory`, `filepath`, `text`, Nix smoke checks

**Storage**: None. Pure JSON-to-text rendering plus file emission into a user
supplied output directory.

**Testing**: existing `tx-explain-render-smoke`, new CLI emit-explain smoke,
and `just format-check`

**Constraints**: keep stdout JSON unchanged; preserve deterministic file order;
touch only known artifact files inside the output directory

## Constitution Check

- **Ledger Code Is Authoritative**: PASS. No ledger semantics change.
- **Transaction Documents Own State**: PASS. The CLI emits artifacts from one
  explicit diagnosis envelope.
- **JSON Control Plane, CBOR Data Plane**: PASS. Output remains the same JSON
  envelope plus optional markdown side files.
- **Explicit Context Only**: PASS. No hidden chain state beyond existing CLI
  behavior.
- **The Library Is the Canonical Artifact**: PASS. Shared runtime/test emission
  stays in the host library, not duplicated in executables.
- **Quality Gates**: PASS. Runtime smoke, snapshot smoke, and formatting checks
  gate the change.

## Project Structure

```text
specs/009-cli-emit-explain/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md

apps/tx-deep-diagnosis/app/Main.hs
apps/tx-deep-diagnosis/snapshot/Main.hs
apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Report.hs
apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/
apps/tx-deep-diagnosis/tx-deep-diagnosis.cabal
gh-docs/build.md
flake.nix
```

## Phase Plan

1. Add speckit artifacts for the runtime emit-explain slice.
2. Extract shared explain-artifact rendering/emission into a reusable library
   module and update the snapshot harness to call it.
3. Add `--emit-explain DIR` to `tx-deep-diagnosis`, keeping stdout JSON
   unchanged.
4. Add a CLI smoke check and update docs/help text.

## Post-Design Constitution Check

- **Ledger Code Is Authoritative**: PASS. No ledger-layer drift.
- **Transaction Documents Own State**: PASS. Artifact output is derived from the
  current envelope only.
- **JSON Control Plane, CBOR Data Plane**: PASS. The JSON contract remains
  stable.
- **Explicit Context Only**: PASS. No extra hidden inputs.
- **The Library Is the Canonical Artifact**: PASS. Runtime and test code reuse
  one emitter.
- **Quality Gates**: PASS. Deterministic smoke coverage is added.
