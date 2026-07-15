# Tasks: Slim the inspector to an engine repo

**Input**: [spec.md](spec.md), [plan.md](plan.md)
**Gate**: `./gate.sh`
**Strategy**: redirect-first, then one coherent engine-slimming commit.

## Slice 1 — Publish and prove the workbench redirect

**Goal**: Make the former Pages workbench route hand off to the already-live
csk workbench before deleting any UI source.

- [ ] T001-S1 Verify the live csk Pages root returns the transaction workbench;
  add `gh-docs/inspector/index.html` with automatic redirect, canonical URL,
  and clickable fallback all targeting the exact live root.
- [ ] T002-S1 Change the Pages workflow and `just build-pages-site` to publish
  strict MkDocs + `/inspector/` redirect + OpenAPI without building/copying the
  UI, while retaining the old UI source and non-Pages checks until slice 2.
- [ ] T003-S1 Build and inspect the Pages artifact, prove docs/redirect/OpenAPI,
  run the unchanged `./gate.sh`, and commit
  `docs(pages): redirect inspector to csk workbench` with
  `Tasks: T001, T002, T003`.

## Slice 2 — Remove the UI and expose only engine surfaces

**Goal**: Delete the browser implementation and every UI-only build/test/CI
surface while keeping the engine, registry, release contract, and downstream
flake interface unchanged.

- [ ] T004-S2 Delete every non-registry child of `docs/inspector/`, the UI-only
  PureScript RDF editor package, `tools/ux-judge`, the UI fixture generator,
  and `nix/wasm-ui.nix`; prove `docs/inspector/protocols/` is byte-identical.
- [ ] T005-S2 Remove UI-only flake inputs, lock nodes, derivation, package/app,
  and dev-shell tools; make `wasm-tx-inspector` the default package without
  changing any preserved named engine output.
- [ ] T006-S2 Remove UI build/artifact and Playwright from CI, delete the UI PR
  preview workflow, and keep the release-assets workflow byte-identical.
- [ ] T007-S2 Prune UI-only Just recipes, align the CI entry point and gate to
  the complete engine check set, and keep strict docs/redirect/OpenAPI proof in
  the gate.
- [ ] T008-S2 Rewrite README, architecture, build/installation/overview docs,
  AGENTS, and the repository guide skill to describe the engine-only scope and
  direct browser users to the csk workbench.
- [ ] T009-S2 Run the full engine gate; compare pre/post store paths for
  `wasm-tx-inspector` and `protocol-registry`; verify registry drift, preserved
  flake names, redirect artifact, and unchanged release workflow; commit
  `refactor: slim inspector to engine surfaces` with
  `Tasks: T004, T005, T006, T007, T008, T009`.

## Dependencies and Scope Guard

T001–T003 must be accepted and pushed before T004 begins. `docs/inspector/protocols/**`,
`.github/workflows/release-assets.yml`, ledger/CLI source, contracts, schemas,
fixtures, and engine dependency hashes are forbidden throughout. Any need to
change those surfaces is a Q-file blocker, not an implementation choice.
