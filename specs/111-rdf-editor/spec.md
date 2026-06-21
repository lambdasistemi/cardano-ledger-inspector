# Feature Specification: Extraction-ready RDF editor for `/library`

## User Story

As a user managing local overlay and blueprint books, I can open a stored book in
`/library`, view and copy its source, edit it with syntax highlighting, and save
only valid edits back to local storage.

## Functional Requirements

- FR-001: Provide a reusable CodeMirror 6-backed PureScript/FFI editor package
  with its own `spago.yaml`, `src/`, and public API documentation.
- FR-002: The editor package must have zero inspector coupling: no inspector
  routes, store types, book vocabulary, or `FFI.BookStore`/`FFI.OverlayBook`
  imports in package source or public API.
- FR-003: The editor API must be generic and extraction-ready: `mount`,
  `getValue`, `setValue`, `onChange`, `setMode` for Turtle/JSON, validation,
  and `dispose`.
- FR-004: The inspector must consume the editor only through that public API.
- FR-005: `/library` must show a per-book editor pane for stored books with
  Turtle and JSON syntax modes chosen from the book source kind.
- FR-006: `/library` must expose a per-book Copy action using the existing
  `FFI.Clipboard.copy` path.
- FR-007: Save-back must re-validate the edited text with the existing
  `OverlayBook.parse` parser before persisting.
- FR-008: Invalid save-back must show a clear error and leave the local book
  store unchanged.
- FR-009: CodeMirror npm dependencies must be exact pinned in
  `docs/inspector/package.json` and `package-lock.json`.
- FR-010: Add an in-repo security note documenting the CodeMirror supply-chain
  tradeoff, isolation from signing/key paths, exact pinning, and future
  re-evaluation trigger.
- FR-011: Playwright coverage must include open/edit/save round trip, copy, and
  reject-invalid behavior, and the deployed subpath route coverage must still
  include `/inspect`, `/settings`, and `/library`.

## Acceptance Criteria

- AC-001: The reusable editor package can be moved out as a directory without
  requiring inspector-specific refactors.
- AC-002: `rg` over the editor package source finds no inspector module imports
  or book/store vocabulary.
- AC-003: `nix build .#packages.x86_64-linux.tx-inspector-ui` succeeds.
- AC-004: Playwright passes with the new library editor tests and existing
  subpath tests.
- AC-005: `docs/inspector/SECURITY.md` exists and covers the CodeMirror
  security tradeoff required by issue #111.

## Non-goals

- RDF-aware autocomplete or semantic linting.
- Publishing the editor package to the PureScript registry.
- Building a standalone book-authoring app.
