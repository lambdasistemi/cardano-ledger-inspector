# Plan

## Current Gap

The existing inspect page still reads as a Material dashboard: a descriptive intro strip, separate card stack on the left, result heading plus summary metrics before the structure, and a teal-accent MD3 skin. CQuisitor is much flatter and denser: a 51px tool header, right-aligned mode tabs, hard 50/50 panes, uppercase labels, thin borders, low elevation, and a decoded-structure pane that owns the right half.

Reference artifacts captured from the live site are stored outside git at:

- `/tmp/epic-113/clins-119/reference/cquisitor-working-surface-1440.png`
- `/tmp/epic-113/clins-119/reference/cquisitor-working-surface-snapshot.md`

## Slice

One presentation slice is appropriate because the acceptance surface is one coherent visual change and the touched files already share Playwright coverage.

### Slice 1: CQuisitor-style inspect presentation

Owned files:

- `docs/inspector/src/Main.purs`
- `docs/inspector/src/Shell.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

Work:

- Rework `/inspect` desktop hierarchy into a hard left/right tool surface with a clear divider.
- Remove the result summary/metrics hero above the decoded structure; keep identity only as compact secondary metadata or in existing lower-detail contexts.
- Make decoded structure the dominant right-pane default after decode and keep Witness, Validation, and Graph/RDF secondary behind tabs.
- Re-skin the shell and MD3 tokens toward CQuisitor: neutral blue-gray page, white surfaces, thin borders, small uppercase labels, tighter spacing, low/no shadow, compact buttons/tabs.
- Adjust top nav to read as mode tabs with Inspect primary and Settings/Library secondary compact links.
- Strengthen Playwright assertions for no identity hero above tree, two-pane proportions, tree dominance, compact labels, and subpath behavior.

Focused proof:

- `just test-playwright`
- `nix build .#packages.x86_64-linux.tx-inspector-ui`
- `./gate.sh`
- Browser smoke on `/inspect` with `conway-mainnet-tx.hex`, screenshot compared against the CQuisitor reference.

## Risks

- Existing tests still expect the old identity summary in a few flows. Update those expectations without weakening coverage of copy/open/identity availability.
- PureScript formatting may be sensitive after render tree changes; run `just format-check` through the gate.
- The CSS file is committed source for this app; do not introduce generated-only changes outside the owned stylesheet.
