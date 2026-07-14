# Plan

## Context

The workflow currently has a `build-gate` job that builds every required
package and check, followed by twelve per-concern jobs that run the OpenAPI,
Swagger, ledger-smoke, Extism, format, HLint, and Playwright entry points.
The repository has individual `just` recipes, but no one local command that
matches that gate.

## Design

One vertical slice will add a `just ci` recipe and a small shell drift
guard. The recipe will first run the guard, then invoke the same flake targets
as the workflow: its complete multi-target `nix build` gate and each required
`nix run` command. It will not reproduce CI-only artifact copying or upload.

`scripts/check-ci-entry-point.sh` will extract `.#…` flake target references
from `.github/workflows/ci.yml` and from only the `ci` recipe body in
`justfile`, ignoring comments. It will compare the two sorted sets and fail
with the missing or extra targets when they differ. Optional environment
variables will let the focused negative proof supply a temporary justfile;
normal invocation uses repository paths.

This compares executable flake target surfaces rather than job-name comments:
deleting a command that covers a required CI surface removes its target from
the local set and makes the guard fail. A future workflow target change likewise
fails locally until `just ci` is updated deliberately.

## Slice 1: Local CI Gate and Drift Guard

Owned files:

- `justfile`
- `scripts/check-ci-entry-point.sh`
- `README.md`

Implementation shape:

- Add `check-ci-drift` and `ci` recipes. The `ci` recipe runs the guard first,
  builds the existing GitHub Actions multi-target gate, and invokes every
  required post-build flake app.
- Add the executable guard script. It must report set differences and exit
  non-zero on drift; it must not edit workflow files or create artifacts.
- Document the pre-push command in the Development section of `README.md`.

## Verification

Focused proof:

- `just check-ci-drift`
- Copy `justfile` to a temporary path, remove the Extism smoke target, then
  run the guard against that copy and observe a non-zero exit.

There is no existing unit-test harness for justfile/shell orchestration, so the
driver may record a RED-skip rationale. The controlled negative invocation is
the required regression proof and must be reviewed by the navigator before
GREEN acceptance.

Final proof:

- `nix develop --quiet -c just ci`
- `./gate.sh`

The second command deliberately re-runs the full local gate after preserving
the pre-existing focused UI proof in `gate.sh`.
