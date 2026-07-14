# Tasks

## Slice 1: Local CI Gate and Drift Guard

- [ ] T001 Add the `just ci` and `check-ci-drift` recipes in `justfile`, covering every executable flake target required by `.github/workflows/ci.yml`.
- [ ] T002 Add `scripts/check-ci-entry-point.sh` to compare the workflow and local-CI target sets, with a non-zero drift failure and a controlled negative proof.
- [ ] T003 Update `README.md` to name `nix develop --quiet -c just ci` as the contributor pre-push command.
- [ ] T004 Run the focused success and temporary-drift checks, then `nix develop --quiet -c just ci` and `./gate.sh`; record RED-skip rationale and GREEN evidence in `WIP.md`.

## Commit Contract

One reviewed, bisect-safe commit:

```text
ci: add local CI entry point

Tasks: T001, T002, T003, T004
```

The ticket orchestrator will mark all four tasks complete by amending that
reviewed commit before pushing it.
