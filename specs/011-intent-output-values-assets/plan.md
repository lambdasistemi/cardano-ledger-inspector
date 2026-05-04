# Implementation Plan: Formalize tx.intent Output Rows and Asset Detail

**Branch**: `011-intent-output-values-assets` | **Date**: 2026-05-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/011-intent-output-values-assets/spec.md`

## Status

- **Completed**: issue-57 worktree setup, baseline `tx-intent-smoke`, and
  discovery that `value.outputs[]` already exists in the live implementation.
- **Current**: encode that output row in the public contract and use it in the
  renderer.
- **Blockers**: None.

## Summary

This slice fixes contract drift around `tx.intent.value.outputs[]`. The live
implementation already returns per-output address, lovelace, assets, and datum,
but the public schema/docs do not describe it and the markdown Outputs table
does not show assets. The implementation will formalize the row shape in the
schema/docs/OpenAPI, extend `tx-intent-smoke` to assert output-level assets on
the existing Conway fixture, and add an Assets column to the report table.

## Technical Context

**Language/Version**: Haskell2010 plus JSON/OpenAPI artifacts via the existing
Nix generation flow

**Primary Dependencies**: existing `tx.intent` implementation in
`libs/cardano-ledger-inspector`, `tx-deep-diagnosis` summary renderer, committed
JSON schema, generated OpenAPI, and Nix smoke checks

**Storage**: committed schema/docs/OpenAPI files and markdown goldens

**Testing**: `tx-intent-smoke`, `tx-explain-render-smoke`, `just format-check`,
and `ledger-functional-openapi-check`

**Constraints**: preserve existing wire values; avoid inventing semantics that
the live JSON does not already carry; keep asset previews deterministic

## Constitution Check

- **Ledger Code Is Authoritative**: PASS. No new ledger decoding logic needed.
- **Transaction Documents Own State**: PASS. Renderer output is derived from the
  existing response document.
- **JSON Control Plane, CBOR Data Plane**: PASS. This slice strengthens the
  JSON contract without changing CBOR fidelity.
- **Explicit Context Only**: PASS. No provider or chain lookups added.
- **The Library Is the Canonical Artifact**: PASS. We are documenting and
  rendering fields the library already emits.
- **Quality Gates**: PASS. Smoke, OpenAPI, render smoke, and format-check cover
  the slice.

## Project Structure

```text
specs/011-intent-output-values-assets/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md

apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs
apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/summary.md
apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/explain.md
flake.nix
specs/001-ledger-functional-layer/contracts/ledger-functional-api.md
specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json
specs/001-ledger-functional-layer/schemas/tx-intent-result.schema.json
```

## Phase Plan

1. Add the speckit slice documenting the contract drift and the chosen scope.
2. Extend the `tx.intent` schema/docs/OpenAPI to describe `value.outputs[]`.
3. Strengthen `tx-intent-smoke` with output-row and non-empty-asset assertions.
4. Add an Assets column to the markdown Outputs table and refresh goldens.
5. Re-run the contract, renderer, and format gates.

## Post-Design Constitution Check

- **Ledger Code Is Authoritative**: PASS.
- **Transaction Documents Own State**: PASS.
- **JSON Control Plane, CBOR Data Plane**: PASS.
- **Explicit Context Only**: PASS.
- **The Library Is the Canonical Artifact**: PASS.
- **Quality Gates**: PASS.
