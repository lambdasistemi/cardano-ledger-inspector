# Feature Specification: tx-deep-diagnosis Explain Artifacts

**Feature Branch**: `feat/issue-54-explain-artifacts`
**Created**: 2026-05-03
**Status**: Draft
**Input**: GitHub issue #54: "tx-deep-diagnosis: render diagram + narrative artifacts from result JSON"

## Context

`tx-deep-diagnosis` already emits a single JSON document combining `intent`,
`validate`, and a `summary` line. The intent block is rich enough to drive
human-facing artifacts: it carries pre-rendered `effects`, `metrics`, and
`sections` rows, an explicit `failures[]` list on the validate block, and
labelled output buckets (`external_key` vs `script`).

A CLI consumer today still has to read raw JSON to reason about a transaction.
The shape is stable enough to render two deterministic artifacts directly:

- a **Mermaid diagram** of inputs → body → outputs with reference and
  collateral side rails and a failure overlay
- a **Markdown report** built from the same JSON: title, claims, effects
  table, signer table, validation verdict, failures, warnings

Naming parties (script / address hashes → human labels) is a registry lookup,
not a reasoning task. The protocol registry (`docs/inspector/protocols/...`)
already maps validator and instance hashes to labels and is loaded today by
`TxDeepDiagnosisHost.Registry.loadRegistries`.

## User Scenarios & Testing

### User Story 1 — Read a transaction at a glance (Priority: P1)

A signer or auditor runs `tx-deep-diagnosis --cbor tx.cbor --emit-mermaid
diagram.mmd --emit-report report.md` and gets two artifacts that, together,
explain the transaction without opening the JSON.

**Why this priority**: this is the user-visible value of the ticket.

**Independent Test**: run on the committed SundaeSwap/USDM mainnet fixture;
the report shows the swap claim, the value-not-conserved failure, the missing
required signers; the Mermaid diagram renders inputs, twelve outputs split
into key vs script buckets, four reference inputs, one collateral, and a
red-tagged body for the value-not-conservation failure.

**Acceptance Scenarios**:

1. **Given** a passing tx, **When** the artifacts are rendered, **Then** the
   diagram has no red overlays and the report's verdict line is `valid`.
2. **Given** a tx with a `ValueNotConservedUTxO` failure, **When** the
   artifacts are rendered, **Then** the body node carries a red badge
   labelled with the conserved-value mismatch summary.
3. **Given** a tx missing vkey witnesses, **When** the artifacts are
   rendered, **Then** each missing-signer hash appears as a red badge
   (resolved to a human label if known in the registry).

### User Story 2 — Determinism and offline use (Priority: P1)

The same JSON input always produces byte-identical artifacts, so they are
checked into snapshot tests and used as documentation fixtures.

**Why this priority**: deterministic golden output is what makes these
artifacts safe to diff and review.

**Independent Test**: render twice in two processes and compare bytes.

**Acceptance Scenarios**:

1. **Given** a fixture JSON, **When** the renderers are invoked, **Then** the
   output bytes match the committed snapshot.
2. **Given** the same fixture, **When** the renderers are invoked from a
   different working directory, **Then** the output is unchanged.

### User Story 3 — Names from the registry, not from a guess (Priority: P2)

When a script hash matches a `RegistryValidator` or `RegistryInstance`, its
label is used in both the diagram and the report. Unknown hashes are
displayed in truncated hex with no fabricated label.

**Why this priority**: a wrong attribution on a `disburse` claim is worse than
`unknown`. This rule keeps the renderers honest.

**Independent Test**: render the SundaeSwap fixture; the script-bucket node
in the diagram is labelled `SundaeSwap V3 Treasury` (or whatever the
registry says), not `38c627d4…`. Render a tx whose script hashes are not in
the registry; the node label is `script (38c627d4…)`.

## Functional Requirements

- **FR-001**: `tx-deep-diagnosis` accepts two new CLI options:
  `--emit-mermaid <PATH>` and `--emit-report <PATH>`. Either or both may be
  given. When neither is given, behaviour is unchanged.
- **FR-002**: With `--emit-mermaid`, a Mermaid `flowchart TD` document is
  written to `<PATH>` after the JSON envelope is emitted on stdout.
- **FR-003**: With `--emit-report`, a Markdown document is written to
  `<PATH>` after the JSON envelope is emitted on stdout.
- **FR-004**: Both renderers consume only the `tx-deep-diagnosis` JSON
  envelope (`intent`, `validate`, `summary`) and the loaded
  `ProtocolRegistry`. They do not call the inspector library or the network.
- **FR-005**: The Mermaid diagram includes nodes for: every resolved input,
  every output bucket from `intent.value.output_buckets[]`, every reference
  input, the collateral input/return when present, and the tx body.
- **FR-006**: Annotations on the body node: fee, redeemer count, withdrawal
  count, mint/burn status, metadata label (when a single label is dominant),
  collateral.
- **FR-007**: Validation failures are overlaid on the diagram by attaching a
  red-styled badge (Mermaid `classDef`) to the affected node. Mapping:
  `ValueNotConservedUTxO` → body; `MissingVKeyWitnessesUTXOW` → a synthetic
  signer node per missing hash; other ledger failures → body with their
  rule name.
- **FR-008**: The Markdown report contains, in order: title (intent.title
  / subtitle), one-paragraph summary derived from `summary` + verdict,
  metadata claims table, effects table (from `intent.sections[]` rows),
  signer perspective table, validation verdict + failures table, warnings
  list.
- **FR-009**: Hash → label resolution uses the existing
  `TxDeepDiagnosisHost.Registry.identifyByHash` and treasury scope helpers.
  Unknown hashes are displayed in truncated form (`first8…last8`) with no
  fabricated label.
- **FR-010**: The renderer modules are pure (`Text`-in, `Text`-out). No `IO`.

## Edge Cases

- No producer-tx context resolved (probe-only mode): the diagram still
  renders inputs as unresolved placeholders; the report's signer perspective
  shows `unknown net spend` with the existing `net_spend_note` reproduced.
- Multiple ledger failures: each failure is overlaid; the report lists them
  in the order returned by the validator.
- A tx with no script outputs: the script bucket is omitted from the diagram.
- A tx with no reference inputs / no collateral: the corresponding side
  rails are omitted.
- Metadata with no `1694` (or any) label: the metadata-label annotation is
  omitted but the claim block in the report still renders raw values.
- Output bucket lovelace totals expressed as decimal strings: rendered as ADA
  with the existing `intent` formatting (no recomputation).

## Out of Scope

- Cross-checking metadata claims against actual destinations.
- Free-form prose narrative generation.
- Resolving stake-pool tickers, ADA Handles, or CIP-26 metadata oracle
  entries (deferrable; the registry covers the immediate need).
- A new `tx.explain` ledger op. The renderers live in the host CLI, not the
  inspector library, so the ledger functional API surface is unchanged.

## Acceptance

- `tx-deep-diagnosis --cbor <hex> --emit-mermaid d.mmd --emit-report r.md`
  exits 0 and produces both files for the four snapshot fixtures.
- Snapshot tests cover: passing tx; `ValueNotConservedUTxO` failure;
  missing-witness failure; multi-redeemer script tx.
- Running the renderers twice produces byte-identical output.
- `just ci` is green.
