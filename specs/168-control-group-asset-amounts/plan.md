# Implementation Plan — Per-Asset Amounts on tx.review Control Groups

## Tech context

- Haskell library `libs/cardano-ledger-inspector/`, compiled three ways:
  `wasm32-wasi` reactor (GHC 9.12), Extism plugin, native CLI (GHC 9.8.4).
- Projection lives in `src/Conway/Inspector/Review.hs` — a pure projection over
  the already-enriched `tx.intent` result. No new ledger decoding is required.
- Unit tests: `libs/cardano-ledger-inspector/test/ReviewSpec.hs`
  (`tx-review-types-test`). Smoke: `tx-review-smoke` in `flake.nix`.
- Public contract: `specs/001-ledger-functional-layer/` — `schemas/`,
  `openapi/` (generated, checked by `ledger-functional-openapi-check`), and
  `contracts/ledger-functional-api.md`.

## Design

Restore quantities along the existing projection path. The change is local to
`Review.hs`; nothing upstream needs to change, because `tx.intent` already
emits the full `assetMap` per output.

The `assetMap` vocabulary is reused verbatim from spec 011 rather than
invented: nested policy-id → asset-name → decimal-string quantity, hex keys.
This keeps one asset representation across `tx.intent` and `tx.review`.

Three edits, in order along the data path:

1. **Parse** — `outputAssetKeys :: Maybe Value -> Set (Text, Text)` becomes an
   asset *map* parser returning `Map (Text, Text) Integer`, reading the
   quantity that the current comprehension discards. Quantities arrive as
   decimal strings and are parsed to `Integer`.
2. **Accumulate** — `GroupAcc.gaAssetKeys :: Set (Text, Text)` becomes
   `gaAssets :: Map (Text, Text) Integer`. `combineAcc`'s `<>` (left-biased
   set union) becomes `Map.unionWith (+)` so grouped outputs sum per asset
   class rather than collapsing.
3. **Project** — `ControlGroup` gains `cgAssets :: Map (Text, Text) Integer`.
   Its `ToJSON` emits a new `"assets"` key in nested `assetMap` shape.
   `cgAssetClassCount` becomes `Map.size (gaAssets acc)` — the same value the
   old `Set.size` produced, since the map is keyed by the same pair.

`asset_class_count` is preserved as an independently computed, independently
required field. It is not derived from `assets` in the contract even though
the two agree, so neither field is implied redundant (spec FR-004).

### Ordering and bisect-safety

Slice 1 adds `assets` to the emitted JSON. Every schema object in
`tx-review-result.schema.json` is `additionalProperties: true`, and `assets` is
not yet in `required`, so the existing schema and smoke checks still pass at
slice 1's HEAD. Slice 2 then tightens the contract to require it. Reversing
that order would fail the gate at slice 1.

## Slices

### Slice 1 — `engine-asset-amounts`

Carry quantities through the projection and emit `assets`.

- `libs/cardano-ledger-inspector/src/Conway/Inspector/Review.hs`
- `libs/cardano-ledger-inspector/test/ReviewSpec.hs`

RED: `ReviewSpec` gains a multi-asset control group case (two asset classes,
one repeated across two grouped outputs so the sum is exercised) and an empty
control group case asserting `assets == {}`. Both fail before the change.
GREEN: the three edits above.

Proof: `just check-review-types`.

### Slice 2 — `contract-surfaces`

Publish `assets` as a required control-group field everywhere the public
contract describes control groups.

- `specs/001-ledger-functional-layer/schemas/tx-review-result.schema.json` —
  add an `assetMap` `$def` mirroring the intent schema's, reference it from
  `controlGroup.properties.assets`, add `"assets"` to `controlGroup.required`.
- `specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json`
  — regenerated, not hand-edited.
- `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md` —
  the `tx.review` section's control-group description and example.
- `README.md` / `gh-docs/` only if they describe the control-group shape.

Proof: `nix run .#ledger-functional-openapi-check`, `just check-openapi`.

### Slice 3 — `regression-fixtures-and-parity`

Prove the acceptance cases on every compiled surface.

- `flake.nix` — extend `tx-review-smoke` to assert an empty control group's
  `assets == {}` and a multi-asset group's exact per-asset quantities, and to
  keep comparing WASI / native / Extism `tx_review` bytes.
- Fixture under `specs/001-ledger-functional-layer/fixtures/` if the existing
  review fixture has no multi-asset control group.

Proof: `just check-review`, `just check-extism-spike`.

## Risks

- **No existing multi-asset fixture.** If the committed review fixture has no
  control group holding more than one asset class, slice 3 must add one.
  Assessed at slice 3 dispatch, against the real fixture, not assumed now.
- **First WASI build is slow** (fresh Cabal dependency cache). Slice 1's
  focused proof is `check-review-types` (native unit) so the pair is not
  blocked on a full wasm rebuild; the full gate runs at orchestrator review.
- **OpenAPI is generated.** Hand-editing it would pass review and fail
  `openapi-check`. Slice 2's brief must say regenerate, not edit.
