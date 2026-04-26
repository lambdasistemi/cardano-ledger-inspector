# Contract: `tx.validate`

Status: planned 0.1

`tx.validate` runs ledger validation over the supplied candidate transaction and
explicit validation context. It is a functional ledger operation, not a
stateful RPC call.

## Request

Use the existing ledger operation envelope:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "tx_cbor": "84a4...",
  "op": "tx.validate",
  "args": {
    "input_policy": "preserve",
    "context": {
      "producer_txs": {
        "0000000000000000000000000000000000000000000000000000000000000000": {
          "tx_cbor": "84a4...",
          "source": "blockfrost.txs.cbor"
        }
      },
      "resolution": {
        "provider": "blockfrost",
        "source": "tx-cbor",
        "requested_input_count": 1,
        "requested_reference_input_count": 0,
        "requested_tx_count": 1,
        "resolved_count": 1,
        "missing": [],
        "errors": [],
        "unspent_status": "not_checked"
      },
      "network": "mainnet",
      "slot": "0",
      "epoch": "0",
      "protocol_parameters": {},
      "governance_state": {},
      "cert_state": {},
      "stake_distribution": {}
    }
  }
}
```

Arguments:

`input_policy`
: Optional. Defaults to `preserve`. `tx.validate` does not mutate the
  transaction; non-preserve policies are rejected in the initial contract.

`context.producer_txs`
: Optional producer transaction CBOR map keyed by transaction id. This is the
  preferred way to resolve regular inputs and reference inputs.

`context.resolution`
: Optional diagnostic metadata describing how producer transaction CBOR was
  fetched. This metadata does not prove ledger facts by itself.

`context.network`
: Optional until a check needs it. Missing network context produces a
  `missing_context` item.

`context.slot` and `context.epoch`
: Optional decimal strings for time-sensitive checks. Missing values produce
  `missing_context` items when a check needs them.

`context.protocol_parameters`
: Optional object containing protocol parameters required by ledger checks.
  Missing required fields produce `missing_context` items.

`context.governance_state`, `context.cert_state`, `context.stake_distribution`
: Optional objects for checks that need chain state beyond transaction bytes and
  referenced outputs.

## Response

Successful operation responses contain `result.validation`:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "op": "tx.validate",
  "result": {
    "validation": {
      "status": "incomplete",
      "valid_for_supplied_context": null,
      "complete": false,
      "tx_id": "1111111111111111111111111111111111111111111111111111111111111111",
      "body_hash": "2222222222222222222222222222222222222222222222222222222222222222",
      "checks": [
        {
          "id": "input.source_outputs",
          "title": "Input source outputs",
          "status": "not_evaluated",
          "scope": "inputs",
          "required_context": ["source_output"],
          "message": "One or more transaction inputs have no resolved source output."
        }
      ],
      "failures": [],
      "missing_context": [
        {
          "kind": "source_output",
          "message": "Provide producer transaction CBOR for this input.",
          "path": ["body", "inputs", "#0"],
          "tx_id": "0000000000000000000000000000000000000000000000000000000000000000",
          "index": 0,
          "required_for": ["input.source_outputs"]
        }
      ],
      "resolved_inputs": [
        {
          "key": "0000000000000000000000000000000000000000000000000000000000000000#0",
          "tx_id": "0000000000000000000000000000000000000000000000000000000000000000",
          "index": 0,
          "kind": "input",
          "path": ["body", "inputs", "#0"],
          "resolved": false,
          "reason": "producer transaction CBOR not supplied"
        }
      ],
      "resolved_reference_inputs": [],
      "context": {
        "input_policy": "preserve",
        "producer_tx_count": 0,
        "decoded_producer_tx_count": 0,
        "input_count": 1,
        "resolved_input_count": 0,
        "missing_input_count": 1,
        "reference_input_count": 0,
        "resolved_reference_input_count": 0,
        "missing_reference_input_count": 0,
        "unspent_status": "not_checked"
      },
      "warnings": [
        "Live unspent status is not checked by this operation unless supplied explicitly."
      ],
      "errors": []
    }
  }
}
```

Status semantics:

| Status | Meaning |
| --- | --- |
| `valid` | All required validation checks ran and passed for the supplied context. |
| `invalid` | Enough context was supplied and at least one ledger check failed. |
| `incomplete` | The operation needs more explicit context before it can decide. |
| `rejected` | Supplied context is malformed, contradictory, or unusable. |

## Error Boundary

Malformed transaction hex, malformed CBOR, malformed operation envelopes, and
unknown operations keep the existing command-level error behavior. They are not
`result.validation` payloads.

Once a `tx.validate` request is decoded, invalid transactions, missing context,
and rejected validation context are represented in the successful response
envelope.

## Schema Artifacts

Draft feature schemas:

- [schemas/tx-validate-args.schema.json](./schemas/tx-validate-args.schema.json)
- [schemas/tx-validate-result.schema.json](./schemas/tx-validate-result.schema.json)

Implementation tasks must promote the result schema to
`specs/001-ledger-functional-layer/schemas/tx-validate-result.schema.json`, add
it to the generated OpenAPI source, and make `just check-openapi` compare the
committed artifact against the flake output.
