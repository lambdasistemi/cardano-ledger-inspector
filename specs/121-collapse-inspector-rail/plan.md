# Plan

## Current Gap

Issue #119 made `/inspect` CQuisitor-like by giving input and decoded structure a compact two-pane workspace. Issue #121 narrows that behavior: the two-pane layout is still right for empty/error states, but after a successful decode the permanent left rail wastes space. The loaded transaction should read like a tool surface where the result is primary and input/config/book controls collapse into a slim, reachable header.

Live CQuisitor reference captured outside git:

- `/tmp/ux121/clins-121/cquisitor-ready.png`

Observed direction: CQuisitor keeps control surfaces compact and modal/header-like so the working output dominates rather than sharing width with a persistent rail.

## Slice

One vertical presentation slice is appropriate because the state gate, CSS layout, and Playwright coverage are one coherent UX behavior.

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

## Risks

- Existing CQuisitor layout tests currently assert the loaded pane stays 50/50; those must become the RED assertions for this ticket rather than being weakened.
- The header must expose real context without inventing new data dependencies; prefer existing state/result helpers.
- The CSS file is committed source in this app, so style changes must be reviewed like normal source rather than treated as generated output.
