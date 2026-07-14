# Issue 135: Local CI Entry Point

## User Story

As a repository contributor, I need one local command that exercises the same
build and test gate as GitHub Actions, so I can obtain reliable pre-push
evidence without assembling a command list by hand.

## Requirements

- `nix develop --quiet -c just ci` MUST run the required build-gate packages
  and checks, then the per-concern commands that the current GitHub Actions
  workflow requires.
- The local command MUST include the OpenAPI regeneration and Swagger alias
  checks; ledger-smoke checks for identify, witness planning, intent,
  validation, script evaluation, and explicit input context; Extism
  conformance; Fourmolu formatting; HLint; the packaged UI; and Playwright.
- A repository-owned drift guard MUST fail when a flake target required by
  `.github/workflows/ci.yml` is absent from the `just ci` recipe.
- The guard MUST derive its required target set from the workflow rather than
  from a hand-maintained duplicate manifest.
- Contributor documentation MUST name `nix develop --quiet -c just ci` as the
  pre-push command.
- GitHub Actions job structure, artifact preparation, and artifact publication
  MUST remain unchanged.

## Acceptance

- `just ci` exits non-zero when any required package, check, formatter, linter,
  or Playwright suite fails.
- `just check-ci-drift` succeeds for the current workflow and recipe, and a
  controlled temporary copy of the recipe with one required target removed
  makes the guard exit non-zero.
- `nix develop --quiet -c just ci` passes from this clean issue worktree after
  implementation.
- The local command contains every flake target currently invoked by the
  required GitHub Actions jobs, including OpenAPI/Swagger, ledger smokes,
  Extism, formatting, HLint, the packaged UI, and Playwright.

## Non-Goals

- Rewriting the Nix flake or GitHub Actions workflow.
- Changing ledger, browser, or artifact behavior.
- Optimizing build duration or binary-cache policy.
