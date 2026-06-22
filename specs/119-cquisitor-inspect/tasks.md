# Tasks

## Slice 1: CQuisitor-style inspect presentation

- [X] T119-S1 Add Playwright RED assertions for CQuisitor-like `/inspect`: hard two-pane, visible divider, compact labels, decoded tree dominant, no identity/metrics hero above the tree, and subpath preservation.
- [X] T119-S1 Rework `Main.purs` presentation so `/inspect` leads with compact config/input left and decoded structure right, keeping result detail secondary and behavior unchanged.
- [X] T119-S1 Rework `Shell.purs` topbar into compact tool/mode-tab navigation with Settings/Library visually secondary.
- [X] T119-S1 Re-skin `styles.css` to flat/compact/neutral MD3-compatible tokens and CQuisitor-like pane density.
- [X] T119-S1 Run focused Playwright, UI build, `./gate.sh`, then commit one bisect-safe slice with the required `Tasks: T119-S1` trailer.
