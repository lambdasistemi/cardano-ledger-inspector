# Plan

## Scope

This is a PureScript/Halogen presentation reorganization in the inspector workbench. The ledger operation calls and all decode/resolution data shapes stay unchanged.

## Implementation Shape

- Extend inspector UI state with a result tab enum and tab-switch action.
- Move `renderDecodedStructure` into the result panel instead of rendering it after the legacy result card.
- Replace the stacked result body with:
  - a compact summary card using existing `tx.inspect`, `tx.intent`, `tx.identify`, `tx.witness.plan`, and `tx.validate` derived data;
  - a tab bar with `Structure`, `Witness`, `Validation`, and `Graph / RDF`;
  - a tab body that renders only the active tab.
- Keep left-pane active chain data, input mode, and Books panel untouched.
- Update CSS for compact result layout, tab controls, bounded tab panels, and scrollable advanced/RDF surfaces.
- Update Playwright helpers and assertions that currently depend on the old standalone identity panel.

## Slices

### Slice 1: Tabbed Tree-Primary Result

Driver owns the behavior and tests in one vertical slice:

- `docs/inspector/src/Main.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

Expected proof:

- A RED Playwright assertion fails against the current stacked layout.
- GREEN implements tabs and layout.
- Focused Playwright checks pass for the result layout and subpath route coverage.
- `nix build .#packages.x86_64-linux.tx-inspector-ui` passes or the driver records a reproducible infrastructure failure.

### Finalization

The ticket orchestrator reviews the implementation commit, marks `tasks.md` in the same commit by amend, pushes, creates/updates the draft PR, and keeps the PR draft until local acceptance, CI, and preview smoke are verified.
