# Tasks: RDF-5 SHACL shapes books

## Slice 1 - Shapes Engine And Book Model

- [X] T082-S1 Extend `FFI.RdfShapes` with a typed `validate` wrapper over the
  vendored `globalThis.rdfShapes.validate(data_ttl, shapes_ttl)` API.
- [X] T082-S1 Add a bundled example SHACL shapes book under
  `docs/inspector/protocols/` and expose it through the browser bundle without
  runtime network fetches.
- [X] T082-S1 Extend the existing book parser/model so shapes Turtle imports as
  selectable `kind = "shacl"` parts while overlay Turtle and blueprint JSON
  behavior remains unchanged.
- [X] T082-S1 Add focused Playwright coverage proving the vendored validate
  engine is callable and the bundled shapes book imports as a selectable part.
- [X] T082-S1 Run `nix develop --quiet -c just ui-check` and
  `nix develop --quiet -c just test-playwright`.
- [X] T082-S1 Commit as `feat: import rdf shacl shapes books`.

## Slice 2 - Conformance UX

- [ ] T082-S2 Validate the composed graph (`rdf.turtle` plus selected overlay
  Turtle) against selected shapes and keep unselected shapes effect-free.
- [ ] T082-S2 Render pass/fail from the normalized SHACL report as both author
  gate and auditor classifier views.
- [ ] T082-S2 Render SHACL violation rows with focus node, path, message, and
  source shape details when present.
- [ ] T082-S2 Extend Playwright coverage for a conforming fixture and a
  deliberately violating shapes book that shows violation rows.
- [ ] T082-S2 Run `./gate.sh`.
- [ ] T082-S2 Commit as `feat: render rdf shacl conformance`.
