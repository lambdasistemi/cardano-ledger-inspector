# Implementation Plan: Slim the inspector to an engine repo

**Branch**: `refactor/150-slim-to-engine-repo` | **Date**: 2026-07-15 | **Spec**: [spec.md](spec.md)

## Summary

Establish the exact csk workbench as the replacement surface, convert the
inspector Pages route to a static redirect, then remove the old UI as one
coherent engine-slimming slice. Preserve every named engine output consumed by
csk, the protocol registry bytes and path, release assets, public operation
contract, and CLI behavior.

## Technical Context

**Languages/tools**: Nix flakes/lock, GitHub Actions YAML, Just, MkDocs,
static HTML, Markdown, Haskell engine checks.

**Replacement surface**:
`https://lambdasistemi.github.io/cardano-swiss-knife/` (live HTTP 200; page
title “Cardano transaction inspector”, verified 2026-07-15).

**Preserved engine surfaces**:

- `packages.<system>.wasm-tx-inspector`
- `packages.<system>.protocol-registry`
- `checks.<system>.protocol-registry-drift-check`
- WASI/Extism packages and byte-conformance checks
- native `tx-deep-diagnosis` packages/checks
- OpenAPI/Swagger packages and checks
- `.github/workflows/release-assets.yml`
- `docs/inspector/protocols/` at its current path

**Removed UI surfaces**:

- every tracked child of `docs/inspector/` except `protocols/`
- `packages/purescript-rdf-editor/`
- `nix/wasm-ui.nix`
- `tools/ux-judge/` and `tools/gen-broken-examples.py`
- UI-only flake inputs, package/app, dev-shell dependencies, and lock nodes
- UI Just recipes, Playwright invocation, CI artifact/job, and PR preview

## Baseline Evidence

At `origin/main` `df8385f7f9b4da8fe493991254d214e317a30ece`:

- `./gate.sh` exits 0 (PureScript compile/package, focused Playwright smoke,
  protocol registry package and drift check).
- `wasm-tx-inspector` store path:
  `/nix/store/0cjyzliiks3h6bcs5v7ccylhmi77m8v0-cardano-ledger-wasm-0.1.0`
- `protocol-registry` store path:
  `/nix/store/663khr1cngprvdy2rn0b4cv1lygws1ik-protocol-registry`
- `release-assets.yml` SHA-256:
  `4d36451a49eeeaf3c504ff56c82110218db57d67dbc62a1d65667f88e0decb50`

## Slice Plan

### Slice 1 — Publish and prove the workbench redirect

Create `gh-docs/inspector/index.html` as a static redirect with canonical and
fallback links to the exact live csk Pages root. Change the Pages workflow and
`just build-pages-site` so the Pages artifact is docs + redirect + OpenAPI and
does not build/copy the old UI. Keep the old UI source, package, CI, and gate
temporarily intact so this commit proves replacement before deletion.

Owned files:

- `gh-docs/inspector/index.html` (new)
- `.github/workflows/pages.yml`
- `justfile`

Proof:

- `curl -fsSL https://lambdasistemi.github.io/cardano-swiss-knife/`
- `just build-pages-site`
- inspect `_site/inspector/index.html` for the exact target and fallback
- `_site/openapi/cardano-ledger-functional.openapi.json` exists
- existing `./gate.sh` exits 0

Commit: `docs(pages): redirect inspector to csk workbench`
with `Tasks: T001, T002, T003`.

### Slice 2 — Remove the UI and expose only engine surfaces

Delete the full UI implementation/test/tool chain while preserving the
protocol registry subtree exactly. Remove UI-only flake inputs and outputs,
regenerate `flake.lock`, make `wasm-tx-inspector` the default engine package,
remove UI/Playwright/preview CI, and prune/rebuild `just` and `gate.sh` around
engine checks. Rewrite current README, MkDocs pages, AGENTS, and the repository
guide skill to explain the engine boundary and link product users to csk.

Owned files:

- `docs/inspector/**` except `docs/inspector/protocols/**` (deletions only)
- `packages/purescript-rdf-editor/**` (deletion)
- `tools/ux-judge/**` and `tools/gen-broken-examples.py` (deletion)
- `nix/wasm-ui.nix` (deletion)
- `flake.nix`, `flake.lock`, `justfile`, `gate.sh`
- `.github/workflows/ci.yml`, `.github/workflows/pr-preview.yml` (delete preview)
- `README.md`, `AGENTS.md`, `skills/cardano-ledger-inspector-guide/SKILL.md`
- `gh-docs/index.md`, `gh-docs/architecture.md`, `gh-docs/build.md`,
  `gh-docs/installation.md`, and any current non-historical documentation
  whose UI claims would otherwise become false

Forbidden files/surfaces:

- `docs/inspector/protocols/**`
- `.github/workflows/release-assets.yml`
- `libs/**`, `apps/**`, ledger contracts/schemas/fixtures, dependency hashes
- engine output names consumed by csk

Proof:

- RED is structural: before the slice, UI-only files and flake/CI names exist;
  after GREEN, scoped absence assertions pass while protocols remain.
- `./gate.sh` runs the engine CI entry point, strict Pages build, operation
  smokes, Extism conformance, OpenAPI, format/lint, native checks, registry
  drift, and `git diff --check` without UI dependencies.
- `nix build --no-link --print-out-paths` for `wasm-tx-inspector` and
  `protocol-registry` equals the baseline paths above.
- `sha256sum .github/workflows/release-assets.yml` equals the baseline.
- `nix flake show` retains every preserved named surface and omits UI-only
  surfaces.

Commit: `refactor: slim inspector to engine surfaces`
with `Tasks: T004, T005, T006, T007, T008, T009`.

## Bisect Safety and Ordering

Slice 1 changes publication only and proves the replacement before any source
deletion. Slice 2 is deliberately one vertical deletion commit: source,
packaging, CI, gate, and current documentation move together so no commit has a
missing package referenced by an active build or presents the deleted UI as a
current repository capability.

