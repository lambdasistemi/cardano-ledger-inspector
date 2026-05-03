# Research: Explain Markdown Parity Phase 1

## Decision: Scope the Branch to the Current `main` Delta, Not the Original Issue Baseline

The issue text was written before several explain-report improvements had
already landed on `main`. Current `main` already includes parsed failure bodies,
smart-contract call tables, outputs, datums, and the single-file explain
renderer.

**Rationale**: Planning against the stale baseline would duplicate work and
mis-state the remaining gap. This branch should only target what is still
missing on current `main`.

**Alternatives considered**:

- Implement the issue literally from the older baseline: rejected because it
  would restate already-shipped sections and create noisy diffs.
- Wait for a rewritten issue body: rejected because the current code makes the
  remaining scope clear enough to proceed independently.

## Decision: Derive the Headline from Existing Intent Content

The headline will be synthesized only from fields already present in the
current diagnosis envelope: existing claim summaries, the report title/subtitle,
verdict state, and output-bucket evidence.

**Rationale**: The issue explicitly allows an initial heuristic version before
issue #57 lands. Current intent data is sufficient to produce a better
above-the-fold line than the generic "Signing summary" title alone.

**Alternatives considered**:

- Wait for new `tx.intent` fields from issue #57: rejected because it blocks an
  otherwise useful first parity branch.
- Use only the existing title field: rejected because it is too generic to act
  as a mainstream-inspector-style action line.

## Decision: Build the Fees & Resources Panel from Existing Envelope Fields

The new panel will use the fields already present on current `main`:
`fee_lovelace`, `tx_size_bytes`, redeemer count, and the committed ex-units
already exposed per script row.

**Rationale**: The issue says partial data is acceptable. Summing committed
per-redeemer ex-units in the renderer is enough for a first reader-facing panel
without waiting for a new top-level intent field.

**Alternatives considered**:

- Add a new top-level total resource field in the ledger layer: rejected for
  this branch because the renderer can compute the summary from current data.
- Omit ex-units until issue #57: rejected because committed ex-units are already
  present today.

## Decision: Promote Human Failure Language Above the Raw Rule Name

The current renderer already generates human-readable failure prose, but the
raw ledger rule name remains the heading. This branch will invert that emphasis:
lead with the reader-facing failure sentence and keep the raw rule as supporting
detail.

**Rationale**: That matches the issue's explicit parity goal and keeps the raw
predicate available for grep/debug use.

**Alternatives considered**:

- Leave the raw rule name as the heading: rejected because it still forces the
  reader to decode ledger jargon before they know what went wrong.
- Drop the raw rule name completely: rejected because reviewers still need a
  stable low-level anchor.

## Decision: Collapse Mermaid Blocks Only in the Single-File Explain Renderer

The directory-shaped artifact set (`summary.md`, `parties.mmd`, `topology.mmd`,
`failures.mmd`, `value-flow.tsv`) remains unchanged. Only `Render.Single` will
wrap its inline Mermaid sections in collapsed details blocks.

**Rationale**: The issue's complaint is about the readability of the single-file
`explain.md`. The directory artifacts are already opt-in by file.

**Alternatives considered**:

- Collapse or suppress the directory artifacts: rejected because they are meant
  for consumers who explicitly want the raw cut files.
- Collapse non-diagram sections like Balance: rejected because the survey only
  demotes visualizations, not tabular truth.

## Decision: Use the Existing Snapshot Harness as the Main Regression Contract

Verification will continue to rely on the existing
`tx-deep-diagnosis-render-snapshot` harness and the flake check
`tx-explain-render-smoke`.

**Rationale**: The renderer is pure, the golden input is already committed, and
the snapshot artifacts directly capture the user-visible contract of this
feature.

**Alternatives considered**:

- Add bespoke unit tests for string fragments only: rejected because they would
  miss ordering regressions across the whole document.
- Rely on manual markdown inspection: rejected because the feature is precisely
  about presentation ordering and wording.
