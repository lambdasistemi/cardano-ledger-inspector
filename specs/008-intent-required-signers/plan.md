# Implementation Plan: tx.intent Required Signer Coverage

**Branch**: `008-intent-required-signers` | **Date**: 2026-05-03 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/008-intent-required-signers/spec.md`

## Status

- **Completed**: Scope selection, code-path audit, `tx.intent.signing`
  expansion, contract/schema updates, golden refresh, and verification.
- **Current**: Prepare the branch for review and open the issue-57 follow-up
  PR.
- **Blockers**: None.

## Summary

Implement the required-signer coverage slice of issue #57. The repo already
knows the declared required signers and the present witness sets in
`tx.witness.plan`, but `tx.intent` only exposes missing signer hashes and
counts. This branch adds the full declared signer list plus witness coverage to
`tx.intent.signing`, documents the contract change, and surfaces a generic
`Declared required signers` table in the markdown report.

## Technical Context

**Language/Version**: Haskell2010 via the repository's existing GHC/Nix setup

**Primary Dependencies**: `aeson`, `text`, `containers`, existing
`tx.intent` / `tx.witness.plan` helpers, `tx-deep-diagnosis` generic section
renderer, Nix/OpenAPI checks

**Storage**: None. This is a pure transaction-to-JSON and JSON-to-markdown
transformation.

**Testing**: `tx-intent-smoke`, `tx-explain-render-smoke`,
`ledger-functional-openapi-check`, and `just format-check`

**Constraints**: Keep the output deterministic; preserve compatibility with
older diagnosis envelopes; reuse existing generic section/table shapes where
possible

## Constitution Check

- **Ledger Code Is Authoritative**: PASS. Required signer and witness data come
  directly from the decoded transaction body and witness set.
- **Transaction Documents Own State**: PASS. No cross-call or cached authority.
- **JSON Control Plane, CBOR Data Plane**: PASS. The change adds JSON views over
  already-decoded signer and witness data.
- **Explicit Context Only**: PASS. No extra provider or chain state.
- **The Library Is the Canonical Artifact**: PASS. The renderer follows library
  output.
- **Quality Gates**: PASS. Contract docs, snapshots, and checks are updated
  together.

## Project Structure

```text
specs/008-intent-required-signers/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md

libs/cardano-ledger-inspector/src/Conway/Inspector.hs
apps/tx-deep-diagnosis/test/golden/value-not-conserved/
specs/001-ledger-functional-layer/{contracts,schemas,openapi}/
nix/ledger-functional-openapi.nix
flake.nix
```

## Phase Plan

1. Extend `tx.intent.signing` to emit the full required signer arrays and
   witness coverage.
2. Add a generic `Declared required signers` section row set to `intent.sections`.
3. Update the contract docs, stored diagnosis input, and golden markdown.
4. Verify smoke, snapshot, OpenAPI, and formatting checks.

## Post-Design Constitution Check

- **Ledger Code Is Authoritative**: PASS. Signer coverage is derived entirely
  from the decoded tx body and witness set.
- **Transaction Documents Own State**: PASS. Pure deterministic transformation.
- **JSON Control Plane, CBOR Data Plane**: PASS. The signer arrays are JSON
  views, not new canonical data.
- **Explicit Context Only**: PASS. No hidden context.
- **The Library Is the Canonical Artifact**: PASS. Report changes remain driven
  by library output.
- **Quality Gates**: PASS. This branch is bounded by existing deterministic
  checks.
