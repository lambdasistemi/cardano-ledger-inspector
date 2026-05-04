# Implementation Plan: Datum Grouping and Explicit Amaru Treasury Schema

**Branch**: `010-datum-grouping-treasury-schema` | **Date**: 2026-05-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/010-datum-grouping-treasury-schema/spec.md`

## Status

- **Completed**: Issue analysis, upstream treasury-source check, baseline
  `tx-explain-render-smoke`.
- **Current**: Add the issue-66 docs, fix the datum grouping key, vendor the
  explicit treasury instance schema, and refresh the goldens.
- **Blockers**: None. The design correction is already resolved: upstream
  treasury datum provenance must be manual, not Aiken-derived.

## Summary

Fix the Datums section so identical inline datum bytes only collapse when they
also share the same destination label, then make the Amaru treasury output use
an explicit instance-level datum schema. The schema will intentionally use the
existing manual-provenance path because the pinned upstream treasury validator
accepts opaque `Data` and does not define the typed datum requested in the
issue body.

## Technical Context

**Language/Version**: Haskell2010 via the repository's existing GHC/Nix setup

**Primary Dependencies**: existing `tx-deep-diagnosis` summary/single-file
renderers, registry loader, `aeson`, `text`, committed protocol registry JSON

**Storage**: none beyond the committed `registry.json` and golden markdown
fixtures

**Testing**: `tx-explain-render-smoke` and `just format-check`

**Constraints**: keep renderer behavior deterministic; preserve the existing
order-schema rendering; disclose manual provenance truthfully; do not claim an
upstream typed treasury datum that does not exist in the pinned source

## Constitution Check

- **Ledger Code Is Authoritative**: PASS. No ledger decoding/validation logic
  changes.
- **Transaction Documents Own State**: PASS. The change only affects rendering
  of the existing diagnosis envelope and the vendored registry.
- **JSON Control Plane, CBOR Data Plane**: PASS. No JSON-envelope changes.
- **Explicit Context Only**: PASS. No hidden provider state or chain fetches.
- **The Library Is the Canonical Artifact**: PASS. The behavior stays in the
  host renderer and registry layer.
- **Quality Gates**: PASS. Golden-render smoke plus formatting will verify the
  slice.

## Project Structure

```text
specs/010-datum-grouping-treasury-schema/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── tasks.md

apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs
apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/summary.md
apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/explain.md
docs/inspector/protocols/registry.json
```

## Phase Plan

1. Add the speckit slice documenting the issue-66 design correction.
2. Change the Datums-section grouping key from `cbor` to
   `(cbor, destination_label)`.
3. Vendor an explicit instance-level schema on the Amaru treasury instance
   using `manual` provenance.
4. Re-render the golden markdown outputs and verify the renderer smoke and
   formatting gates.

## Post-Design Constitution Check

- **Ledger Code Is Authoritative**: PASS. Renderer-only change.
- **Transaction Documents Own State**: PASS. Datums are still derived solely
  from the envelope.
- **JSON Control Plane, CBOR Data Plane**: PASS. No contract drift.
- **Explicit Context Only**: PASS. Registry data remains explicit and committed.
- **The Library Is the Canonical Artifact**: PASS. No duplicated logic.
- **Quality Gates**: PASS. Existing Nix smoke and formatting checks remain the
  relevant proof points.
