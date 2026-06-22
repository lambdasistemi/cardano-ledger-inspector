# Issue #119: CQuisitor-Style Inspect Surface

## User Story

As a transaction analyst using `/inspect`, I want the page to read like CQuisitor: a compact two-pane decode tool with paste input on the left and the decoded structure tree dominating the right, so I can inspect a transaction without fighting a dashboard layout or a metrics hero.

## Functional Requirements

- FR1: `/inspect` MUST present a hard two-pane desktop layout with a clear vertical divider: left pane for input/config/actions, right pane for decoded structure and result detail.
- FR2: The left pane MUST make the paste/fetch input visually prominent and keep chain-data/provider/book controls compact and inline.
- FR3: The right pane MUST lead with the decoded structure tree after a successful decode; no "Conway transaction identity" metrics-card hero may appear above the tree.
- FR4: Identity values may remain available only as compact secondary metadata, not as a hero grid above the tree.
- FR5: Witness, validation, RDF, browser, lenses, and book-resolution detail MUST remain available as secondary tabs or collapsible/result sections without changing decode/resolution behavior.
- FR6: The shell/top navigation MUST read like a compact tool with mode-tab styling; Settings and Library must be visually secondary to Inspect.
- FR7: Material components may remain in use, but the visual skin MUST be flat, compact, neutral, low-elevation, and label-dense like CQuisitor.

## Acceptance Criteria

- AC1: Side-by-side with `https://cardananium.github.io/cquisitor/`, `/inspect` has the same broad structure: compact header, mode-tab navigation, left input/config pane, right decoded-structure pane, and a visible divider.
- AC2: A genuine fixture decode lands with the Structure tab selected and the decoded tree visible in the first viewport.
- AC3: Playwright asserts no identity/metrics hero above the tree, tree dominance in the right pane, two-pane proportions, compact labels, and subpath `/inspect/` behavior.
- AC4: `nix build .#packages.x86_64-linux.tx-inspector-ui`, `just test-playwright`, and `./gate.sh` pass.
- AC5: A browser smoke using `specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex` verifies the preview visually against the saved CQuisitor reference.

## Non-Goals

- No ledger operation, provider, book-resolution, RDF, SPARQL, witness, validation, or WASM loading behavior changes.
- No dependency changes.
- No generated hash or lockfile changes.
