# Tasks: Generic hex-suffix credential resolution

**Input**: [spec.md](spec.md), [plan.md](plan.md)  
**Gate**: `./gate.sh`  
**Implementation strategy**: one independently testable, bisect-safe slice.

## Slice 1 — Resolve generic credential hashes

**Goal**: Present the two named Amaru owner credentials when their generic
book identities match transaction-specific credential identifiers by hex
suffix, while retaining prior label resolutions.

**Independent proof**: The focused packaged-browser regression shows both
owner labels and concrete matched identifiers for the scoped real transaction,
continues to show a pre-existing resolution, and passes the ticket gate.

- [X] T001-S1 [US1] Add a failing `generic hex-suffix credential resolution`
  regression to `docs/inspector/tests/tx-identify.spec.mjs` for both scoped
  owner hashes and one existing resolution.
- [X] T002-S1 [US1] Extend the resolved-label query and result normalisation in
  `docs/inspector/src/FFI/RdfShapes.js` to return the transaction credential
  matched by the shared hex suffix; document the accepted same-bytes,
  cross-type collision limitation beside that query.
- [X] T003-S1 [US1] Run `./gate.sh`, inspect its successful output, and commit
  `feat(inspector): resolve credentials by generic hex suffix` with
  `Tasks: T001, T002, T003`.

## Dependencies & Execution Order

T001 is RED proof and must be observed failing before T002. T002 follows
after navigator approval of the RED handoff. T003 follows GREEN approval and
is the only commit in this slice.

## Scope Guard

The driver may edit only:

- `docs/inspector/src/FFI/RdfShapes.js`
- `docs/inspector/tests/tx-identify.spec.mjs`

It must not edit `docs/inspector/src/Main.purs`, any Turtle book, any
tx-graph emitter source, or any orchestrator-owned file under `specs/`.
