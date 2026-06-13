# Feature Specification: RDF-5 SHACL shapes books

**Branch**: feat/rdf-shacl-shapes-books
**Issue**: lambdasistemi/cardano-ledger-inspector#82

## User Story

As a browser workbench user inspecting a Conway transaction, I can import a
SHACL shapes book, select it alongside the transaction RDF graph and any
overlay/blueprint books, and see a client-side conformance report that works
both as an author gate before signing and as an auditor classifier after the
fact.

## Functional Requirements

- **FR-001**: A shapes book is a local Turtle asset containing SHACL Core
  shapes. The browser MUST accept pasted shapes Turtle and expose at least one
  bundled example under `docs/inspector/protocols/`.
- **FR-002**: Shapes books MUST run through the vendored
  `rdf-shapes-wasm.validate(data_ttl, shapes_ttl)` API. No server-side SHACL,
  JVM `shacl`, or remote validation service is allowed.
- **FR-003**: The validation data graph MUST be the current `cardano:` RDF
  graph plus selected overlay Turtle. If selected blueprint books are applied,
  their typed fields are already included in the current RDF graph and MUST be
  visible to SHACL.
- **FR-004**: The UI MUST render one conformance result from `validate()` in
  two interpretations: author gate and auditor classifier.
- **FR-005**: Author gate copy MUST flag non-conforming transactions before
  signing and clearly show the SHACL violations.
- **FR-006**: Auditor classifier copy MUST classify conforming transactions as
  canonical-pipeline matches and non-conforming transactions as foreign or
  off-spec.
- **FR-007**: The report MUST include pass/fail and normalized violation rows
  with enough detail to identify the failed focus node, path, message, and
  source shape when the engine provides them.
- **FR-008**: Shapes book selection is selective: unselected shapes have zero
  effect on the conformance report, and selected shapes can be deselected.
- **FR-009**: Ledger validation, book signing/trust roots, remote catalogs, and
  arbitrary user-authored SHACL editing beyond paste/import are out of scope.

## Success Criteria

- Importing or loading the example shapes book and applying it to a matching
  decoded fixture renders a conforming report.
- Replacing the selected shapes with a deliberately violating shape renders a
  non-conforming report with visible violation rows.
- The same `validate()` output is rendered as both author gate and auditor
  classifier status.
- Validation runs fully in the browser through `rdf-shapes-wasm`; tests prove
  `globalThis.rdfShapes.validate` is callable from the page.
- `just ui-check`, `just test-playwright`, and `./gate.sh` pass locally before
  push.
- The PR is not reported complete until GitHub Build Gate CI is green.
