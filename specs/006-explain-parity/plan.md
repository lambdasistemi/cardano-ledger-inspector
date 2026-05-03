# Implementation Plan: Explain Markdown Parity Phase 1

**Branch**: `006-explain-parity` | **Date**: 2026-05-03 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-explain-parity/spec.md`

## Status

- **Completed**: Feature specification, checklist, research, data model,
  quickstart, and task plan are written. `Render.Summary` now renders a
  headline, reader-first failure/balance/resources order, and explicit
  self-declared badges. `Render.Single` now collapses inline Mermaid sections.
  The app README documents the explain artifact contract, the golden snapshots
  were refreshed, `tx-explain-render-smoke` passes, and `just format-check`
  passes.
- **Current**: Prepare the branch for push and PR review without merging.
- **Blockers**: Issue #57-dependent additions remain out of scope for this
  branch. Passing/governance-specific snapshot coverage is still deferred.

## Summary

Tighten the `tx-deep-diagnosis` markdown explain report so its first screen
matches the reader-first patterns seen in mainstream transaction inspectors,
without adding any new ledger fields. The implementation stays in the report
layer: reorder the summary sections, derive a headline from already available
intent data, add a compact fees/resources panel, make self-declared claims
explicitly unverified, collapse Mermaid blocks in the single-file explain
render, and lock the behavior with the existing golden snapshot harness.

## Technical Context

**Language/Version**: Haskell2010 sources compiled via the repo's existing GHC
and Nix setup; markdown output rendered by the native `tx-deep-diagnosis` host

**Primary Dependencies**: `aeson`, `text`, `vector`, existing
`TxDeepDiagnosisHost.Render.*` modules, current `cardano-ledger-inspector`
intent/validate envelope fields, Nix flake checks

**Storage**: None. The feature is a pure transformation from an existing
diagnosis JSON envelope to markdown text.

**Testing**: Golden snapshot verification through
`tx-deep-diagnosis-render-snapshot` and
`checks.x86_64-linux.tx-explain-render-smoke`, plus `just format-check`

**Target Platform**: Single-file and directory-shaped markdown explain artifacts
emitted by the native `tx-deep-diagnosis` CLI and reviewed on GitHub

**Project Type**: Native Haskell CLI/report renderer with pure text artifacts
and snapshot-based regression coverage

**Performance Goals**: Keep rendering deterministic and pure; no new network
calls, no new ledger execution, and no measurable slowdown beyond a small
amount of extra text formatting

**Constraints**: Use only fields already present on current `main`; preserve the
directory-shaped artifacts; keep markdown diffs reviewable; do not reimplement
ledger semantics or add hidden state

**Scale/Scope**: One explain report per diagnosis document, initially verified
against the existing invalid golden fixture; the branch targets issue #58 items
`A1` to `A5` plus `C3`, and explicitly excludes issue #57-dependent additions

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Ledger Code Is Authoritative**: PASS. No new ledger behavior is introduced;
  the feature only re-renders already produced intent/validate output.
- **Transaction Documents Own State**: PASS. Rendering remains a pure function
  of one diagnosis JSON envelope with no cross-call state.
- **JSON Control Plane, CBOR Data Plane**: PASS. The report consumes existing
  JSON summaries and does not alter transaction or datum CBOR authority.
- **Explicit Context Only**: PASS. The branch does not fetch or infer new chain
  state; it only presents what the current envelope already says.
- **The Library Is the Canonical Artifact**: PASS. The host renderer remains a
  consumer of library output rather than a new ledger interpreter.
- **Quality Gates**: PASS. The change is designed around deterministic snapshot
  regression tests and limited documentation updates before any UI divergence.

## Project Structure

### Documentation (this feature)

```text
specs/006-explain-parity/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── tasks.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
apps/tx-deep-diagnosis/
├── src/TxDeepDiagnosisHost/Render/
│   ├── Single.hs
│   └── Summary.hs
├── snapshot/Main.hs
├── test/golden/value-not-conserved/
│   ├── input.json
│   └── expected/
│       ├── explain.md
│       └── summary.md
└── README.md

flake.nix
README.md
```

**Structure Decision**: Keep the implementation entirely inside the
`tx-deep-diagnosis` host renderer and its snapshot fixtures. No library schema
changes or browser code changes are needed for this first parity branch.

## Phase Plan

1. **Reader-first summary layout**: Refactor `Render.Summary` so the headline,
   verdict, failure summary, balance, and fees/resources appear before lower-
   priority narrative sections.
2. **Truth labeling**: Add explicit self-declared badges to metadata-derived
   destinations and claims without weakening the distinction between registry-
   resolved evidence and metadata assertions.
3. **Single-file readability**: Wrap inline Mermaid sections in collapsed
   details blocks in `Render.Single` while keeping the same underlying content.
4. **Contract hardening**: Update the golden fixtures, add app-level explain
   report docs, and verify the branch with the dedicated snapshot smoke plus
   formatting checks.

## Post-Design Constitution Check

- **Ledger Code Is Authoritative**: PASS. The branch changes only wording,
  ordering, and visibility controls in the renderer.
- **Transaction Documents Own State**: PASS. The rendered headline/resources
  summary is computed from the current envelope only.
- **JSON Control Plane, CBOR Data Plane**: PASS. New text uses existing JSON
  fields such as `claims`, `fee_lovelace`, `tx_size_bytes`, and per-redeemer
  committed ex-units.
- **Explicit Context Only**: PASS. No new external context is introduced.
- **The Library Is the Canonical Artifact**: PASS. The host report remains a
  consumer of existing library output.
- **Quality Gates**: PASS. Snapshot smoke and formatting checks are sufficient
  for this renderer-only branch.

## Complexity Tracking

No constitution violations or complexity exceptions are required.
