# Tasks

## Slice 1: Loaded-state rail collapse

- [ ] T121-S1 Add Playwright RED assertions that empty/error states keep the two-pane layout and loaded state collapses the left rail into a slim header with full-width decoded results.
- [ ] T121-S1 Update `Main.purs` presentation to gate on `state.result`, preserving the empty/error two-pane path and rendering a loaded-state header plus full-width result path for `Just _`.
- [ ] T121-S1 Update `styles.css` workspace/header/responsive rules so loaded desktop is full-width and narrow layouts stack without overlap.
- [ ] T121-S1 Run `nix build .#packages.x86_64-linux.tx-inspector-ui`, `just test-playwright`, `just format-check`, and `just hlint`; commit one bisect-safe slice with the required `Tasks: T121-S1` trailer.
