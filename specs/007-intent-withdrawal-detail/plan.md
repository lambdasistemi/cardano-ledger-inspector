# Implementation Plan: tx.intent Withdrawal Detail

**Branch**: `feat/txintent-information-audit-fields-decoded-by-the-l` | **Date**: 2026-05-03 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/007-intent-withdrawal-detail/spec.md`

## Status

- **Completed**: Scope selection, library helpers, `tx.intent.withdrawals[]`,
  contract/schema/OpenAPI updates, markdown renderer updates, golden refresh,
  and verification (`tx-intent-smoke`, `tx-explain-render-smoke`,
  `ledger-functional-openapi-check`, `just format-check`).
- **Current**: Prepare the branch for commit, push, and PR review.
- **Blockers**: None.

## Summary

Implement the withdrawal-detail slice of issue #57. The ledger already decodes
withdrawals from the transaction body, but `tx.intent` currently collapses them
to `withdrawal_count`. This branch surfaces one structured row per withdrawal,
documents the contract change, and renders the rows in `tx-deep-diagnosis`
alongside more specific rewarding-script targets.

## Technical Context

**Language/Version**: Haskell2010 via the repository's existing GHC/Nix setup

**Primary Dependencies**: `aeson`, `bytestring`, `text`, `containers`,
`cardano-ledger-api`, existing `tx.intent` / `tx-deep-diagnosis` modules

**Storage**: None. This is a pure transaction-to-JSON and JSON-to-markdown
transformation.

**Testing**: `tx-intent-smoke`, `tx-explain-render-smoke`,
`ledger-functional-openapi-check`, and `just format-check`

**Target Platform**: WASI `tx.intent` responses plus the native
`tx-deep-diagnosis` renderer

**Project Type**: Haskell ledger library plus native renderer/contract docs

**Constraints**: Keep the change deterministic; preserve backward-compatible
renderer behavior for diagnosis envelopes that predate `withdrawals[]`; update
contract docs in the same PR

## Constitution Check

- **Ledger Code Is Authoritative**: PASS. Withdrawal rows come directly from the
  decoded ledger body.
- **Transaction Documents Own State**: PASS. The result is computed from the
  supplied transaction/document only.
- **JSON Control Plane, CBOR Data Plane**: PASS. The change adds JSON view data
  over already-decoded ledger withdrawals.
- **Explicit Context Only**: PASS. No hidden provider or chain state is added.
- **The Library Is the Canonical Artifact**: PASS. The renderer remains a
  consumer of library output.
- **Quality Gates**: PASS. The branch updates schema/docs and verifies smoke
  checks plus formatting.

## Project Structure

```text
specs/007-intent-withdrawal-detail/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md

libs/cardano-ledger-inspector/src/Conway/
├── Inspector.hs
└── Inspector/Common.hs

apps/tx-deep-diagnosis/
├── src/TxDeepDiagnosisHost/Render/Summary.hs
├── test/golden/value-not-conserved/
│   ├── input.json
│   └── expected/{summary.md,explain.md}
└── README.md

specs/001-ledger-functional-layer/
├── contracts/ledger-functional-api.md
├── schemas/tx-intent-result.schema.json
└── openapi/cardano-ledger-functional.openapi.json

nix/ledger-functional-openapi.nix
```

## Phase Plan

1. Add shared withdrawal JSON helpers in the inspector library and emit
   `intent.withdrawals[]`.
2. Update the schema, contract markdown, and OpenAPI example to describe the
   new shape.
3. Teach the renderer to show structured withdrawals and refine rewarding
   script targets.
4. Refresh the golden diagnosis input/output and verify with smoke checks.

## Post-Design Constitution Check

- **Ledger Code Is Authoritative**: PASS. The new rows are still direct ledger
  projections.
- **Transaction Documents Own State**: PASS. No new mutable state or caching.
- **JSON Control Plane, CBOR Data Plane**: PASS. `reward_account_hex` is a
  machine-readable address view over ledger data, not a canonical replacement
  for CBOR.
- **Explicit Context Only**: PASS. Withdrawals come from the tx body alone.
- **The Library Is the Canonical Artifact**: PASS. Contract and renderer follow
  the library output.
- **Quality Gates**: PASS. The branch carries schema, OpenAPI, snapshot, and
  smoke verification together.
