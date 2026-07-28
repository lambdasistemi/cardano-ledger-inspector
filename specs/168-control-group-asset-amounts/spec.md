# Feature Specification: Per-Asset Amounts on tx.review Control Groups

**Feature Branch**: `feat/168-control-group-asset-amounts`
**Created**: 2026-07-28
**Status**: Draft
**Input**: GitHub issue #168: "tx.review: expose per-asset (policy id / asset
name / quantity) amounts, not just asset_class_count"

## Context

Each `tx.review` control group currently carries `asset_class_count` — a
cardinality saying how many distinct non-ADA asset classes the group holds —
and nothing else about those assets. A signer-facing renderer can therefore
say "this group holds 3 asset classes" but cannot say *which* assets, or *how
much* of each.

The data is not missing from the engine. It is discarded inside the
projection. `tx.intent` already emits per-output `assets` as a nested
policy-id → asset-name → quantity map (the `assetMap` shape formalized in
spec 011). `Conway.Inspector.Review.outputAssetKeys` reads that map and throws
the quantities away:

```haskell
outputAssetKeys (Just (Aeson.Object policies)) =
    Set.fromList
        [ (AesonKey.toText policyId, AesonKey.toText assetName)
        | (policyId, Aeson.Object names) <- KeyMap.toList policies
        , (assetName, _) <- KeyMap.toList names   -- quantity discarded here
        ]
```

The accumulator carries `gaAssetKeys :: Set (Text, Text)` purely so
`accToGroup` can take its `Set.size`. Policy ids and asset names survive the
grouping; only quantities are lost.

This spec restores the quantities through the same projection and publishes
them as a contractual field, so downstream signer-facing renderers read exact
amounts from the engine instead of synthesizing them.

## Why this belongs in the engine

Ledger semantics belong in Haskell/WASI, not in browser or provider adapters
(AGENTS.md, "Code style and boundaries"). cardano-swiss-knife#121 is a
signer-review renderer; it is forbidden from synthesizing per-asset ledger
semantics host-side, and `asset_class_count` gives it no amount to render.
The canonical semantics and result schema therefore belong here.

## User Scenarios & Testing

### User Story 1 — Renderers can show exact multi-asset holdings (Priority: P1)

A signer-facing renderer reading a `tx.review` control group can display each
non-ADA asset the group holds, with its policy id, asset name, and exact
quantity, instead of only a count.

**Why this priority**: this is the capability the issue asks for, and the one
blocking cardano-swiss-knife#121's acceptance.

**Independent Test**: project a review result for a transaction whose outputs
carry more than one asset class in a single control group, and assert the
group's `assets` map reports each policy/name with its exact summed quantity.

**Acceptance Scenarios**:

1. **Given** a control group whose outputs hold two distinct asset classes,
   **When** the group is projected, **Then** `assets` reports both, each with
   its exact quantity as a decimal string.
2. **Given** a control group holding the same asset class across two grouped
   outputs, **When** the group is projected, **Then** that asset's quantity is
   the sum across those outputs.
3. **Given** a control group with no non-ADA assets, **When** the group is
   projected, **Then** `assets` is an empty object — present, not absent.

### User Story 2 — `asset_class_count` keeps its exact meaning (Priority: P1)

An existing consumer reading `asset_class_count` sees no change in its value
or its meaning.

**Why this priority**: `asset_class_count` is already a published contract
field. Issue #168 asks for the new detail *alongside* it, not instead of it.
Silently redefining or dropping it would break existing consumers.

**Why it is not redundant**: `asset_class_count` is a strict count of distinct
asset classes. It remains the authoritative cardinality and stays independently
required in the schema; `assets` is the detail. Consumers must not be led to
treat either as derivable from the other by contract.

**Acceptance Scenarios**:

1. **Given** any control group, **When** it is projected, **Then**
   `asset_class_count` reports the number of distinct asset classes, exactly
   as before this change.
2. **Given** the committed review schema, **When** a consumer validates a
   response, **Then** both `asset_class_count` and `assets` are required
   fields of a control group.

### User Story 3 — Every compiled surface reports the new field (Priority: P1)

A consumer of any surface `tx.review` runs on — the WASI reactor, the native
build, or the Extism `tx_review` export — sees the same control-group shape.

**Why this priority**: the browser workbench consumes the WASI artifact. A
native-only landing leaves the actual downstream consumer on the old shape,
which would not unblock #121.

**Acceptance Scenarios**:

1. **Given** a review request, **When** it is answered by WASI, by the native
   build, and by the Extism `tx_review` export, **Then** all three return
   byte-identical control groups carrying `assets`.

## Functional Requirements

- **FR-001**: A `tx.review` control group MUST carry an `assets` field holding
  a nested policy-id → asset-name → quantity map, using the same `assetMap`
  shape `tx.intent` already publishes for output rows (hex policy ids, hex
  asset names, decimal-string quantities).
- **FR-002**: Quantities MUST be summed per asset class across every output
  grouped into the control group.
- **FR-003**: `assets` MUST be present and empty (`{}`) for a control group
  holding no non-ADA assets, never absent or null.
- **FR-004**: `asset_class_count` MUST retain its current value and meaning —
  a strict count of distinct non-ADA asset classes — and remain a required
  field.
- **FR-005**: The committed review JSON schema, the OpenAPI document, and the
  public contract text MUST describe `assets` as a required control-group
  field.
- **FR-006**: Regression proof MUST cover an empty control group and a
  multi-asset control group (more than one policy/asset class in one group).
- **FR-007**: The WASI reactor, the native build, and the Extism `tx_review`
  export MUST agree byte-for-byte on the new shape.

## Out of Scope

- `tx.intent`'s `value_buckets[].asset_class_count`. That is a different
  structure on a different operation; issue #168 and the blocked
  cardano-swiss-knife#121 acceptance criterion both name `tx.review` control
  groups. Recorded here so the omission is a decision, not an oversight.
- Any change to cardano-swiss-knife. This ticket publishes the upstream
  contract; the downstream renderer is #121's work.

## Success Criteria

- A multi-asset control group reports each policy id, asset name, and exact
  summed quantity.
- An empty control group reports `assets: {}`.
- `asset_class_count` is unchanged for every fixture that existed before this
  change.
- Schema, OpenAPI, and contract text all require `assets`.
- WASI, native, and Extism agree byte-for-byte.
