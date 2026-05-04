# Implementation Plan: Formalize tx.intent Scripts Detail

**Branch**: `012-intent-scripts-contract` | **Date**: 2026-05-04 | **Spec**: [spec.md](./spec.md)

## Status

- **Completed**: issue-57 worktree creation, baseline `tx-intent-smoke`, drift
  confirmation against the live `scripts[]` payload.
- **Current**: formalize the existing redeemer surface in schema/docs and bind
  it to a smoke assertion.
- **Blockers**: none.

## Summary

`tx.intent` already emits `scripts[]`, and the explain renderer already renders
it as `## Smart-contract calls`. The missing work is contractual:
`tx-intent-result.schema.json` does not describe `scripts[]`, and the
ledger-functional API example/prose does not show the field. This slice adds
the contract surface and tightens the smoke check around the existing Conway
fixture's minting redeemer.

## Technical Context

**Language/Version**: Haskell + Nix  
**Primary Dependencies**: Aeson schemas/docs, flake smoke checks  
**Storage**: none  
**Testing**: `tx-intent-smoke`, OpenAPI check, format check  
**Target Platform**: existing WASI/CLI build graph  
**Project Type**: Haskell library + WASI host tooling

## Constitution Check

- The change is spec-driven and scoped to a single vertical slice.
- No new runtime behavior is invented; the slice documents and verifies existing
  behavior.
- Verification is local and explicit.

## Research

See [research.md](./research.md).

## Design

See [data-model.md](./data-model.md).

## Implementation Phases

1. Extend `tx-intent-result.schema.json` with `scripts[]` and its supporting
   definitions.
2. Update `ledger-functional-api.md` with a representative `scripts[]` example
   and field notes.
3. Regenerate OpenAPI and copy the artifact only if it materially changes.
4. Strengthen `tx-intent-smoke` against the existing minting redeemer fixture.
5. Re-run verification and open the PR.
