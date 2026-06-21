# Implementation Plan: Extraction-ready RDF editor

## Architecture

Create a standalone package at `packages/purescript-rdf-editor/` with:

- `spago.yaml`
- `src/RdfEditor.purs`
- `src/RdfEditor.js`
- package-local README documenting the API and extraction contract

The package is generic. It owns CodeMirror mounting, document access, mode
switching, change notification, validation hook support, and disposal. It does
not import or mention inspector modules, book stores, routes, Cardano-specific
book names, or local-storage details.

The inspector app consumes this package through Spago `extraPackages` from
`docs/inspector/spago.yaml`. CodeMirror npm dependencies are bundled by the
existing esbuild bootstrap path in `docs/inspector/src/bootstrap.js`, exposed to
the FFI through `globalThis`, and pinned exactly in `docs/inspector/package.json`
and `package-lock.json`.

## CodeMirror API Notes

Current CodeMirror 6 docs confirm:

- editor state is created with `EditorState.create({ doc, extensions })`;
- an editor is attached with `new EditorView({ state, parent })`;
- full value read is `view.state.doc.toString()`;
- full replacement is `view.dispatch({ changes: { from: 0, to:
  view.state.doc.length, insert: text } })`;
- change callbacks use `EditorView.updateListener.of(update => ...)`;
- legacy stream modes use `StreamLanguage.define(...)`.

Use `@codemirror/lang-json` for JSON and
`@codemirror/legacy-modes/mode/turtle` with `StreamLanguage.define` for Turtle.

## Slice Breakdown

### Slice 1: reusable editor package and build wiring

Add the standalone package and app dependency wiring. Prove the package compiles
from the inspector workspace and the UI bundle can include exact-pinned
CodeMirror dependencies. No `/library` behavior changes beyond import/build
plumbing.

### Slice 2: `/library` editor view and copy action

Mount the editor for each stored book or a selected book detail pane in
`/library`, with Material-compatible styling, Turtle/JSON mode selection, and a
Copy button using `FFI.Clipboard.copy`.

### Slice 3: validated save-back

Track editor drafts, save edited content through `OverlayBook.parse`, update
the existing `BookStore.Book` fields only after a successful parse, refresh
book-derived lenses where needed, and reject invalid content without mutating
local storage.

### Slice 4: acceptance hardening

Add `docs/inspector/SECURITY.md`, Playwright coverage for open/edit/save,
copy, reject-invalid, and keep the existing non-root subpath route checks green.
Run the final gate locally before push readiness.

## Verification

Focused slice gates should include `nix develop --quiet -c sh -c 'cd
docs/inspector && spago build'` and `nix build
.#packages.x86_64-linux.tx-inspector-ui`. Final verification must run
`./gate.sh final`, which includes Playwright.

## Risks

- Halogen lifecycle integration with an imperative CodeMirror view needs careful
  disposal or idempotent mounting.
- CodeMirror increases the runtime npm tree. The security note and exact pins
  are acceptance requirements, not optional documentation.
- Save-back must parse the edited raw text, not only update displayed Turtle,
  because JSON blueprint books and Turtle books use different raw formats.
