# Tasks: Transaction-scoped Structure resolution demo

**Input**: [spec.md](spec.md), [plan.md](plan.md)
**Gate**: focused Firefox Playwright + `./gate.sh`; final `nix develop --quiet -c just ci`
**Implementation strategy**: one vertical, independently testable,
bisect-safe slice executed by a driver+navigator pair.

## Slice 1 — Bundled credential-resolution journey

**Goal**: Make one real required-signer credential visibly resolve in
Structure from the bundled Amaru book while preserving raw identity and
proving transaction scope across Structure and Graph / RDF.

**Independent proof**: The focused Playwright journey starts without the book,
loads the bundled example, observes the raw signer, applies the book, and
asserts the exact label/type/source/raw/copy/count and Graph / RDF distinction
without a second full decode.

- [ ] T001-S1 [US1] Add a failing `transaction-scoped owner-key resolution`
  Playwright journey to `docs/inspector/tests/tx-identify.spec.mjs` covering the
  exact before/after Network Compliance signer, copyability, count, Graph / RDF
  match/vocabulary cues, provider silence, and no repeat `tx.inspect` call.
- [ ] T002-S1 [US1] Extend `tools/gen-broken-examples.py` with the existing
  committed SundaeSwap disbursement fixture as the “Amaru owner-key
  resolution” example and regenerate `docs/inspector/src/Examples.purs`.
- [ ] T003-S1 [US1] In `docs/inspector/src/FFI/RdfShapes.js`, project
  `cardano:hasRequiredSigner` entities into the decoded tree and map #144's
  existing explicit generic suffix matches onto their concrete transaction
  identities without changing the suffix-query semantics.
- [ ] T004-S1 [US1] Extend
  `docs/inspector/src/FFI/RdfShapes.purs` and
  `docs/inspector/src/Main.purs` so Structure renders RDF type and selected
  overlay source, counts distinct resolved transaction entities, preserves raw
  copy controls, and Graph / RDF distinguishes transaction matches from
  book-only vocabulary.
- [ ] T005-S1 [US1] Run the focused journey on an isolated
  `PLAYWRIGHT_PORT`, the existing generic hex-suffix and address-resolution
  regressions, and `./gate.sh`; verify `gate.sh`, the transaction fixture, the
  Amaru journal, and overlay Turtle are unchanged from `origin/main`.
- [ ] T006-S1 [US1] Commit one bisect-safe change as
  `feat(inspector): demonstrate credential resolution in Structure` with
  `Tasks: T001, T002, T003, T004, T005, T006`, then stop without pushing.

## Dependencies & Execution Order

T001 is RED proof and must be observed failing before any implementation.
Navigator approval of the RED handoff precedes T002–T004. Navigator approval
of the complete GREEN diff precedes T005 and the single T006 commit.

## Owned Files

- `tools/gen-broken-examples.py`
- `docs/inspector/src/Examples.purs`
- `docs/inspector/src/FFI/RdfShapes.js`
- `docs/inspector/src/FFI/RdfShapes.purs`
- `docs/inspector/src/Main.purs`
- `docs/inspector/tests/tx-identify.spec.mjs`

## Forbidden Scope

- `docs/inspector/src/FFI/RdfShapes.js`'s generic
  `resolvedLabelMatchesQuery` matching semantics from #144
- `specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex`
- `docs/inspector/protocols/amaru-treasury/journal-2026.json`
- `docs/inspector/protocols/amaru-treasury/overlay.ttl`
- Haskell/WASM ledger and emitter code
- `gate.sh`, all `specs/139-*` artifacts, PR/issue metadata, dependency files,
  generated hashes, and any file not listed under Owned Files
