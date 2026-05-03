# Tasks: tx-deep-diagnosis Explain Artifacts

Each task is one bisect-safe commit. Order matters — every commit
compiles and passes tests with no `sorry`-equivalent.

## T1 — `Render.Doc`: parse the envelope

- Add `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Doc.hs`
  with `DiagnosisDoc` and `parseDiagnosisDoc`.
- Wire the new module into `tx-deep-diagnosis.cabal`.

**Acceptance**: `nix build .#tx-deep-diagnosis` succeeds.

## T2 — `Render.Names`: hash → label

- Add `Render/Names.hs` with `PartyName`, `PartySource`,
  `resolveScript`, `resolveAddress`.
- Pure functions reusing `Registry.identifyByHash` and
  `findScopeByOwner`.

**Acceptance**: build green; tests added in T5.

## T3 — `tasty` test suite skeleton

- Add `apps/tx-deep-diagnosis/test/Main.hs` with one trivial passing
  test.
- Add `test-suite tx-deep-diagnosis-test` stanza to the cabal file.
- Wire into `nix/host/tx-deep-diagnosis-native/default.nix` so the
  test executable is buildable via nix.

**Acceptance**: `nix build .#packages.x86_64-linux.tx-deep-diagnosis-test`
succeeds and the test runs.

## T4 — `Render.Parties`: L1 cut

- Add `Render/Parties.hs` exporting `renderPartiesMermaid`.
- Mermaid `flowchart LR`. One node per distinct party (signer hash,
  output payment credential, script bucket).

**Acceptance**: snapshot fixture for `parties.mmd` lands in T6 covering
the SundaeSwap mainnet tx.

## T5 — `Render.ValueFlow`: L2 cut

- Add `Render/ValueFlow.hs` exporting `renderValueFlowTsv`.
- TSV with header `source\ttarget\tlovelace\tlabel`. Empty body when
  inputs are unresolved. No reformatting of decimal strings.

**Acceptance**: snapshot fixture for `value-flow.tsv` lands in T6.

## T6 — `Render.Topology`: L3 cut

- Add `Render/Topology.hs` exporting `renderTopologyMermaid`.
- Mermaid `flowchart TD` of every input, output, reference input,
  collateral, body, and synthetic signer node. Apply failure overlays
  via `classDef` per the mapping in `plan.md`.
- Land all four golden fixtures and unit tests in this commit (the
  tests for T2/T4/T5 ride along, gated on the topology snapshot).

**Acceptance**: `nix run .#tx-explain-render-smoke` is green
(scaffolded in T8).

## T7 — `Render.Failures` + `Render.Summary`

- Add `Render/Failures.hs` exporting `renderFailuresMermaid` (returns
  `Maybe Text`).
- Add `Render/Summary.hs` exporting `renderSummaryMarkdown`. The
  summary's "diagrams" footer links only to files that exist in
  `EmittedFiles`.

**Acceptance**: snapshots include `summary.md` for all four fixtures
and `failures.mmd` for the three invalid ones.

## T8 — CLI flag + emit IO

- Add `Render/Emit.hs` with `emitExplain :: FilePath -> ... -> IO ()`.
- Add `--emit-explain` to `Options` and call `emitExplain` after the
  JSON envelope is written.
- Add `tx-explain-render-smoke = pkgs.runCommand …` in `flake.nix`,
  exposed via `mkApp`. Adds CI Build Gate + per-job step.

**Acceptance**: green CI, `nix run .#tx-explain-render-smoke` passes.

## T9 — Update PR + docs

- Update PR body: motivation (link #54), what changed, file tour per
  module, snapshot strategy, follow-ups.
- Add a short note to `apps/tx-deep-diagnosis/`-level README (or
  inline in `--help`) pointing at the four cuts and the summary.

## Bisect plan

After each commit:

```sh
nix build .#packages.x86_64-linux.tx-deep-diagnosis        # T1, T2, T4-T8
nix build .#packages.x86_64-linux.tx-deep-diagnosis-test   # T3
nix run .#tx-explain-render-smoke                          # T6, T7, T8
```

If a commit fails to build, fix it via `stg goto N && stg refresh` —
never append a fixup commit.
