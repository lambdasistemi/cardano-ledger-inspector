# Tasks: RDF-3 overlay books

## Slice 1 - Overlay Book Asset And Parser

- [X] T080-S1 Add an Amaru overlay Turtle asset derived from
  `docs/inspector/protocols/amaru-treasury/journal-2026.json`.
- [X] T080-S1 Add browser import/parse state for pasted Turtle and bundled
  Amaru journal JSON.
- [X] T080-S1 Add selectable overlay parts with deterministic selected Turtle
  output and zero contribution from unselected parts.
- [X] T080-S1 Run `nix develop --quiet -c just check-rdf`,
  `nix develop --quiet -c just ui-check`, and `./gate.sh`.
- [X] T080-S1 Commit as `feat: add rdf overlay book import model`.

## Slice 2 - Merge And Resolved Labels UX

- [ ] T080-S2 Merge selected overlay Turtle with `tx.rdf` by RDF union only.
- [ ] T080-S2 Add a named resolved-labels SPARQL lens through
  `rdf-shapes-wasm query()` and render label/role/entity rows.
- [ ] T080-S2 Extend Playwright coverage for import, select, merge,
  resolved-label rendering, and deselect selectivity.
- [ ] T080-S2 Run `nix develop --quiet -c just check-rdf`,
  `nix develop --quiet -c just ui-check`,
  `nix develop --quiet -c just test-playwright`, and `./gate.sh`.
- [ ] T080-S2 Commit as `feat: render resolved labels from rdf overlay books`.
