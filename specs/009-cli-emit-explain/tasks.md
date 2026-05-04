# Tasks: tx-deep-diagnosis Runtime --emit-explain

**Input**: Design documents from `/specs/009-cli-emit-explain/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: Included because this slice restores a promised CLI contract and
must keep runtime and snapshot behavior aligned.

## Phase 1: Shared emitter

- [X] T001 Add a reusable explain-artifact emitter module under `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/`
- [X] T002 Refactor the snapshot harness to consume the shared emitter instead of owning the artifact ordering locally
- [X] T003 Expose any report-envelope helper needed so runtime emission can parse the in-memory diagnosis document without re-reading stdout

## Phase 2: Runtime CLI

- [X] T004 Add `--emit-explain DIR` to `apps/tx-deep-diagnosis/app/Main.hs`
- [X] T005 Write explain artifacts after stdout JSON emission when the flag is present
- [X] T006 Remove stale known artifact files that are not rendered for the current transaction

## Phase 3: Verification and docs

- [X] T007 Add a Nix smoke check for `tx-deep-diagnosis --emit-explain`
- [X] T008 Update CLI/tutorial docs in `gh-docs/build.md` to document the one-shot explain flow
- [X] T009 Run `nix build .#checks.x86_64-linux.tx-explain-render-smoke`
- [X] T010 Run `nix build .#checks.x86_64-linux.tx-deep-diagnosis-emit-explain-smoke`
- [X] T011 Run `just format-check`
