# Plan

## Context

The current Structure tree is generated from `tx.rdf` through `docs/inspector/src/FFI/RdfShapes.js` and rendered by `docs/inspector/src/Main.purs`. It currently presents a curated tree: body scalar fields, all input-like rows in one "Inputs" section, outputs, a duplicate Fee section, witnesses, redeemers, and a collapsed metadata section. Issue #124 requires this to become a faithful structural view of the Conway transaction in CDDL order.

The acceptance oracle is hermetic. It does not call `cardano-cli`, CSL, or CML. The parity test key-walks only the top-level CBOR shape needed to know which CDDL keys are present, then compares that structural field set and order with the rendered Structure rows.

## Slice 1: Faithful Structure Parity

One vertical slice covers the whole milestone because the RED test and the Structure implementation must agree on the same CDDL contract.

Owned files:

- `docs/inspector/src/FFI/RdfShapes.js`
- `docs/inspector/src/FFI/RdfShapes.purs`
- `docs/inspector/src/Main.purs`
- `docs/inspector/tests/tx-identify.spec.mjs`

Expected implementation shape:

- Add a dependency-free CBOR key walker in the Playwright spec or a local helper in that same file. It only needs to walk the outer transaction array, body map integer keys, witness-set map integer keys, `is_valid`, and auxiliary-data presence enough for the parity assertions.
- Add RED assertions over every current Amaru `signed-tx.hex` fixture under `/code/amaru-treasury-tx/transactions/2026/**`, with a non-empty corpus assertion.
- Add a focused golden assertion for the `18d57a4f...` contingency transaction matching the CQuisitor field tree from `/tmp/ux121/faithful-decode-spec.md`.
- Update the decoded Structure normalization so it emits a stable row tree in the CDDL order from the spec, explicitly includes NULL rows for absent fields, keeps input categories distinct, removes the duplicate Fee section, expands auxiliary metadata, and shows `is_valid`.
- Preserve existing decoded-tree row shape and annotation metadata so book resolution and CURIE tests keep working.

## Verification

Focused proof inside the slice:

- `nix build .#packages.x86_64-linux.tx-inspector-ui`
- `nix develop --quiet -c sh -c 'cd docs/inspector && TX_AMARU_TREASURY_TX_ROOT=/code/amaru-treasury-tx TX_INSPECTOR_SITE_DIR=../../result playwright test tests/tx-identify.spec.mjs --grep "faithful CQuisitor parity" --reporter=list'`

Final proof:

- `nix build .#packages.x86_64-linux.tx-inspector-ui`
- `just test-playwright`
- `just format-check`
- `just hlint`

The PR remains draft after verification.
