# Tasks — Per-Asset Amounts on tx.review Control Groups

Issue: https://github.com/lambdasistemi/cardano-ledger-inspector/issues/168

One commit per slice, bisect-safe, `Tasks:` trailer naming the closed tasks.

## Slice 1 — engine-asset-amounts

Commit subject: `feat: expose per-asset amounts on tx.review control groups`

- [X] T168 RED: add a `ReviewSpec` case for a multi-asset control group — two
      distinct asset classes, one of them present in two grouped outputs so the
      per-class sum is exercised — asserting exact policy id, asset name, and
      summed quantity in the emitted `assets` map.
- [X] T169 RED: add a `ReviewSpec` case for a control group holding no non-ADA
      assets, asserting `assets` is present and empty (`{}`), not absent or
      null.
- [X] T170 GREEN: parse quantities — replace the discarding `outputAssetKeys`
      with an asset-map parser returning `Map (Text, Text) Integer`.
- [X] T171 GREEN: accumulate quantities — `GroupAcc.gaAssetKeys` becomes
      `gaAssets :: Map (Text, Text) Integer`; `combineAcc` sums with
      `Map.unionWith (+)`.
- [X] T172 GREEN: project — `ControlGroup` gains `cgAssets`, its `ToJSON` emits
      `"assets"`, and `cgAssetClassCount` becomes `Map.size` over the same map,
      preserving its existing value and meaning.
- [X] T173 Proof: `just check-review-types` green; existing `ReviewSpec` cases
      unchanged in their `asset_class_count` expectations.
- [X] T173a Added during slice-1 review, not in the original plan. The first
      GREEN parsed quantities with skip-on-mismatch pattern guards, so an entry
      whose quantity was not a parseable decimal string was dropped entirely —
      shrinking `asset_class_count` below its pre-change value (an FR-004 break)
      and silently removing an asset from a signer-facing review. Requirement:
      the `(policy, name)` key set must be derived from the structure of the
      assets object, independent of whether each quantity parses. Delivered as
      `fromMaybe 0` over a total `case` on the value, with RED test T170
      (`"not_a_number"` → class still counted, quantity reported `0`).

## Slice 2 — contract-surfaces

Commit subject: `feat: require per-asset amounts in the tx.review contract`

- [ ] T174 Add an `assetMap` `$def` to `tx-review-result.schema.json` mirroring
      the `tx.intent` schema's, reference it from `controlGroup.properties.assets`,
      and add `"assets"` to `controlGroup.required` alongside `asset_class_count`.
- [ ] T175 Add `assets` to every tx.review ControlGroup example in the OpenAPI
      SOURCE `nix/ledger-functional-openapi.nix` (both `control_groups` and
      `high_value_movements`), then regenerate the committed
      `.openapi.json` via `just build-openapi` + copy. Do NOT hand-edit the
      JSON, and do NOT touch tx.intent `output_buckets` examples.
- [ ] T176 Update the `tx.review` section of
      `contracts/ledger-functional-api.md` — control-group field description and
      worked example — stating that `asset_class_count` remains a strict count
      and `assets` carries the detail.
- [ ] T177 Confirm README.md / gh-docs need no change (verified: neither
      mentions `asset_class_count`); state the finding rather than editing.
- [ ] T177a Document the unparseable-quantity rule in
      `contracts/ledger-functional-api.md`: an asset whose quantity cannot be
      parsed as a decimal integer is still reported, still counts toward
      `asset_class_count`, and has its quantity rendered as `"0"`. Landed in
      slice 1 (T173a); this makes the behaviour contractual rather than hidden.
- [ ] T178 Proof: `nix run .#ledger-functional-openapi-check` and
      `just check-openapi` green.

## Slice 3 — regression-fixtures-and-parity

Commit subject: `test: prove per-asset control-group amounts across all surfaces`

- [ ] T179 Assess the committed review fixture for a control group holding more
      than one asset class; add one if absent.
- [ ] T180 Extend `tx-review-smoke` to assert an empty control group reports
      `assets == {}`.
- [ ] T181 Extend `tx-review-smoke` to assert a multi-asset control group
      reports each policy id, asset name, and exact quantity.
- [ ] T182 Confirm `tx-review-smoke` still compares WASI, native, and Extism
      `tx_review` bytes with the new field present on all three.
- [ ] T183 Proof: `just check-review` and `just check-extism-spike` green.

## Orchestrator-owned

- [ ] T184 Final: full `./gate.sh` green at HEAD, gate restored to `main`'s
      content, PR body audited, PR marked ready for review. Never self-merge.
