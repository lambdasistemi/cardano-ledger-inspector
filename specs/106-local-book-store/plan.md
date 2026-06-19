# Plan

## Context

The current inspector keeps imported overlay parts only in `Main.purs`
state. `/library` is a placeholder, and inspect still exposes hardcoded
"Load bundled book" buttons. #104 already proved the merge path:
selected overlay and blueprint parts feed `tx.rdf`, then resolved labels
and decoded-tree lenses query the merged Turtle.

## Design

Add a small browser-local book store for parsed overlay books.

- Store key: `cardano-ledger-inspector.books.v1`.
- Stored entry shape: stable `id`, editable `name`, `source`, raw input
  text, parsed `parts`, parsed `turtle`, booleans `selected` and `seed`.
- Store envelope shape: `{ "kind": "cardano-ledger-inspector.books.v1",
  "books": [...] }`.
- Invalid or missing store data falls back to seed books rather than
  partially recovering corrupt entries.
- The bundled Amaru, SundaeSwap, and SHACL books are just seed entries in
  the same store. Users may delete them; a later first-run in a fresh
  browser re-seeds.
- `/library` and inspect use the same load/save helpers, so selecting a
  book in `/library` immediately changes the merge set used by inspect
  after reload/navigation.
- Export/import is JSON only. Paste/file/URL book input still accepts the
  existing parsed book formats: Amaru journal JSON, blueprint JSON, SHACL
  Turtle, and overlay Turtle.

## Slices

### Slice 1 - Store Foundation

Create a typed store module and FFI helpers for localStorage, download,
file-read, and URL fetch. Seed bundled books through `OverlayBook.parse`.
No visible UI beyond preserving the existing placeholder route.

Owned files:
- `docs/inspector/src/FFI/Storage.purs`
- `docs/inspector/src/FFI/Storage.js`
- `docs/inspector/src/FFI/BookStore.purs`
- `docs/inspector/src/FFI/BookStore.js`
- `docs/inspector/src/Main.purs`
- `docs/inspector/tests/tx-identify.spec.mjs`

### Slice 2 - Library CRUD

Replace the `/library` placeholder with a Material-styled local book list
plus paste add, rename, select, and guarded delete. The page should be
compact and consistent with the existing settings/inspect styling.

Owned files:
- `docs/inspector/src/Main.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

### Slice 3 - Exchange Paths

Add URL import, file import, export selected, export all, and JSON import
round-trip behavior. The Playwright proof must export from one browser
context and import into a clean store.

Owned files:
- `docs/inspector/src/FFI/Storage.purs`
- `docs/inspector/src/FFI/Storage.js`
- `docs/inspector/src/FFI/BookStore.purs`
- `docs/inspector/src/FFI/BookStore.js`
- `docs/inspector/src/Main.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

### Slice 4 - Inspect Wiring + Acceptance

Make inspect's Books panel consume selected store entries, remove the
hardcoded bundled-book magic from the inspect flow, and prove a selected
store book resolves a decoded-tree node on a genuine fixture. Keep or
extend the non-root subpath spec for `/inspect`, `/settings`, and
`/library`.

Owned files:
- `docs/inspector/src/Main.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

## Verification

Every implementation slice runs `./gate.sh`. Final local acceptance also
requires:

- `nix build .#packages.x86_64-linux.tx-inspector-ui`
- `nix develop --quiet -c just format-check`
- `nix develop --quiet -c just hlint`
- `nix develop --quiet -c just test-playwright`
- Manual or Playwright browser smoke: add a book, export it, import it into
  a clean store, select it, decode a genuine fixture, and observe a
  resolved decoded-tree row.
