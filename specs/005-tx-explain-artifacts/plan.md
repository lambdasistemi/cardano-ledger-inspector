# Implementation Plan: tx-deep-diagnosis Explain Artifacts

**Branch**: `feat/issue-54-explain-artifacts`
**Spec**: [spec.md](spec.md)
**Issue**: #54

## Decision: extend the host CLI, not the ledger op

The renderers consume only the existing `tx-deep-diagnosis` envelope plus
the `ProtocolRegistry`. Putting them in the host CLI keeps the ledger
functional API surface untouched and avoids re-running the ledger to
produce display-only artifacts. No new `tx.explain` op.

## Module layout

Add to `apps/tx-deep-diagnosis/src/`:

- `TxDeepDiagnosisHost.Render.Names`
  - `data PartyName = PartyName { pnLabel :: !Text, pnSource :: !PartySource }`
  - `data PartySource = FromValidator | FromInstance | FromAmaruScope | TruncatedHex`
  - `resolveScript :: ProtocolRegistry -> Text -> PartyName`
    Looks up a script hash in `prValidators`, then `prInstances`, then
    `prAmaru` scope owners. Falls back to `first8…last8` truncation.
  - `resolveAddress :: ProtocolRegistry -> Text -> PartyName`
    Same, given an address-hex; extracts the payment-script-hash byte
    range and delegates to `resolveScript`. Key-only addresses get
    truncated hex with `pnSource = TruncatedHex`.

- `TxDeepDiagnosisHost.Render.Diagram`
  - `data DiagramOptions = DiagramOptions { dShowReferenceInputs :: !Bool, dShowCollateral :: !Bool }`
  - `defaultDiagramOptions :: DiagramOptions`
  - `renderMermaid :: DiagramOptions -> ProtocolRegistry -> DiagnosisDoc -> Text`
  - One `flowchart TD` document. Nodes are addressed by stable string
    IDs derived from JSON paths (e.g. `inN`, `outN`, `refN`, `body`,
    `signerN`). Validation failures are encoded as a `classDef failure`
    applied to the affected node IDs.

- `TxDeepDiagnosisHost.Render.Report`
  - `renderMarkdown :: ProtocolRegistry -> DiagnosisDoc -> Text`
  - Sections in fixed order so output is diffable.

- `TxDeepDiagnosisHost.Render.Doc`
  - `data DiagnosisDoc = DiagnosisDoc { ddSummary :: !Text, ddIntent :: !Value, ddValidate :: !Value }`
  - `parseDiagnosisDoc :: Value -> Either String DiagnosisDoc`
    Pulls the `tx-deep-diagnosis` object from the wrapped envelope.

The four modules form a small subgraph under
`TxDeepDiagnosisHost.Render.*`. Each exposes pure functions; nothing in
this subgraph uses `IO`.

Rename the existing `TxDeepDiagnosisHost.Report` to keep its meaning
clear (it renders the JSON envelope, not the markdown). Two options:

- (A) Leave `Report` alone (it renders the JSON envelope) and put the
  markdown emitter in `Render.Report`. Slightly confusing but minimal
  diff.
- (B) Rename `Report` → `Envelope`. Cleaner names but a churn commit.

Choose (A) for now; if the names get confusing during implementation,
revisit in a follow-up rename commit.

## CLI surface

Add to `Options`:

```haskell
, optEmitMermaid :: !(Maybe FilePath)
, optEmitReport  :: !(Maybe FilePath)
```

After the existing JSON envelope is written to stdout, if either option
is set, parse the in-memory `Value` we already have, render, and write
to the target path. No re-encoding round-trip.

## Failure overlay mapping

Match on `validate.result.validation.failures[].rule` + `kind`:

| Source                                    | Diagram target            | Class       |
|-------------------------------------------|---------------------------|-------------|
| `UTXOW` / `ValueNotConservedUTxO`         | body                      | `bodyFail`  |
| `UTXOW` / `MissingVKeyWitnessesUTXOW`     | one synthetic signer node | `signerFail`|
| `UTXOW` / `BadInputsUTxO`                 | matching input            | `inputFail` |
| `UTXOW` / `OutsideValidityIntervalUTxO`   | body                      | `bodyFail`  |
| anything else under `UTXOW`               | body                      | `bodyFail`  |
| any other rule                            | body                      | `bodyFail`  |

Unmapped failures still reach the user via the report's failure table.

## Snapshot tests

Test suite under `apps/tx-deep-diagnosis/test/`:

```
apps/tx-deep-diagnosis/
├── test/
│   ├── Main.hs                  -- tasty entrypoint
│   └── golden/
│       ├── passing/             -- input.json, diagram.mmd, report.md
│       ├── value-not-conserved/
│       ├── missing-witness/
│       └── multi-redeemer/
└── tx-deep-diagnosis.cabal      -- adds test-suite stanza
```

Use `tasty` + a hand-rolled byte-equality assertion (no `tasty-golden`
dependency to keep CHaP-pinned dep set tight). Each test loads
`input.json`, runs the renderer, and compares to `diagram.mmd` /
`report.md`. Mismatch prints the unified diff.

For the parties registry, the tests load the bundled
`docs/inspector/protocols` registry just like the binary does.

## Nix check

Add `tx-explain-render-smoke` to `flake.nix`:

```nix
tx-explain-render-smoke = pkgs.runCommand "tx-explain-render-smoke" { } ''
  ${hostTargets.tx-deep-diagnosis-test}/bin/tx-deep-diagnosis-test
  touch $out
'';
```

Wired into `nix/host/tx-deep-diagnosis-native/default.nix` to expose the
test executable, and into `apps/x86_64-linux` so `nix run
.#tx-explain-render-smoke` works (CI pattern).

CI workflow gets a new `tx-explain-render-smoke` job mirroring the
existing `tx-intent-smoke` job.

## Determinism

- All `Map`/`Set` traversals over JSON: drive layout from
  `Vector`/list order in the JSON, not from key-set hashing.
- Lovelace and decimal numbers are reproduced from the JSON strings as-is
  — never reparsed and reformatted.
- No timestamps or random IDs in the output.

## Out of scope (this PR)

- Surge preview render integration (the artifacts can be added later to
  the static site).
- A graphviz / DOT alternative.
- Cross-checking metadata claims against destinations.

## Risks

- Mermaid diagrams beyond ~30 nodes get hard to read in default
  renderers. Mitigation: collapse output buckets into one node per
  bucket label rather than per-output. The four fixtures cover the
  expected sizes.
- The `RegistryInstance` label is sometimes generic (`"SundaeSwap V3
  Treasury"` for many distinct treasuries). Mitigation: append the last
  6 hex of the hash to instance-derived labels so distinct instances
  remain distinguishable.

## Open follow-ups (separate tickets)

- Wire the rendered artifacts into the docs build so the site shows the
  diagram for the bundled fixture.
- Add a small fixtures-bumping helper to make snapshot regeneration safe.
