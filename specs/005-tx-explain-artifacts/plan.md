# Implementation Plan: tx-deep-diagnosis Explain Artifacts

**Branch**: `feat/issue-54-explain-artifacts`
**Spec**: [spec.md](spec.md)
**Issue**: #54

## Decision: extend the host CLI, not the ledger op

The renderers consume only the existing `tx-deep-diagnosis` envelope plus
the `ProtocolRegistry`. Putting them in the host CLI keeps the ledger
functional API surface untouched and avoids re-running the ledger to
produce display-only artifacts. No new `tx.explain` op.

## Decision: cuts at different heights, not one mega-graph

A single Mermaid diagram of every input/output/reference/collateral
plus signers is unreadable beyond ~20 nodes and Mermaid's auto-layout
breaks. The renderer emits a directory of cuts:

- **L1 parties (`parties.mmd`)** — Mermaid `flowchart LR`, ~4–8 nodes
- **L2 value flow (`value-flow.tsv`)** — Sankey TSV
- **L3 topology (`topology.mmd`)** — Mermaid `flowchart TD`, full graph
- **L4 failures (`failures.mmd`)** — Mermaid, only when invalid
- **`summary.md`** — prose, links to the cuts above

## Module layout

Add to `apps/tx-deep-diagnosis/src/`:

- `TxDeepDiagnosisHost.Render.Doc`
  - `data DiagnosisDoc = DiagnosisDoc { ddSummary :: !Text, ddIntent :: !Value, ddValidate :: !Value }`
  - `parseDiagnosisDoc :: Value -> Either String DiagnosisDoc`

- `TxDeepDiagnosisHost.Render.Names`
  - `data PartyName = PartyName { pnLabel :: !Text, pnSource :: !PartySource }`
  - `data PartySource = FromValidator | FromInstance | FromAmaruScope | TruncatedHex`
  - `resolveScript :: ProtocolRegistry -> Text -> PartyName`
  - `resolveAddress :: ProtocolRegistry -> Text -> PartyName`

- `TxDeepDiagnosisHost.Render.Parties`
  - `renderPartiesMermaid :: ProtocolRegistry -> DiagnosisDoc -> Text`

- `TxDeepDiagnosisHost.Render.ValueFlow`
  - `renderValueFlowTsv :: ProtocolRegistry -> DiagnosisDoc -> Text`
    Header row `source\ttarget\tlovelace\tlabel`. Rows derived from
    `intent.value.resolved_input_buckets[]` and
    `intent.value.output_buckets[]`. When inputs are unresolved, only
    the header is emitted (deterministic empty Sankey).

- `TxDeepDiagnosisHost.Render.Topology`
  - `renderTopologyMermaid :: ProtocolRegistry -> DiagnosisDoc -> Text`
    Full per-node graph; failures applied as `classDef` overlays.

- `TxDeepDiagnosisHost.Render.Failures`
  - `renderFailuresMermaid :: ProtocolRegistry -> DiagnosisDoc -> Maybe Text`
    Returns `Nothing` when `validation.failures[]` is empty so the
    caller knows not to write the file.

- `TxDeepDiagnosisHost.Render.Summary`
  - `data EmittedFiles = EmittedFiles { efParties :: !FilePath, efValueFlow :: !FilePath, efTopology :: !FilePath, efFailures :: !(Maybe FilePath) }`
  - `renderSummaryMarkdown :: ProtocolRegistry -> DiagnosisDoc -> EmittedFiles -> Text`
    Sections: title, verdict paragraph, claims table, effects table,
    signer perspective table, failures table, warnings, diagrams
    footer. Links use the relative file names in `EmittedFiles`.

- `TxDeepDiagnosisHost.Render.Emit` (Main.hs glue, IO)
  - `emitExplain :: FilePath -> ProtocolRegistry -> DiagnosisDoc -> IO ()`
    Creates the directory, writes the four/five files, picks
    `summary.md` last so its link list reflects what was actually
    written.

The renderer subgraph under `TxDeepDiagnosisHost.Render.*` is pure —
nothing in it imports `System.IO`. Only `Render.Emit` does IO.

## CLI surface

Add to `Options`:

```haskell
, optEmitExplain :: !(Maybe FilePath)
```

After the existing JSON envelope is written to stdout, if the option is
set, parse the in-memory `Value` we already have, call `emitExplain`.

Help text:

```
--emit-explain DIR
    Write a directory of human-readable artifacts: summary.md,
    parties.mmd, value-flow.tsv, topology.mmd, and failures.mmd
    (when the tx is invalid). Existing files are overwritten.
```

## Failure overlay mapping

Match on `validate.result.validation.failures[].rule` + the failure
substring. Applies in `Render.Topology` (for L3 overlay) and in
`Render.Failures` (for the standalone L4 cut):

| Source                                    | Diagram target            | Class       |
|-------------------------------------------|---------------------------|-------------|
| `UTXOW` / `ValueNotConservedUTxO`         | body                      | `bodyFail`  |
| `UTXOW` / `MissingVKeyWitnessesUTXOW`     | one synthetic signer node | `signerFail`|
| `UTXOW` / `BadInputsUTxO`                 | matching input            | `inputFail` |
| `UTXOW` / `OutsideValidityIntervalUTxO`   | body                      | `bodyFail`  |
| anything else under `UTXOW`               | body                      | `bodyFail`  |
| any other rule                            | body                      | `bodyFail`  |

## Snapshot tests

Test suite under `apps/tx-deep-diagnosis/test/`:

```
apps/tx-deep-diagnosis/
├── test/
│   ├── Main.hs                  -- tasty entrypoint
│   └── golden/
│       ├── passing/             -- input.json + expected/{summary.md, parties.mmd, value-flow.tsv, topology.mmd}
│       ├── value-not-conserved/ -- ... + expected/failures.mmd
│       ├── missing-witness/
│       └── multi-redeemer/
└── tx-deep-diagnosis.cabal      -- adds test-suite stanza
```

Use `tasty` + a hand-rolled byte-equality assertion. Each test loads
`input.json`, runs the renderers, and compares each file to its
counterpart under `expected/`. Mismatch prints a unified diff.

For the parties registry, the tests load the bundled
`docs/inspector/protocols` registry just like the binary does, via
`Paths_tx_deep_diagnosis.getDataDir`.

## Nix check

Add `tx-explain-render-smoke` to `flake.nix`, run the test executable,
expose an app wrapper, wire to CI Build Gate + a per-job step mirroring
`tx-intent-smoke`.

## Determinism

- All `Map`/`Set` traversals over JSON: drive layout from
  `Vector`/list order in the JSON, not from key-set hashing.
- Lovelace and decimal numbers are reproduced from the JSON strings as-is
  — never reparsed and reformatted.
- No timestamps or random IDs in the output.
- File write order: parties → value-flow → topology → failures →
  summary. Summary is last so its link list reflects which files
  exist.

## Out of scope (this PR)

- Surge preview render integration (the artifacts can be added later to
  the static site).
- D2 / Graphviz alternative backends.
- Cross-checking metadata claims against destinations.

## Risks

- Mermaid diagrams beyond ~30 nodes get hard to read. Mitigated by the
  cut design — only `topology.mmd` approaches that size.
- Generic instance labels (`"SundaeSwap V3 Treasury"` for many distinct
  treasuries). Mitigation: append the last 6 hex of the hash to
  instance-derived labels so distinct instances remain
  distinguishable.

## Open follow-ups (separate tickets)

- D2 backend swap if any cut looks bad on a real fixture.
- Wire the rendered artifacts into the docs build so the site shows the
  diagrams for the bundled fixture.
- A small fixtures-bumping helper to make snapshot regeneration safe.
