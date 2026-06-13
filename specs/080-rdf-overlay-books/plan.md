# Implementation Plan: RDF-3 overlay books

## Context

RDF-1 emits deterministic `cardano:` Turtle through `tx.rdf`. RDF-2 vendors
`rdf-shapes-wasm` and renders a fixed SPARQL lens over that graph. RDF-3 adds
overlay data authored outside the transaction, selected by the user, merged by
IRI union, then queried with another fixed named lens.

## Technical Shape

- **Overlay asset**: add a repository-local Amaru overlay Turtle asset next to
  `docs/inspector/protocols/amaru-treasury/journal-2026.json`.
- **Book parsing**: add a small browser-side parser/import layer for pasted
  Turtle and the Amaru journal JSON shape. Journal JSON becomes overlay parts:
  scopes, treasury addresses, owner identifiers, and deployed script refs.
- **Selection state**: keep selected part ids in Halogen state. The merged graph
  is `tx.rdf.turtle <> selectedOverlayTurtle`.
- **Resolved-labels lens**: extend the `FFI.RdfShapes` wrapper with a named
  query returning normalized rows. The query joins overlay `cardano:Entity`
  labels/roles to transaction graph IRIs/literals via shared IRI and canonical
  Cardano predicates.
- **UI**: render import controls, a selected-parts checklist, merged graph
  status, and resolved-label rows inside the existing result area.
- **Tests**: extend the Playwright fixture decode test to import the bundled
  overlay, prove a label appears, deselect it, and prove the label disappears.

## Slices

### Slice 1 - Overlay Book Asset And Parser

Create the Amaru overlay Turtle asset and browser-side import/selection model.
This slice should prove selectivity without depending on the final resolved
labels lens rendering.

### Slice 2 - Merge And Resolved Labels UX

Union selected overlay Turtle with the transaction graph, run the named SPARQL
resolved-labels lens, render results, and add Playwright coverage.

## Verification

Per slice:

- `nix develop --quiet -c just check-rdf`
- `nix develop --quiet -c just ui-check`
- `nix develop --quiet -c just test-playwright`
- `./gate.sh`

Final:

- `just build-ui`
- `./gate.sh`
