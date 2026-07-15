# Tasks: Transaction-scoped Structure resolution demo

**Input**: [spec.md](spec.md), [plan.md](plan.md)
**Gate**: focused Firefox Playwright + `./gate.sh`; final `nix develop --quiet -c just ci`
**Implementation strategy**: two vertical, independently testable,
bisect-safe slices executed by fresh driver+navigator pairs.

## Slice 1 — Bundled credential-resolution journey

**Goal**: Make one real required-signer credential visibly resolve in
Structure from the bundled Amaru book while preserving raw identity and
proving transaction scope across Structure and Graph / RDF.

**Independent proof**: The focused Playwright journey starts without the book,
loads the bundled example, observes the raw signer, applies the book, and
asserts the exact label/type/source/raw/copy/count and Graph / RDF distinction
without a second full decode.

- [X] T001-S1 [US1] Add a failing `transaction-scoped owner-key resolution`
  Playwright journey to `docs/inspector/tests/tx-identify.spec.mjs` covering the
  exact before/after Network Compliance signer, copyability, count, Graph / RDF
  match/vocabulary cues, provider silence, and no repeat `tx.inspect` call.
- [X] T002-S1 [US1] Extend `tools/gen-broken-examples.py` with the existing
  committed SundaeSwap disbursement fixture as the “Amaru owner-key
  resolution” example and regenerate `docs/inspector/src/Examples.purs`.
- [X] T003-S1 [US1] In `docs/inspector/src/FFI/RdfShapes.js`, project
  `cardano:hasRequiredSigner` entities into the decoded tree and map #144's
  existing explicit generic suffix matches onto their concrete transaction
  identities without changing the suffix-query semantics.
- [X] T004-S1 [US1] Extend
  `docs/inspector/src/FFI/RdfShapes.purs` and
  `docs/inspector/src/Main.purs` so Structure renders RDF type and selected
  overlay source, counts distinct resolved transaction entities, preserves raw
  copy controls, and Graph / RDF distinguishes transaction matches from
  book-only vocabulary.
- [X] T005-S1 [US1] Run the focused journey on an isolated
  `PLAYWRIGHT_PORT`, the existing generic hex-suffix and address-resolution
  regressions, and `./gate.sh`; verify `gate.sh`, the transaction fixture, the
  Amaru journal, and overlay Turtle are unchanged from `origin/main`.
- [X] T006-S1 [US1] Commit one bisect-safe change as
  `feat(inspector): demonstrate credential resolution in Structure` with
  `Tasks: T001, T002, T003, T004, T005, T006`, then stop without pushing.

## Slice 2 — UX-judge resolution capture

**Goal**: Make the accepted credential-hash journey a repeatable UX-judge
scenario at desktop, laptop, and mobile widths.

**Independent proof**: Against PR #156's packaged preview, the capture manifest
contains successful `04-resolution` entries for all three viewports; each
image visibly contains the resolved required-signer label and the judge/report
pipeline emits parsed resolution scores for those entries.

- [X] T007-S2 [US1] Run the existing UX capture against the PR preview and
  record RED because no `04-resolution` scenario exists; add the scenario to
  `tools/ux-judge/capture.mjs`, reusing the exact “Amaru owner-key resolution”
  example and waiting for “Amaru Network Compliance owner key” on a resolved
  required-signer Structure row before each screenshot.
- [X] T008-S2 [US1] Keep the three existing capture journeys green, run the
  capture/judge/report pipeline at all configured viewports, verify every
  capture succeeds, verify each resolution judgment parses with a non-null
  resolution score, and verify the aggregate report lists all three resolution
  screenshots. Remove generated untracked history after preserving evidence;
  do not commit `out/` or generated report/history files.
- [X] T009-S2 [US1] Commit one bisect-safe change as
  `test(ux): capture credential resolution scenario` with
  `Tasks: T007, T008, T009`, then stop without pushing.

## Dependencies & Execution Order

T001 is Slice 1 RED proof and must be observed failing before implementation.
Navigator approval of that RED handoff precedes T002–T004; approval of the
complete GREEN diff precedes T005 and T006. Slice 2 starts only after Slice 1
and Q-001 approval. Navigator approval of the T007 missing-scenario RED
precedes the capture edit; approval of the complete GREEN diff precedes T008
and T009.

## Owned Files

- `tools/gen-broken-examples.py`
- `docs/inspector/src/Examples.purs`
- `docs/inspector/src/FFI/RdfShapes.js`
- `docs/inspector/src/FFI/RdfShapes.purs`
- `docs/inspector/src/Main.purs`
- `docs/inspector/tests/tx-identify.spec.mjs`

Slice 2 owns exactly:

- `tools/ux-judge/capture.mjs`

## Forbidden Scope

- `docs/inspector/src/FFI/RdfShapes.js`'s generic
  `resolvedLabelMatchesQuery` matching semantics from #144
- `specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex`
- `docs/inspector/protocols/amaru-treasury/journal-2026.json`
- `docs/inspector/protocols/amaru-treasury/overlay.ttl`
- Haskell/WASM ledger and emitter code
- `gate.sh`, all `specs/139-*` artifacts, PR/issue metadata, dependency files,
  generated hashes, and any file not listed under Owned Files
