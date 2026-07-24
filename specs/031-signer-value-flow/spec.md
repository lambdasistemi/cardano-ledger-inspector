# Feature Specification: Signer-Facing Transaction Review

**Feature Branch**: `feat/31-signer-value-flow`
**Created**: 2026-07-24
**Status**: Ready for implementation
**Input**: GitHub issue #31 and the signer-review repair lane rooted at
`cardano-swiss-knife#74`.

## User Story

As a transaction signer, I need one structured review result that explains
where value comes from, where it goes, what remains under signer control, and
which conclusions are facts versus claims, so I can decide whether to sign
without interpreting raw CBOR or a ledger-field dump.

## Acceptance Scenarios

1. Given any decodable Conway transaction without producer context,
   `tx.review` returns output control groups, fee, collateral, withdrawals,
   and read-only reference-input facts while explicitly stating that net
   signer gain or loss is unprovable.
2. Given complete producer context, `tx.review` reports resolved regular-input
   value and a provable signer net result using the existing `tx.intent`
   signer-control semantics.
3. Given the issue's SundaeSwap/USDM disbursement fixture and its available
   producer transaction, the review distinguishes the treasury continuation,
   SundaeSwap order outputs, unlabeled script value, external-key value, fee,
   collateral, and missing input context.
4. Given metadata that declares a swap or destination, the review presents it
   only as a self-declared metadata claim; it does not use that text to assert
   an output role.
5. Given WASI, native, and Extism invocations of the same request, all three
   targets return byte-identical `tx.review` response bytes.

## Functional Requirements

- **FR-001**: The local target-independent wrapper MUST implement the canonical
  `tx.review` operation and MAY accept the legacy short name `review`.
- **FR-002**: `tx.review` MUST be a deterministic projection over the shared,
  locally enriched `tx.intent` result plus the same decoded Conway
  transaction. It MUST NOT reimplement the operation separately in WASI,
  native, Extism, a host adapter, or a browser.
- **FR-003**: A review response MUST contain a versioned
  `result.review` object with transaction identity, context status, value
  sources, output control groups, high-value movements, fee, collateral,
  net-signer-value status, metadata claims, and warnings.
- **FR-004**: Output control categories MUST be exactly
  `signer_controlled`, `external_key`, `script`, `bootstrap`, and `unknown`.
  Existing `tx.intent` signer matching remains the authority for the first
  four; missing or unrecognized classification maps to `unknown`.
- **FR-005**: Evidence provenance MUST use explicit tags:
  `ledger_proven`, `context_proven`, `registry_decoded`,
  `metadata_claim`, and `heuristic`.
- **FR-006**: Output groups MUST be deterministic and group outputs by control
  category, address, and role. Each group MUST include output indices, output
  count, lovelace total, asset-class count, addresses, role label, role
  provenance, and evidence tags.
- **FR-007**: Registry-decoded datum labels MAY name protocol roles. A
  signer-controlled return/change label is heuristic. A same-address output
  returning to a resolved input's script or key address MAY be labeled a
  continuation only with `context_proven` evidence. Metadata text MUST NOT
  supply any of those role labels.
- **FR-008**: High-value movements MUST be surfaced in descending lovelace
  order. The deterministic inclusion rule is every control group containing
  at least one percent of total output lovelace, with the largest non-empty
  group always included.
- **FR-009**: Regular inputs, withdrawals, collateral inputs, and reference
  inputs MUST be separate sources. Reference inputs MUST be marked read-only.
  Collateral MUST be marked conditional and report body-declared total and
  collateral-return value independently from regular transaction outputs.
- **FR-010**: The net-signer-value object MUST contain `provable`, nullable
  `lovelace`, and a plain-language note. It MUST be unprovable whenever not
  every regular input is resolved from explicit producer transaction CBOR.
- **FR-011**: Metadata claims MUST be copied into a separate collection with
  `metadata_claim` provenance and a self-declared marker. Claims MUST never
  change a control category, output role, amount, or high-value decision.
- **FR-012**: The issue CBOR MUST remain the regression fixture; no duplicate
  transaction fixture may be introduced. Its existing producer fixture MUST
  be used to prove the intentionally incomplete-context path.
- **FR-013**: The fixture review MUST make these facts directly queryable:
  fee `1043795` lovelace; 12 outputs; output 0 as an approximately
  1.041-billion-lovelace treasury-script continuation; outputs 1 through 9 as
  registry-decoded SundaeSwap order locks; output 10 as an unlabeled script
  lock; output 11 as external-key value; one collateral input with separate
  total and return amounts; and one missing regular input.
- **FR-014**: The Extism plugin MUST export `tx_review`, and registered plus
  unknown-registry cases MUST be byte-identical across WASI, native, and
  Extism through the shared wrapper.
- **FR-015**: JSON schema, generated OpenAPI, operation registry, public API
  documentation, architecture documentation, installation/export lists, and
  release-asset descriptions MUST describe the new operation.
- **FR-016**: Existing operation response bytes, including `tx.intent`, MUST
  remain unchanged.
- **FR-017**: The permanent tracked `gate.sh` MUST remain present and
  unchanged. New checks MUST be reached through `just ci`.

## Review Wire Contract

The stable top-level shape is:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "op": "tx.review",
  "result": {
    "review": {
      "version": "cardano-tx-review/v1",
      "tx_id": "<hex>",
      "body_hash": "<hex>",
      "context": {
        "input_status": "incomplete",
        "regular_input_count": 0,
        "resolved_regular_input_count": 0,
        "missing_regular_input_count": 0
      },
      "sources": [],
      "control_groups": [],
      "high_value_movements": [],
      "fee": {},
      "collateral": {},
      "net_signer_value": {
        "provable": false,
        "lovelace": null,
        "note": "missing input context, net signer gain/loss unprovable"
      },
      "claims": [],
      "warnings": []
    }
  }
}
```

Numeric ledger quantities are decimal strings so values remain lossless in
JavaScript consumers. Arrays and groups have deterministic ordering.

## Success Criteria

- **SC-001**: The review-vocabulary unit check observes RED before its types and
  encoders exist, then passes after the first slice.
- **SC-002**: The review smoke validates both a complete-context request and
  the issue fixture's incomplete-context request.
- **SC-003**: The issue fixture's high-value list starts with the treasury
  continuation and separately includes the aggregated swap-order and
  external-key groups.
- **SC-004**: Raw byte comparisons pass for WASI/native/Extism registered and
  unknown-registry review requests.
- **SC-005**: Existing `just check-intent` remains byte-stable and green.
- **SC-006**: `./gate.sh` succeeds at final HEAD, and fresh required pull
  request checks all conclude successfully.

## Edge Cases

- A transaction can have no outputs, no required signers, no witnesses, no
  withdrawals, no collateral, or no reference inputs.
- A valid output can be a bootstrap address; future or unrecognized output
  classification is represented as `unknown`, never guessed.
- Total output lovelace can be zero; the high-value list is then empty.
- Producer context can be absent, partial, malformed, or contain unrelated
  transactions. Only successfully resolved regular inputs contribute
  context-proven values.
- Registry decoding can be unavailable. Ledger classification and value facts
  still return; protocol roles remain generic.
- Multiple outputs with the same address but different decoded roles stay in
  separate groups.

## Non-Goals

- Rendering the table or graph in `cardano-swiss-knife`.
- Provider calls, hidden context, wallet discovery, or address-book lookup.
- Proving real-world ownership beyond transaction-declared/witnessed signer
  credentials and explicit producer context.
- Treating metadata as authorization, validation, or truth.
- Signing, submitting, balancing, or mutating a transaction.
