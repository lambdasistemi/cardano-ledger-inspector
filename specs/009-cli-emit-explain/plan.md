# Implementation Plan: tx-deep-diagnosis Stdout Explain Format

**Branch**: `009-cli-emit-explain` | **Date**: 2026-05-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-cli-emit-explain/spec.md`

## Status

- **Completed**: Shared emitter refactor, optional runtime file emission,
  stdout `--format json|explain` selection, smoke coverage, and doc/spec
  correction.
- **Current**: Refresh the issue/PR copy so the review surface matches the
  corrected stdout-first contract.
- **Blockers**: None.

## Summary

Implement the stdout format switch the CLI actually needs. JSON remains the
default stdout contract, `--format explain` produces the single-file markdown
explanation on stdout, and `--emit-explain` is retained only as optional
side-output for the directory-shaped artifact bundle. The snapshot harness and
runtime continue to share one emitter path so the file outputs do not drift.

## Technical Context

**Language/Version**: Haskell2010 via the repository's existing GHC/Nix setup

**Primary Dependencies**: existing `tx-deep-diagnosis` renderers,
`optparse-applicative`, `directory`, `filepath`, `text`, Nix smoke checks

**Storage**: None. Pure JSON-to-text rendering plus optional file emission into
a user supplied output directory.

**Testing**: existing `tx-explain-render-smoke`, updated CLI explain-format
smoke, and `just format-check`

**Constraints**: preserve existing JSON as the default stdout mode; keep
markdown stdout and file rendering consistent; preserve deterministic file
order; touch only known artifact files inside the output directory

## Constitution Check

- **Ledger Code Is Authoritative**: PASS. No ledger semantics change.
- **Transaction Documents Own State**: PASS. The CLI emits artifacts from one
  explicit diagnosis envelope.
- **JSON Control Plane, CBOR Data Plane**: PASS. JSON remains the default
  machine-readable mode; markdown is an explicit alternate stdout view.
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

1. Add speckit artifacts for the stdout explain slice.
2. Extract shared explain-artifact rendering/emission into a reusable library
   module and update the snapshot harness to call it.
3. Add `--format explain` to `tx-deep-diagnosis`, keeping JSON as the default
   stdout contract.
4. Keep `--emit-explain DIR` only as optional file emission on top of the
   selected stdout format.
5. Add a CLI smoke check and update docs/help text.

## Post-Design Constitution Check

- **Ledger Code Is Authoritative**: PASS. No ledger-layer drift.
- **Transaction Documents Own State**: PASS. Artifact output is derived from the
  current envelope only.
- **JSON Control Plane, CBOR Data Plane**: PASS. The JSON contract remains
  stable and is still the default mode.
- **Explicit Context Only**: PASS. No extra hidden inputs.
- **The Library Is the Canonical Artifact**: PASS. Runtime and test code reuse
  one emitter.
- **Quality Gates**: PASS. Deterministic smoke coverage is added.
