# Tasks: tx-deep-diagnosis Explain Artifacts

Each task is one bisect-safe commit. Order matters — every commit
compiles and passes tests with no `sorry`-equivalent.

## T1 — `Render.Doc`: parse the envelope

- Add `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Doc.hs`
  with `DiagnosisDoc` and `parseDiagnosisDoc`. Expose nothing else yet.
- Wire the new module into `tx-deep-diagnosis.cabal`.
- No callers; the build proves the module compiles.

**Acceptance**: `nix build .#tx-deep-diagnosis` succeeds.

## T2 — `Render.Names`: hash → label

- Add `Render/Names.hs` with `PartyName`, `PartySource`,
  `resolveScript`, `resolveAddress`.
- Pure functions. Reuse `TxDeepDiagnosisHost.Registry.identifyByHash`
  and `findScopeByOwner` (no new IO).
- Unit tests: a tiny `test/Spec/Names.hs` covers
  hit-via-validator, hit-via-instance, hit-via-amaru-scope, miss with
  truncation. Tests run inside the existing project, no new test
  dependencies — use the `tasty` entrypoint introduced in T5.

**Acceptance**: name resolution covered by tests; build is green.

## T3 — `Render.Report`: markdown report

- Add `Render/Report.hs` with `renderMarkdown`.
- Render: title, subtitle, claims table, effects table, signer
  perspective table, validation verdict + failures table, warnings.
- Drive layout from `intent.sections[]` rows where present so wording
  stays in sync with the inspector library.

**Acceptance**: snapshot test (T6) passes for the passing-tx fixture.

## T4 — `Render.Diagram`: mermaid diagram

- Add `Render/Diagram.hs` with `DiagramOptions`, `defaultDiagramOptions`,
  `renderMermaid`.
- Emit a `flowchart TD` document. Include classDef styles for
  `bodyFail`, `signerFail`, `inputFail`. Apply via the failure mapping
  in `plan.md`.

**Acceptance**: snapshot tests (T6) pass for all four fixtures.

## T5 — `tasty` test suite skeleton

- Add `apps/tx-deep-diagnosis/test/Main.hs` (tasty entrypoint).
- Add `test-suite tx-deep-diagnosis-test` stanza to the cabal file.
- Wire into nix via `nix/host/tx-deep-diagnosis-native/default.nix`.
- Test suite is initially empty (one trivial passing test) so the
  scaffold lands separately from the snapshot fixtures.

**Acceptance**: `nix build .#packages.x86_64-linux.tx-deep-diagnosis-test`
succeeds and the test runs.

## T6 — Snapshot fixtures + golden tests

- Commit four fixture envelopes under `apps/tx-deep-diagnosis/test/golden/`:
  - `passing/input.json` — a minimal passing tx (synthesised; no
    network calls). Output expectations: empty failures, no overlays.
  - `value-not-conserved/input.json` — derived from the user's
    `result.json` (the SundaeSwap/USDM mainnet tx).
  - `missing-witness/input.json` — derived from the same tx (single
    fixture covers both via the failures it carries).
  - `multi-redeemer/input.json` — same tx; the report exercises the
    multi-redeemer rendering.
- For each, commit `diagram.mmd` and `report.md` snapshots.
- Test suite reads `input.json`, runs renderers, asserts byte equality
  against `diagram.mmd` / `report.md`. On mismatch, print a unified diff.

**Acceptance**: `nix run .#tx-explain-render-smoke` is green.

## T7 — CLI flags

- Add `--emit-mermaid` and `--emit-report` to `Options`.
- After the JSON envelope is printed to stdout, if either flag is set,
  parse the in-memory envelope and write the artifact to disk.
- Help text quotes the spec's behaviour.

**Acceptance**: integration test in `Main.hs` (or a separate smoke)
runs the binary with both flags and inspects the produced files exist
and match the snapshots.

## T8 — Nix check `tx-explain-render-smoke`

- Add `tx-explain-render-smoke = pkgs.runCommand …` to `flake.nix`.
- Expose as `apps/x86_64-linux/tx-explain-render-smoke` (mkApp).
- Add to the `Build Gate` job and create a per-job CI step mirroring
  `tx-intent-smoke`.

**Acceptance**: `nix run .#tx-explain-render-smoke` exits 0 locally;
green CI.

## T9 — Update issue + PR

- Update PR body with: motivation (link #54), what changed, file tour
  per module, snapshot strategy, follow-ups.
- Add `enhancement` label, assign to `paolino`.

## Bisect plan

After each commit:

```sh
nix build .#packages.x86_64-linux.tx-deep-diagnosis    # T1, T2, T3, T4, T7
nix build .#packages.x86_64-linux.tx-deep-diagnosis-test  # T5
nix run .#tx-explain-render-smoke                       # T6, T8
```

If a commit fails to build, fix it via `stg goto N && stg refresh` —
never append a fixup commit.
