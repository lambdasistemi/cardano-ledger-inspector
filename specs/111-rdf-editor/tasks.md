# Tasks: Extraction-ready RDF editor

## Slice 1 - reusable editor package and build wiring

- [X] T111-S1 Create `packages/purescript-rdf-editor/` as a standalone Spago package with documented generic API.
- [X] T111-S1 Implement CodeMirror 6 FFI for mount/getValue/setValue/onChange/setMode/validate/dispose with Turtle and JSON modes.
- [X] T111-S1 Wire the inspector Spago workspace and bootstrap/npm lock to consume the package through its public API only.
- [X] T111-S1 Prove `spago build` and `nix build .#packages.x86_64-linux.tx-inspector-ui` pass.
- [X] T111-S1 Commit as `feat(ui): add reusable RDF editor package`.

## Slice 2 - library editor view and copy action

- [X] T111-S2 Render a `/library` editor surface for stored books using the reusable package API.
- [X] T111-S2 Select Turtle or JSON mode from the stored book source/raw content.
- [X] T111-S2 Add per-book Copy through `FFI.Clipboard.copy`.
- [X] T111-S2 Keep Material styling consistent and responsive.
- [X] T111-S2 Prove the focused UI build passes.
- [X] T111-S2 Commit as `feat(ui): expose book source editor in library`.

## Slice 3 - validated save-back

- [X] T111-S3 Track editor drafts without mutating stored books while typing.
- [X] T111-S3 On save, validate edited content through `OverlayBook.parse`.
- [X] T111-S3 Persist only successful parse results, updating raw/source/parts/turtle fields consistently.
- [X] T111-S3 Reject invalid input with a clear visible error and leave localStorage unchanged.
- [X] T111-S3 Prove focused save-back behavior with build or browser smoke evidence.
- [X] T111-S3 Commit as `feat(ui): validate book editor save-back`.

## Slice 4 - acceptance hardening

- [X] T111-S4 Add `docs/inspector/SECURITY.md` documenting the CodeMirror security tradeoff and constraints.
- [X] T111-S4 Add Playwright coverage for open/edit/save, copy, and reject-invalid.
- [X] T111-S4 Keep the deployed non-root subpath route coverage green for `/inspect`, `/settings`, and `/library`.
- [X] T111-S4 Run `./gate.sh final` locally and record evidence.
- [X] T111-S4 Commit as `test(ui): cover validated library editor`.

## Finalization

- [ ] T111-F1 Verify editor package source has no inspector imports or book/store coupling.
- [ ] T111-F1 Verify CodeMirror npm dependencies are exact pinned.
- [ ] T111-F1 Push branch and keep PR draft until CI, preview, and browser smoke pass.
