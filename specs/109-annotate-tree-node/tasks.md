# Tasks

## Bootstrap

- [X] T109-B Create the #109 worktree, branch, gate, spec, plan, task contract, and draft PR.

## Slice 1 - Decoded-Tree Annotation Flow

- [X] T109-S1 Add Playwright RED coverage for labeling an opaque decoded-tree node from a genuine fixture.
- [X] T109-S1 Infer annotation predicates and values from decoded-tree row data without protocol-specific branching.
- [X] T109-S1 Add the per-row `Label this as...` flow for label, optional type, existing-book selection, and inline new-book creation.
- [X] T109-S1 Append parseable Turtle to the chosen/new local book through the #106 store shape.
- [X] T109-S1 Recompute merged RDF lenses immediately so the row resolves without manual reload or apply.
- [X] T109-S1 Prove export/import round-trip preserves the generated book annotation.
- [X] T109-S1 Keep the non-root subpath `/inspect`, `/settings`, and `/library` route spec green.
- [X] T109-S1 Run `./gate.sh` and commit `feat(inspector): label decoded tree nodes into books`.

## Finalization - Orchestrator Owned

- [X] T109-F1 Review the slice diff, commit message, and task trailer; amend this task file into the accepted slice commit.
- [ ] T109-F2 Push the branch and verify CI is green.
- [ ] T109-F3 Verify the PR preview under `/inspector/`: label a node, observe immediate resolution, and export/import the generated book.
- [ ] T109-F4 Update PR body with delivered behavior and proof, then leave the PR draft for epic-owner review.
