# Tasks

## Slice 1: Loaded-state rail collapse

- [X] T121-S1 Add Playwright RED assertions that empty/error states keep the two-pane layout and loaded state collapses the left rail into a slim header with full-width decoded results.
- [X] T121-S1 Update `Main.purs` presentation to gate on `state.result`, preserving the empty/error two-pane path and rendering a loaded-state header plus full-width result path for `Just _`.
- [X] T121-S1 Update `styles.css` workspace/header/responsive rules so loaded desktop is full-width and narrow layouts stack without overlap.
- [X] T121-S1 Run `nix build .#packages.x86_64-linux.tx-inspector-ui`, `just test-playwright`, `just format-check`, and `just hlint`; commit one bisect-safe slice with the required `Tasks: T121-S1` trailer.

## Slice 2: Decoded-tree row compactness

- [X] T121-S2 Add Playwright RED assertions for decoded-structure rows: vocab IRIs render as linked CURIEs with the full href, raw vocab URLs are not shown as row text, `urn:cardano:*` subjects are collapsed and not linked, and annotation fields stay hidden until the edit icon is clicked.
- [X] T121-S2 Update `Main.purs` presentation so decoded tree rows use the `FFI/RdfShapes.js` prefix table for linked CURIE labels, collapse/copy non-dereferenceable `urn:cardano:*` subjects, and gate the existing annotation draft form behind an `md-icon-button` edit affordance without changing the save flow.
- [X] T121-S2 Update `styles.css` for the compact CURIE/subject/edit-icon row presentation and responsive annotation expander behavior.
- [X] T121-S2 Run `nix build .#packages.x86_64-linux.tx-inspector-ui`, `just test-playwright`, `just format-check`, and `just hlint`; commit one bisect-safe slice with the required `Tasks: T121-S2` trailer.

## Slice 3: Annotation labels bind to decoded entities

- [X] T121-S3 Add Playwright RED coverage that labeling decoded-tree nodes resolves the row through the decoded-tree resolver immediately after Save, including Output 0, an address, a script/hash-like row, and another identifier row where present.
- [X] T121-S3 Surface the decoded row's canonical entity IRI to the annotation save path and update generated annotation Turtle so `rdfs:label` and optional `a <type>` attach to that entity rather than a synthetic local proxy.
- [X] T121-S3 Preserve the A-001 presentation contract and existing annotation book persistence/export/import behavior while making the saved label/type re-query into `resolvedLabel`/`resolvedType` without a re-decode.
- [X] T121-S3 Run `nix build .#packages.x86_64-linux.tx-inspector-ui`, `just test-playwright`, `just format-check`, and `just hlint`; commit one bisect-safe slice with the required `Tasks: T121-S3` trailer.

## Slice 4: Vertical inspect stack

- [X] T121-S4 Add Playwright RED coverage for the revised vertical inspect layout: load form above books above decoded structure, no right-column decoded pane, decoded structure full-width, books outside the load form and not clipped, and loaded-state collapse/uncollapse/re-decode behavior.
- [X] T121-S4 Update `Main.purs` presentation so `.workspace` renders as a vertical stack with a top collapsible load form, a separate books section, and full-width decoded results below while preserving CURIE links, collapsed URNs, edit-icon annotation gating, and entity-bound annotation resolution.
- [X] T121-S4 Update `styles.css` to remove the horizontal two-column workspace assumptions, fix the books panel height truncation/overflow bug, and keep empty, loaded, and narrow layouts visually coherent.
- [X] T121-S4 Run `nix build .#packages.x86_64-linux.tx-inspector-ui`, `just test-playwright`, `just format-check`, and `just hlint`; commit one bisect-safe slice with the required `Tasks: T121-S4` trailer.
