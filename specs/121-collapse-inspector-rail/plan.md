# Plan

## Current Gap

Issue #119 made `/inspect` CQuisitor-like by giving input and decoded structure a compact two-pane workspace. Issue #121 narrows that behavior: the two-pane layout is still right for empty/error states, but after a successful decode the permanent left rail wastes space. The loaded transaction should read like a tool surface where the result is primary and input/config/book controls collapse into a slim, reachable header.

Live CQuisitor reference captured outside git:

- `/tmp/ux121/clins-121/cquisitor-ready.png`

Observed direction: CQuisitor keeps control surfaces compact and modal/header-like so the working output dominates rather than sharing width with a persistent rail.

## Slice

The original rail-collapse work is one vertical presentation slice because the state gate, CSS layout, and Playwright coverage are one coherent UX behavior. The A-001 preview follow-up adds a second presentation-only slice on the same branch/PR for decoded-structure row compactness. A-002 adds a logic slice for decoded-tree annotation resolution. A-004 is a user redirect that supersedes the horizontal two-pane layout from Slice 1/A-001 with a vertical stack: load form at the top, books as its own section, decoded structure full-width below.

### Slice 1: Loaded-state rail collapse

Owned files:

- `docs/inspector/src/Main.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

Work:

- Gate `renderInspector` on `state.result`.
- Preserve the existing two-pane render path when `state.result == Nothing`, including fetch-error display.
- For `state.result == Just _`, render a loaded-state workspace variant: compact header strip for loaded context and controls, full-width result/decoded structure below.
- Include loaded context in the header: source/input mode, provider, network, and transaction id/hash derived from existing result/state data.
- Keep input and books reachable from the loaded header without changing decode or book logic. A details/expand affordance, edit-input toggle, or compact controls are acceptable if the decoded structure remains dominant.
- Update CSS `.workspace*` and responsive rules so loaded mode is full-width and narrow mode stacks cleanly.
- Add/extend Playwright assertions for empty two-pane behavior and loaded full-width/collapsed behavior, including the existing prefixed subpath harness.

Focused proof:

- `nix build .#packages.x86_64-linux.tx-inspector-ui`
- `just test-playwright`
- `just format-check`
- `just hlint`
- Browser smoke of the published preview with `specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex`.

### Slice 2: Decoded-tree row compactness

Owned files:

- `docs/inspector/src/Main.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

Work:

- In decoded-structure rows, render known vocab IRIs as linked CURIEs using a local prefix table that mirrors the `PREFIX` declarations in `docs/inspector/src/FFI/RdfShapes.js`; unknown HTTP(S) IRIs remain linked but middle-truncated.
- Collapse `urn:cardano:*` subject values from `id` or `summary` into a short middle-ellipsized, copyable, tooltip-backed text form; do not link URN subjects.
- Replace the always-visible inline annotation call-to-action with a compact `md-icon-button` edit affordance per row, while preserving `StartDecodedTreeAnnotation` and `SaveDecodedTreeAnnotation` behavior and every field in the existing annotation draft form.
- Keep the change presentation-only: no decode/resolution changes, no annotation persistence changes, no new JavaScript dependencies.
- Extend Playwright coverage for the CURIE href, absence of raw vocab URL text, collapsed/not-linked URN subjects, and editor hidden-until-click behavior.

Focused proof:

- `nix build .#packages.x86_64-linux.tx-inspector-ui`
- `just test-playwright`
- `just format-check`
- `just hlint`
- Browser smoke of the published preview with `specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex`.

### Slice 3: Annotation labels bind to decoded entities

Owned files:

- `docs/inspector/src/FFI/BookStore.js`
- `docs/inspector/src/FFI/BookStore.purs`
- `docs/inspector/src/FFI/RdfShapes.js`
- `docs/inspector/src/FFI/RdfShapes.purs`
- `docs/inspector/src/Main.purs`
- `docs/inspector/tests/tx-identify.spec.mjs`

Work:

- Add/extend Playwright coverage so saving an inline decoded-tree annotation proves resolver binding, not just local book persistence or transient DOM text. The test must fail on the current synthetic-proxy Turtle.
- Expose the canonical decoded-tree entity IRI on `DecodedTreeRow` (or otherwise pass the same canonical subject into the save path) for rows that support annotations.
- Generate annotation Turtle that writes `rdfs:label` and optional `a <type>` on the target entity IRI itself, matching the decoded-tree/overlay resolution subject convention instead of `local:annotation-*` proxy subjects.
- Recompute decoded-tree lenses after save as today, preserving selected-book persistence, export/import round-trip, and A-001 CURIE/collapsed-URN/edit-icon presentation.

Focused proof:

- `nix build .#packages.x86_64-linux.tx-inspector-ui`
- `just test-playwright`
- `just format-check`
- `just hlint`
- Browser smoke of the published preview: label a decoded node and observe the row resolve live without re-decode.

### Slice 4: Vertical inspect stack

Owned files:

- `docs/inspector/src/Main.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

Work:

- Replace the horizontal `.workspace` two-column layout with a vertical stack ordered top-to-bottom: collapsible load form, independent books section, full-width decoded result/structure area.
- Keep the load form expanded for empty/error states. Once a transaction result is present, default the load form to a compact header with source/network/tx context and a "Change input" style control that re-expands it at any time.
- Ensure the expanded loaded form is fully re-operable: users can change the tx hash or CBOR input and decode again; after successful re-decode the form returns to the compact loaded header.
- Move `renderBooksPanel` out of the load/input form. Fix the books-panel max-height/overflow truncation so the section is not clipped; it may size to content or scroll deliberately with visible affordance.
- Move `renderResult` below the load/books sections and make it full-width in both empty and loaded states. Remove the right-column decoded structure assumption.
- Preserve all prior decoded-tree behavior: linked CURIEs, collapsed/copyable `urn:cardano:*` subjects, edit-icon-gated annotation editor, and entity-bound annotation save/resolution.
- Extend Playwright coverage for vertical order, full-width decoded structure/no right column, books outside load form and not clipped, and collapse/uncollapse/re-decode round trip.

Focused proof:

- `nix build .#packages.x86_64-linux.tx-inspector-ui`
- `just test-playwright`
- `just format-check`
- `just hlint`
- Browser smoke of the published preview in empty and loaded states, including uncollapse/change-input visibility.

## Risks

- Existing CQuisitor layout tests currently assert the loaded pane stays 50/50; those must become the RED assertions for this ticket rather than being weakened.
- The header must expose real context without inventing new data dependencies; prefer existing state/result helpers.
- The CSS file is committed source in this app, so style changes must be reviewed like normal source rather than treated as generated output.
- Slice 4 intentionally changes earlier loaded-state layout assertions. Tests that still encode "decoded structure is on the right" should become RED assertions for the new vertical order rather than being weakened or deleted without replacement.
