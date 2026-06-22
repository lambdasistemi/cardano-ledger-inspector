# Tasks

## Slice 1 - Tabbed Tree-Primary Result

- [X] T114-S1 Add focused Playwright RED coverage for default `Structure` tab, bounded result height, tab reachability, and subpath decode.
- [X] T114-S1 Implement tab state/actions and render result as summary plus tabbed panels with decoded structure as the default.
- [X] T114-S1 Update CSS so the result lands compactly and advanced panels scroll inside their tab instead of stacking the page.
- [X] T114-S1 Run focused Playwright checks and `nix build .#packages.x86_64-linux.tx-inspector-ui`.
- [X] T114-S1 Commit one bisect-safe slice with the required `Tasks: T114-S1` trailer.

## Finalization

- [ ] T114-F1 Orchestrator review: verify diff scope, commit trailer, local gate, and task amendment.
- [ ] T114-F2 Push branch and open/update draft PR linked to #114 and #113.
- [ ] T114-F3 Verify CI and preview smoke before reporting COMPLETE.
