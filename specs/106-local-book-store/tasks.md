# Tasks

## Slice 1 - Store Foundation

- [X] T106-S1 Add a typed local book store module with seed loading,
  parse/serialize helpers, stable ids, selected flags, and corrupt-store
  fallback.
- [X] T106-S1 Extend FFI only as needed for storage/remove/download/file/URL
  primitives.
- [X] T106-S1 Add focused Playwright RED proof that seeded books persist and
  can be inspected from localStorage.
- [X] T106-S1 Run `./gate.sh` and commit `feat(inspector): add local book store foundation`.

## Slice 2 - Library CRUD

- [ ] T106-S2 Replace the `/library` placeholder with the local book store
  list.
- [ ] T106-S2 Implement paste add, rename, select/deselect, and guarded
  delete with persistent state.
- [ ] T106-S2 Add Playwright coverage for list, add, select, rename,
  delete, and reload persistence.
- [ ] T106-S2 Run `./gate.sh` and commit `feat(inspector): manage books in the library`.

## Slice 3 - Exchange Paths

- [ ] T106-S3 Add file upload, URL import, export selected, export all, and
  import store JSON.
- [ ] T106-S3 Add Playwright coverage for export/import round-trip into a
  clean browser context.
- [ ] T106-S3 Run `./gate.sh` and commit `feat(inspector): exchange local book stores`.

## Slice 4 - Inspect Wiring + Acceptance

- [ ] T106-S4 Make the inspect Books panel read selected store books and
  merge them into the RDF/decoded-tree resolution path.
- [ ] T106-S4 Remove inspect hardcoded bundled-book buttons; bundled books
  are seed store entries only.
- [ ] T106-S4 Extend Playwright coverage for selected store book resolving a
  decoded-tree node on a genuine fixture.
- [ ] T106-S4 Keep the non-root subpath navigation, refresh, and deep-link
  assertions green for `/inspect`, `/settings`, and `/library`.
- [ ] T106-S4 Run `./gate.sh` and commit `feat(inspector): resolve inspected trees from selected books`.

## Finalization

- [ ] T106-F1 Verify local acceptance commands and browser smoke evidence.
- [ ] T106-F2 Update the draft PR body with delivered behavior and proof.
- [ ] T106-F3 Verify CI green and preview published.
- [ ] T106-F4 Browser-smoke the preview URL under `/inspector/`.
- [ ] T106-F5 Drop `gate.sh` in the ready-for-review commit after all tasks
  are complete.
