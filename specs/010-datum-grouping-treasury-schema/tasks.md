# Tasks: Datum Grouping and Explicit Amaru Treasury Schema

**Input**: Design documents from
`/specs/010-datum-grouping-treasury-schema/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: Included because this slice changes user-visible markdown output and
must keep the committed render goldens stable.

## Phase 1: Renderer grouping

- [X] T001 Change the Datums-section grouping key in `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs` from `cbor` to `(cbor, destination)`
- [X] T002 Keep datum-block titles and schema provenance bound to the
      representative chosen for that full grouping key in
      `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs`

## Phase 2: Registry provenance

- [X] T003 Add an explicit datum schema to the Amaru treasury `instances[]`
      entry in `docs/inspector/protocols/registry.json`
- [X] T004 Mark that treasury schema with manual provenance that states the
      pinned upstream treasury validator does not expose a typed datum source

## Phase 3: Goldens and verification

- [X] T005 Refresh
      `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/summary.md`
- [X] T006 Refresh
      `apps/tx-deep-diagnosis/test/golden/value-not-conserved/expected/explain.md`
- [X] T007 Run `nix build .#checks.x86_64-linux.tx-explain-render-smoke`
- [X] T008 Run `just format-check`
