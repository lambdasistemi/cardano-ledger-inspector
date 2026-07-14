# Tasks

## Slice 1: Loaded hierarchy and visual regression

- [X] T136 Remove the duplicate full Resolution books card only from the
  successful decoded loaded state, retaining the header's compact book summary
  and controls.
- [X] T137 Update the CQuisitor Playwright scenario to prove the decoded state
  exposes one books summary/control surface and no full Resolution books card.
- [X] T138 Add laptop (1024×768) and mobile (390×844) first-viewport checks
  for result tabs and the Structure/Decoded transaction heading, while keeping
  the Change input, re-decode, Library, and Apply books checks.
- [X] T139 Run the focused Playwright regression, `./gate.sh`, and
  `nix develop --quiet -c just ci`, recording RED/GREEN and screenshot/capture
  evidence in `WIP.md`.

## Commit Contract

One reviewed, bisect-safe commit:

```text
fix(inspector): restore loaded result hierarchy

Tasks: T136, T137, T138, T139
```

The ticket orchestrator will mark all four tasks complete by amending that
reviewed commit before pushing it.
