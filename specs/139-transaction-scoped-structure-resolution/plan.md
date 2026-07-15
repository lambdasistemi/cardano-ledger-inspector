# Implementation Plan: Transaction-scoped Structure resolution demo

**Branch**: `feat/139-structure-resolution-demo` | **Date**: 2026-07-15 | **Spec**: [spec.md](spec.md)

## Summary

Promote #144's proven generic credential match into the primary Structure
tree. Reuse the committed real transaction whose two required signers match
the bundled Amaru owner entries, add it to Examples through the existing
generator, project `cardano:hasRequiredSigner` rows from the canonical RDF
graph, and distinguish matched transaction labels from book-only vocabulary in
Graph / RDF. One Playwright journey supplies the RED/GREEN proof.

## Technical Context

**Languages**: PureScript/Halogen browser shell plus JavaScript RDF FFI.
**Canonical data source**: Haskell/WASM `tx.rdf`; the pinned emitter represents
required signers as `cardano:hasRequiredSigner` targets with
`cardano:bytesHex`.
**Matching primitive**: existing `resolvedLabelMatchesQuery` from #144; do not
specialize or replace it.
**Committed fixture**:
`specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex`.
**Testing**: focused Firefox Playwright, `./gate.sh`, then
`nix develop --quiet -c just ci`. Use an isolated `PLAYWRIGHT_PORT`.

## Design

1. Extend `tools/gen-broken-examples.py`'s generated Examples module inputs
   with a non-broken “Amaru owner-key resolution” entry read from the existing
   fixture. Regenerate `docs/inspector/src/Examples.purs`; do not duplicate the
   fixture or edit the generated module by hand.
2. Add a decoded required-signers SPARQL projection in `RdfShapes.js`:
   `?transaction cardano:hasRequiredSigner ?entity`, with the entity's
   `cardano:bytesHex` and RDF type. Replace the current hard-coded null
   `required_signers` body field with a container and one child per result.
3. Reuse #144's generic explicit-match results when constructing decoded label
   matches. Map each concrete matched transaction identity (and its raw hash)
   to the book label/type; leave the suffix query itself unchanged.
4. Extend the resolved-label row shape with a transaction-match flag computed
   from the existing explicit-match set. Render that flag as a generic
   “Transaction match” versus “Book vocabulary” cue in Graph / RDF.
5. In Structure, display the resolved RDF type when present and derive the
   source cue from selected overlay books (not every selected blueprint/SHACL
   book). Compute the toolbar count from distinct resolved transaction entity
   identities, not overlay rows.
6. Add one exact before/after Playwright scenario. It deselects the Amaru book,
   loads the new example, proves the raw required signer, applies the book,
   proves its label/type/source/raw/copy/count, checks Graph / RDF match versus
   vocabulary cues, and records operation calls to prove book re-application
   does not repeat `tx.inspect`.

## Project Structure

```text
tools/gen-broken-examples.py                    # generated Examples inputs
docs/inspector/src/Examples.purs                # regenerated bundled example
docs/inspector/src/FFI/RdfShapes.js             # required-signer projection + match metadata
docs/inspector/src/FFI/RdfShapes.purs           # typed row extension
docs/inspector/src/Main.purs                     # Structure/Graph rendering and count
docs/inspector/tests/tx-identify.spec.mjs        # exact before/after proof
```

The existing transaction fixture and Amaru journal/book remain byte-identical.
`gate.sh` is inherited from the epic and MUST remain byte-identical to
`origin/main`.

## Slice Plan

### Slice 1 — Bundled credential-resolution journey

One vertical, bisect-safe implementation commit:

- Add the Playwright journey first and observe RED because the example and
  required-signer Structure rows/cues do not exist.
- Generate the new example, project required signers, surface generic matches
  in Structure, add exact source/type/count cues, and distinguish Graph / RDF
  rows.
- Run the focused Playwright scenario on an isolated port, the existing #144
  generic-resolution regression, `./gate.sh`, and UI formatting/build checks.
- Commit as `feat(inspector): demonstrate credential resolution in Structure`
  with `Tasks: T001, T002, T003, T004, T005, T006`.

## Verification

- **RED**: focused grep `transaction-scoped owner-key resolution` fails before
  implementation for the missing example/Structure match.
- **GREEN**: the same focused Firefox scenario passes with an isolated
  `PLAYWRIGHT_PORT`.
- **Regression**: existing `generic hex-suffix credential resolution` and
  decoded-tree address resolution scenarios pass.
- **Slice gate**: `./gate.sh` passes without any edit to `gate.sh`.
- **Final gate**: `nix develop --quiet -c just ci` passes at the accepted HEAD.
- **UX evidence**: capture the resolved Structure state at the acceptance
  scenario's desktop viewport for the parent/PR report.

## Risks and Controls

- **Catalog overcount**: only decoded Structure rows can contribute to the
  count, keyed by concrete entity identity; book lens rows never do.
- **False protocol coupling**: tests name Amaru data, but implementation joins
  generic RDF identifiers and renders generic row metadata only.
- **Source ambiguity with multiple overlays**: source cues derive only from
  selected overlay books. If more than one can supply a row and exact
  attribution cannot be determined generically, stop and file a Q rather than
  guessing or adding a protocol branch.
- **Concurrent host ports**: choose a unique `PLAYWRIGHT_PORT` proactively.
