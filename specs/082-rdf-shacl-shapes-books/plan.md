# Implementation Plan: RDF-5 SHACL shapes books

RDF-1 emits deterministic `cardano:` Turtle through `tx.rdf`. RDF-2 vendors
`rdf-shapes-wasm` and already exposes SPARQL query helpers. RDF-3/4 add
selective overlay and blueprint book composition. RDF-5 adds shapes books and
uses the already-vendored `validate(data_ttl, shapes_ttl)` SHACL Core engine
over the composed in-page graph.

## Architecture

- **Shapes book model**: extend the existing book parser/model to recognize
  SHACL Turtle as `kind = "shacl"` while preserving pasted overlay Turtle and
  CIP-57 blueprint JSON behavior. A bundled example shapes book lives under
  `docs/inspector/protocols/`.
- **FFI boundary**: extend `FFI.RdfShapes` with a `validate` wrapper over
  `globalThis.rdfShapes.validate(data_ttl, shapes_ttl)`. Normalize the JS
  result into a small PureScript-facing shape containing `conforms` and
  violation rows.
- **Data graph**: validate against `rdf.turtle <> selectedOverlayTurtle`.
  Blueprint selection is already materialized in `rdf.turtle` by the `tx.rdf`
  re-run, so no extra blueprint merge is needed in the SHACL path.
- **UI**: render a shapes panel near the RDF/book panels. It loads/imports
  shapes, lets the user select/deselect them, runs validation, and renders the
  same report as:
  - author gate: pass means safe to proceed from the book's perspective; fail
    means block/signing warning with violations;
  - auditor classifier: pass means canonical-pipeline match; fail means
    foreign/off-spec with the same violations.
- **Playwright proof**: add coverage for `globalThis.rdfShapes.validate`, a
  bundled/example conforming shapes book against the fixture graph, and a
  deliberately violating pasted shape that produces visible violation rows.

## Slice 1 - Shapes Engine And Book Model

Driver/navigator expose `validate()` through the FFI, add the example shapes
book asset, extend book parsing/selection for `kind = "shacl"`, and add a
focused Playwright engine/book test.

Focused proof:

```bash
nix develop --quiet -c just ui-check
nix develop --quiet -c just test-playwright
```

## Slice 2 - Conformance UX

Driver/navigator render the author-gate and auditor-classifier views from the
same normalized SHACL report, wire selection/application over the composed
graph, and add Playwright pass/fail coverage.

Focused proof:

```bash
./gate.sh
```

## Finalization

After all tasks are checked and the final local gate passes, update PR
metadata, drop `gate.sh`, mark the PR ready, push, and wait for GitHub Build
Gate CI to report green before writing `COMPLETE`.
