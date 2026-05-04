# Feature Specification: Formalize tx.intent Output Rows and Asset Detail

**Feature Branch**: `011-intent-output-values-assets`
**Created**: 2026-05-04
**Status**: Draft
**Input**: GitHub issue #57: "tx.intent: information audit — fields decoded by the ledger but dropped from the envelope"

## Context

During issue-57 triage, the current code showed an important drift: the live
`tx.intent` implementation already emits `value.outputs[]` with per-output
`address_hex`, `coin_lovelace`, `assets`, and `datum`, but the committed JSON
schema and public contract text do not describe that structure as part of the
supported result. The markdown report also shows only ADA and datum preview in
its Outputs table, so asset-bearing outputs remain hidden from the default
reader view.

This slice fixes that drift. It does not invent new ledger decoding. It makes
the existing per-output rows contractual, verifies them in smoke tests, and
surfaces per-output asset detail in the markdown report.

## User Scenarios & Testing

### User Story 1 — API consumers can rely on value.outputs[] (Priority: P1)

An API consumer reading the `tx.intent` contract can treat `value.outputs[]` as
part of the supported result, rather than an undocumented extra field.

**Why this priority**: contract drift is the main risk here. Consumers cannot
depend on a field that the schema and docs do not admit exists.

**Independent Test**: validate the updated schema/docs and extend the smoke
check to assert that `value.outputs[]` exists with non-empty asset maps on the
existing Conway fixture.

**Acceptance Scenarios**:

1. **Given** a `tx.intent` response, **When** the consumer validates it against
   the committed schema, **Then** `value.outputs[]` is an explicitly described
   field rather than an undocumented extra.
2. **Given** the asset-bearing Conway fixture, **When** `tx-intent-smoke`
   runs, **Then** it proves at least one output row carries a non-empty
   `assets` object.

### User Story 2 — Report readers can see per-output assets (Priority: P1)

A report reader scanning the Outputs table can see which outputs carry native
assets without opening raw JSON.

**Why this priority**: this is the human-facing payoff of surfacing
per-output rows. ADA alone is not enough to verify swaps or NFT-bearing
outputs.

**Independent Test**: re-render the existing markdown goldens and verify the
Outputs table gains an Assets column with stable formatting.

**Acceptance Scenarios**:

1. **Given** an output has no assets, **When** the Outputs table renders,
   **Then** the Assets cell shows `—`.
2. **Given** an output has one or more assets, **When** the Outputs table
   renders, **Then** the Assets cell shows a compact preview derived from the
   output's `assets` map.

## Functional Requirements

- **FR-001**: The committed `tx.intent` schema MUST describe
  `value.outputs[]` explicitly.
- **FR-002**: Each documented output row MUST include at least:
  `index`, `bucket`, `address_hex`, `coin_lovelace`, `assets`, and `datum`.
- **FR-003**: The public `ledger-functional-api.md` contract text MUST mention
  `value.outputs[]` as part of the supported `tx.intent` result.
- **FR-004**: The generated OpenAPI artifact MUST stay in sync with that
  contract update.
- **FR-005**: `tx-intent-smoke` MUST assert that `value.outputs[]` is an array
  and that the existing Conway fixture includes at least one row whose `assets`
  map is non-empty.
- **FR-006**: The markdown Outputs table in `tx-deep-diagnosis` MUST include an
  Assets column derived from `value.outputs[].assets`.
- **FR-007**: Assetless outputs MUST render `—` in that Assets column.
- **FR-008**: Asset-bearing outputs MUST render a deterministic compact preview
  from the `assets` map without hiding the ADA or datum columns.

## Edge Cases

- Outputs with an empty `assets` object.
- Outputs with one policy id and one empty asset name (NFT-style marker
  assets).
- Outputs with multiple policies and multiple asset names; the preview must
  remain deterministic and compact.

## Out of Scope

- Computing per-asset transfer edges between inputs and outputs.
- Resolving policy IDs or asset names to registry labels.
- Adding new ledger-decoded output fields beyond the ones already present in
  the live implementation.

## Acceptance

- The committed schema/docs/OpenAPI explicitly describe `value.outputs[]`.
- `tx-intent-smoke` proves output rows and non-empty assets on the existing
  Conway fixture.
- The markdown Outputs table shows an Assets column in both `summary.md` and
  `explain.md`.
