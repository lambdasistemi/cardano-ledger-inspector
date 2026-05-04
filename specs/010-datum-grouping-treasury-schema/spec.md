# Feature Specification: Datum Grouping and Explicit Amaru Treasury Schema

**Feature Branch**: `010-datum-grouping-treasury-schema`
**Created**: 2026-05-04
**Status**: Draft
**Input**: GitHub issue #66: "Datums section: group by (cbor, destination) and vendor Amaru treasury schema"

## Context

`tx-deep-diagnosis` currently groups decoded inline datums only by their
`cbor_hex`. In the committed SundaeSwap/USDM fixture, that collapses the Amaru
treasury change output together with the SundaeSwap order outputs because they
happen to share the same inline datum bytes even though their destinations are
different.

The fixture also exposes a provenance problem. The treasury change output is
currently rendered with the SundaeSwap order schema only because it was grouped
into the order block. The pinned upstream `treasury-contracts` source does not
actually expose a typed treasury datum in `validators/treasury.ak`; the spend
validator treats the datum as opaque `Data`. This slice therefore needs an
explicit instance-level schema with honest provenance instead of a false claim
that the upstream treasury validator provided those field names.

## User Scenarios & Testing

### User Story 1 — Separate identical datums by destination (Priority: P1)

A reviewer reading the Datums section sees separate blocks when the same inline
datum bytes are sent to different destinations.

**Why this priority**: the current grouping is actively misleading because it
shows the treasury change output as if it belonged to the SundaeSwap order
destination.

**Independent Test**: render the committed fixture and verify that output `#0`
has its own datum block while the order outputs remain grouped together.

**Acceptance Scenarios**:

1. **Given** two outputs share identical `cbor_hex` but resolve to different
   destination labels, **When** the Datums section renders, **Then** they
   appear in separate `<details>` blocks.
2. **Given** multiple outputs share identical `cbor_hex` and the same
   destination label, **When** the Datums section renders, **Then** they remain
   collapsed into one block with the output index list.

### User Story 2 — Treasury datum interpretation is explicit (Priority: P1)

A reviewer reading the treasury change datum sees a typed rendering that is
bound to the Amaru treasury instance intentionally, with provenance that states
the shape was manually interpreted because the upstream treasury validator does
not publish a typed datum.

**Why this priority**: the current treasury rendering inherits the order schema
accidentally from grouping. The output needs an explicit, auditable
interpretation path of its own.

**Independent Test**: render the committed fixture and verify that the treasury
block uses a treasury-instance schema provenance line instead of the generic
untyped fallback or the order-schema disclaimer.

**Acceptance Scenarios**:

1. **Given** the Amaru treasury change output, **When** the Datums section
   renders, **Then** it uses the schema vendored on the matching
   `instances[]` entry in `registry.json`.
2. **Given** that vendored schema is manually curated, **When** the typed datum
   renders, **Then** the provenance line states that no upstream typed treasury
   source exists and that the field names come from manual analysis.

### User Story 3 — Group representatives cannot leak labels or schema (Priority: P2)

A reviewer can trust that the destination label and schema used in each datum
block belong to that block's actual grouping key, not to whichever equal-CBOR
output happened to win the fold order.

**Why this priority**: the current representative-selection behavior is the
mechanism that leaks the order label and schema onto the treasury output.

**Independent Test**: inspect the rendered block titles and provenance lines in
both `summary.md` and `explain.md`; each block must match its own destination.

## Functional Requirements

- **FR-001**: The Datums section MUST group inline datums by the pair
  `(cbor_hex, destination_label)`, not by `cbor_hex` alone.
- **FR-002**: Outputs that share the same grouping key MUST remain collapsed
  into one datum block with the sorted output index list.
- **FR-003**: Outputs that share `cbor_hex` but differ in destination label
  MUST render as separate datum blocks.
- **FR-004**: The Amaru Network Compliance treasury instance
  (`32201dc1…0baa0d`) in `docs/inspector/protocols/registry.json` MUST carry an
  explicit datum schema under `instances[]`.
- **FR-005**: The treasury instance datum schema MUST use provenance that does
  not claim an upstream typed treasury datum when the pinned upstream source
  exposes only opaque `Data`.
- **FR-006**: The treasury change output in the committed SundaeSwap/USDM
  fixture MUST render against the treasury instance schema rather than
  inheriting the order schema through grouping.
- **FR-007**: The SundaeSwap order outputs in the same fixture MUST keep their
  existing typed order rendering and Aiken provenance.
- **FR-008**: If a datum AST stops matching the vendored treasury schema, the
  renderer MUST keep its existing schema-mismatch fallback instead of emitting
  misleading typed fields.

## Edge Cases

- Identical datum bytes sent to two different script addresses that resolve to
  different labels.
- Multiple outputs sent to the same destination with identical datum bytes;
  these should still collapse into one block.
- The manually curated treasury schema drifts from the observed datum shape;
  the renderer must fall back to untyped rather than invent fields.

## Out of Scope

- Changing the fixture transaction itself.
- Changing the order schema provenance or the generic typed-datum renderer.
- Claiming a typed upstream treasury datum where the pinned source exposes only
  opaque `Data`.

## Acceptance

- The Datums section renders one separate block for treasury change output `#0`
  and separate order blocks according to the actual `(cbor, destination)` keys
  in the committed fixture.
- The treasury block uses an explicit treasury-instance schema provenance line,
  not the order schema by accident.
- `summary.md` and `explain.md` show the same grouping split.
