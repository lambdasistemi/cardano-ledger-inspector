# Plan

## Context

#98 introduced the route shell and Material runtime bundle.
#100/#101 moved chain-data settings to `/settings` and made `/inspect` a
full-width input/results workspace. The current inspector still renders normal
HTML buttons/inputs and a long decoded-results stack. It already runs `tx.rdf`
after decode and has `docs/inspector/src/FFI/RdfShapes.js` wrappers around the
browser RDF/SPARQL engine.

The CQuisitor reference model for this child is the issue-defined "dig into
data" shape: left input pane, right expandable decoded structure tree,
type-aware labels, raw opaque values, with byte highlighting and resolution
left for later children.

## Implementation

Use two implementation slices.

### Slice 1 — Material Baseline And Two-Pane Workspace

- Add Material Symbols Outlined, Roboto Flex, and Roboto Mono links to
  `docs/inspector/dist/index.html`.
- Convert the shell theme button to `md-icon-button` with `md-icon`.
- Convert inspector input controls to Material Web elements where they are
  already bundled: `md-outlined-text-field`, `md-filled-button`,
  `md-outlined-button`, `md-switch`, `md-elevated-card`, `md-list`, and
  `md-list-item`.
- Keep native radio inputs only where the current Material bundle lacks a
  stable replacement in this repo.
- Rework `/inspect` as a responsive two-pane workspace:
  input/settings/books slot on the left, decoded result surface on the right.
- Keep existing decode, provider state, routing, and overlay behavior intact.
- Update Playwright assertions for Material icon rendering and the two-pane
  layout.

### Slice 2 — SPARQL Decoded Structure Tree

- Add typed SPARQL view queries in `RdfShapes.js` that summarize the
  transaction graph into generic tree rows.
- Expose a PureScript row type and query wrapper in `FFI.RdfShapes.purs`.
- Build a generic tree renderer in `Main.purs` from rows rather than bespoke
  field plucking.
- Keep query rows shaped for later book resolution with optional label/type
  bindings, but render raw values in this child.
- Reuse existing expand/collapse state where possible, or add a dedicated
  decoded-tree expansion set if the transaction browser paths conflict.
- Update Playwright coverage to paste the sample Conway fixture, assert the
  decoded tree is sourced from graph/SPARQL, and exercise expand/collapse.
- Keep the existing deployed-subpath spec green and extend it only if a new
  `/inspect` assertion is needed for the tree.

## Owned Files

Slice 1:

- `docs/inspector/dist/index.html`
- `docs/inspector/src/Shell.purs`
- `docs/inspector/src/Main.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

Slice 2:

- `docs/inspector/src/FFI/RdfShapes.js`
- `docs/inspector/src/FFI/RdfShapes.purs`
- `docs/inspector/src/Main.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

## Verification

- Focused during Slice 1: `just ui-check` and the Playwright shell/layout
  tests touched by the slice.
- Focused during Slice 2: `just ui-check` and the Playwright decode/tree tests
  touched by the slice.
- Full PR gate before accepting each implementation commit: `./gate.sh`.
- Mandatory local final proof before `COMPLETE`:
  `nix build .#packages.x86_64-linux.tx-inspector-ui`, `just ui-check`,
  `just test-playwright`, and a browser smoke served under a non-root subpath.
- Preview proof before `COMPLETE`: the PR preview under
  `https://preview.dev.plutimus.com/lambdasistemi/cardano-ledger-inspector/pr-103/inspector/`
  must render `/inspect`, `/settings`, and `/library`, and `/inspect` must
  decode the fixture and show the tree.

## Risks

- The Material Web bundle may not include every desired component. The worker
  should use real `md-*` components that are available and leave narrowly
  justified native controls where needed.
- RDF predicate naming may not expose every CQuisitor section directly. The
  query layer should prefer semantic `cardano:` predicates and gracefully omit
  absent sections rather than synthesizing misleading data.
- Existing `expandedPaths` is used by the JSON browser. If tree paths overlap,
  use a namespaced path prefix or separate state so decoded tree toggles do not
  disturb browser expansion.
