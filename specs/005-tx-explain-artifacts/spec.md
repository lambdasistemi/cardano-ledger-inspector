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

A single mega-graph of every input, output, reference input, collateral,
signer, and failure does not survive a typical Conway transaction (≥20
nodes; Mermaid's auto-layout is unstable past ~20 nodes). Pedagogically a
signer also wants different views at different moments: who is moving
what, where the money goes, the full topology, what is wrong.

The output of the renderer is therefore **a directory of cuts at
different heights**, plus a top-level `summary.md` that tells the story
in prose with links to the cuts.

Naming parties (script / address hashes → human labels) is a registry
lookup, not a reasoning task. The protocol registry
(`docs/inspector/protocols/...`) already maps validator and instance
hashes to labels and is loaded today by
`TxDeepDiagnosisHost.Registry.loadRegistries`.

## User Scenarios & Testing

### User Story 1 — Read a transaction at a glance (Priority: P1)

A signer or auditor runs `tx-deep-diagnosis --cbor tx.cbor --emit-explain
out/` and gets a directory of artifacts that, together, explain the
transaction without opening the JSON.

**Why this priority**: this is the user-visible value of the ticket.

**Independent Test**: run on the committed SundaeSwap/USDM mainnet
fixture; `out/summary.md` opens with the swap claim, the
value-not-conserved failure, and the missing required signers; the
embedded links resolve to `parties.mmd`, `value-flow.tsv`,
`topology.mmd`, and `failures.mmd`.

**Acceptance Scenarios**:

1. **Given** a passing tx, **When** the artifacts are rendered, **Then**
   `failures.mmd` is omitted and `summary.md` ends with `verdict: valid`.
2. **Given** a tx with a `ValueNotConservedUTxO` failure, **When** the
   artifacts are rendered, **Then** `failures.mmd` shows the body node
   in the `bodyFail` class and `summary.md` quotes the conserved-value
   mismatch from the validator message.
3. **Given** a tx missing vkey witnesses, **When** the artifacts are
   rendered, **Then** each missing-signer hash appears as a red
   synthetic-signer node in `failures.mmd`, resolved to a human label
   if known in the registry.

### User Story 2 — Determinism and offline use (Priority: P1)

The same JSON input always produces byte-identical artifacts, so they are
checked into snapshot tests and used as documentation fixtures.

**Why this priority**: deterministic golden output is what makes these
artifacts safe to diff and review.

**Independent Test**: render twice in two processes and compare bytes.

**Acceptance Scenarios**:

1. **Given** a fixture JSON, **When** the renderers are invoked, **Then**
   each emitted file matches the committed snapshot byte-for-byte.
2. **Given** the same fixture, **When** the renderers are invoked from a
   different working directory, **Then** the output is unchanged.

### User Story 3 — Names from the registry, not from a guess (Priority: P2)

When a script hash matches a `RegistryValidator` or `RegistryInstance`,
its label is used in every cut and in the prose summary. Unknown hashes
are displayed in truncated hex (`first8…last8`) with no fabricated label.

**Why this priority**: a wrong attribution on a `disburse` claim is worse
than `unknown`. This rule keeps the renderers honest.

**Independent Test**: render the SundaeSwap fixture; the script-bucket
node is labelled from the registry, not from raw hex. Render a tx whose
script hashes are not in the registry; the node label is `script
(38c627d4…)`.

## Functional Requirements

- **FR-001**: `tx-deep-diagnosis` accepts a new CLI option
  `--emit-explain <DIR>`. When absent, behaviour is unchanged. When
  present, the directory is created (mkdir -p) and the artifacts below
  are written to it after the JSON envelope is emitted on stdout.

- **FR-002**: The emitted directory contains the following files:
  - `summary.md` — top-level prose summary, always present
  - `parties.mmd` — Mermaid `flowchart LR`, parties cut (L1)
  - `value-flow.tsv` — Sankey-shaped TSV of lovelace flows (L2)
  - `topology.mmd` — Mermaid `flowchart TD`, full topology cut (L3)
  - `failures.mmd` — Mermaid `flowchart TD` of failures only, written
    only when `validation.failures[]` is non-empty (L4)

- **FR-003**: `summary.md` is the human-readable deep summary. Sections
  in this order: title (intent.title), one-paragraph verdict
  (parses `summary` line + `valid_for_supplied_context`), claims table,
  effects table from `intent.sections[]`, signer perspective table,
  validation failures table, warnings, and a "diagrams" footer with
  relative links to `parties.mmd`, `value-flow.tsv`, `topology.mmd`, and
  `failures.mmd` (links are emitted only for files that were written).

- **FR-004**: All renderers consume only the `tx-deep-diagnosis` JSON
  envelope (`intent`, `validate`, `summary`) and the loaded
  `ProtocolRegistry`. They do not call the inspector library or the
  network.

- **FR-005**: Cut definitions:

  - **Parties (L1)** — one Mermaid node per distinct party, where a
    party is a signer hash, an address payment-credential, or a script
    hash from `intent.value.output_buckets[].bucket`. Edges represent
    the consume / produce / withdraw / collateral relations. Node
    budget: ~4–8 in expected fixtures.

  - **Value flow (L2)** — TSV with columns `source<TAB>target<TAB>lovelace<TAB>label`. Sources are
    resolved-input nodes; targets are output-bucket nodes. The TSV is a
    standard Sankey input that any d3-sankey or pivot tool consumes;
    it is not rendered as Mermaid (Mermaid `sankey-beta` is unstable
    and we want byte-stable snapshots).

  - **Topology (L3)** — every resolved input, every output (one node
    per output, not per bucket), every reference input, the collateral
    input/return when present, the body, and one synthetic signer node
    per declared required signer. Node budget: ~20–30 in expected
    fixtures.

  - **Failures (L4)** — only emitted when `validation.failures[]` is
    non-empty. Each failure becomes one or more red nodes mapped per
    plan.md.

- **FR-006**: Annotations on the body node in topology: fee, redeemer
  count, withdrawal count, mint/burn status, metadata label (when a
  single label is dominant), collateral indicator.

- **FR-007**: Validation failures are styled with Mermaid `classDef`
  classes named `bodyFail`, `signerFail`, `inputFail`. The mapping is
  defined in `plan.md`.

- **FR-008**: Hash → label resolution uses the existing
  `TxDeepDiagnosisHost.Registry.identifyByHash` and treasury scope
  helpers. Unknown hashes are truncated `first8…last8` with no
  fabricated label.

- **FR-009**: The renderer modules are pure (`Text`-in, `Text`-out). No
  `IO` inside the renderers; the `Main` writes the resulting strings to
  disk.

## Edge Cases

- No producer-tx context resolved (probe-only mode): `summary.md`
  reproduces `value.net_spend_note`; `topology.mmd` shows inputs as
  unresolved placeholders; `value-flow.tsv` is emitted with empty rows
  plus a header so downstream tools do not crash.
- Multiple ledger failures: each failure overlays a node in
  `failures.mmd`; `summary.md` lists them in the validator's order.
- A tx with no script outputs: the parties cut omits the script node;
  the topology cut still renders the body and signers.
- A tx with no reference inputs / no collateral: the corresponding
  side rails are omitted from topology.
- Metadata with no `1694` (or any) label: the metadata-label
  annotation is omitted but the claim block in `summary.md` still
  renders raw values.
- Lovelace and decimal numbers are reproduced from the JSON strings
  as-is — never reparsed and reformatted.

## Out of Scope

- Cross-checking metadata claims against actual destinations.
- Free-form prose narrative beyond the structured `summary.md` template.
- Resolving stake-pool tickers, ADA Handles, or CIP-26 metadata oracle
  entries.
- A new `tx.explain` ledger op. The renderers live in the host CLI, not
  the inspector library, so the ledger functional API surface is
  unchanged.
- D2 / Graphviz alternative backends. If Mermaid layout proves
  insufficient for the topology cut on a fixture, a D2 swap is a
  follow-up PR, not part of this scope.

## Acceptance

- `tx-deep-diagnosis --cbor <hex> --emit-explain out/` exits 0 and
  produces `summary.md`, `parties.mmd`, `value-flow.tsv`, `topology.mmd`
  for the four snapshot fixtures, plus `failures.mmd` for the three
  invalid ones.
- Snapshot tests cover: passing tx; `ValueNotConservedUTxO` failure;
  missing-witness failure; multi-redeemer script tx.
- Running the renderers twice produces byte-identical output for every
  emitted file.
- `just ci` is green.
