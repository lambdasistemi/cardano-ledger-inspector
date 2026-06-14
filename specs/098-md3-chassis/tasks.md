# Issue 98 Tasks: MD3 Chassis

## Bootstrap

- [X] T000 Create issue worktree, add `gate.sh`, run bootstrap gate, open draft PR.

## Slice A: Material Shell Foundation

- [X] T001 Add route/theme/shell modules for `/inspect`, `/settings`, `/library`.
- [X] T002 Load `material.js` and external `styles.css` from the packaged UI.
- [X] T003 Add route/theme Playwright RED coverage and make it pass.
- [X] T004 Run `./gate.sh`, commit `feat(inspector): add md3 shell foundation`, and stop before push.

## Slice B: Inspector MD3 Reskin

- [ ] T005 Reskin current inspector panels, controls, and result surfaces with MD3 tokens.
- [ ] T006 Preserve provider config, bundled books, decode operations, and flat result order.
- [ ] T007 Extend/adjust Playwright coverage for decoded content under the shell and viewport fit.
- [ ] T008 Run `./gate.sh`, commit `feat(inspector): reskin inspect flow with md3 tokens`, and stop before push.

## Finalization

- [ ] T009 Run final `./gate.sh` and browser smoke on the packaged UI.
- [ ] T010 Update PR #99 body with verification evidence.
- [ ] T011 Drop `gate.sh`, mark PR ready only after local acceptance and CI are green.
