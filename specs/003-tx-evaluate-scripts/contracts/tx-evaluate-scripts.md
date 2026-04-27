# Contract: `tx.evaluate.scripts`

Status: planned 0.1

`tx.evaluate.scripts` evaluates phase-2 scripts for the supplied candidate
transaction and explicit evaluation context. It is a functional ledger
operation, not a stateful RPC call, and it never mutates the transaction.

## Request

Use the existing ledger operation envelope:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "tx_cbor": "84a4...",
  "op": "tx.evaluate.scripts",
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
      "cost_models": {},
      "governance_state": {},
      "cert_state": {},
      "stake_distribution": {}
    }
  }
}
```

Arguments:

`input_policy`
: Optional. Defaults to `preserve`. `tx.evaluate.scripts` does not mutate the
  transaction; non-preserve policies are rejected in the initial contract.

`context.producer_txs`
: Optional producer transaction CBOR map keyed by transaction id. This is the
  preferred way to resolve regular inputs and reference inputs.

`context.resolution`
: Optional diagnostic metadata describing how producer transaction CBOR or
  other context facts were fetched. This metadata does not prove ledger facts by
  itself.

`context.network`
: Optional until evaluation needs it. Missing network context produces a
  `missing_context` item.

`context.slot` and `context.epoch`
: Optional decimal strings for time-sensitive script context. Missing values
  produce `missing_context` items when evaluation needs them.

`context.protocol_parameters`
: Optional object containing protocol parameters required by script evaluation.
  Missing required fields produce `missing_context` items.

`context.cost_models`
: Optional object for cost models when they are not supplied as part of
  protocol parameters.

`context.governance_state`, `context.cert_state`, `context.stake_distribution`
: Optional objects for scripts whose redeemer purposes need chain state beyond
  transaction bytes and referenced outputs.

## Response

Successful operation responses contain `result.script_evaluation`:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "op": "tx.evaluate.scripts",
  "result": {
    "script_evaluation": {
      "status": "incomplete",
      "scripts_evaluate_for_supplied_context": null,
      "complete": false,
      "tx_id": "1111111111111111111111111111111111111111111111111111111111111111",
      "body_hash": "2222222222222222222222222222222222222222222222222222222222222222",
      "redeemers": [
        {
          "key": "spend#0",
          "purpose": "spend",
          "index": 0,
          "status": "not_evaluated",
          "path": ["witnesses", "redeemers", "#0"],
          "script_hash": "33333333333333333333333333333333333333333333333333333333",
          "redeemer_data_hash": "4444444444444444444444444444444444444444444444444444444444444444",
          "budget_ex_units": {
            "memory": "1000000",
            "steps": "500000000"
          },
          "evaluated_ex_units": null,
          "missing_context": ["source_output"],
          "warnings": []
        }
      ],
      "total_ex_units": {
        "memory": "0",
        "steps": "0",
        "partial": true
      },
      "failures": [],
      "missing_context": [
        {
          "kind": "source_output",
          "message": "Provide producer transaction CBOR for this script input.",
          "path": ["body", "inputs", "#0"],
          "tx_id": "0000000000000000000000000000000000000000000000000000000000000000",
          "index": 0,
          "required_for": ["spend#0"]
        }
      ],
      "resolved_inputs": [],
      "resolved_reference_inputs": [],
      "context": {
        "input_policy": "preserve",
        "producer_tx_count": 0,
        "decoded_producer_tx_count": 0,
        "redeemer_count": 1,
        "evaluated_redeemer_count": 0,
        "unspent_status": "not_checked"
      },
      "warnings": [
        "Script evaluation does not submit, sign, balance, patch, or prove future network acceptance."
      ],
      "errors": []
    }
  }
}
```

Status semantics:

| Status | Meaning |
| --- | --- |
| `succeeded` | All phase-2 scripts evaluated successfully for the supplied context. |
| `failed` | Enough context was supplied and at least one phase-2 script failed. |
| `incomplete` | The operation needs more explicit context before it can evaluate all scripts. |
| `rejected` | Supplied context is malformed, contradictory, or unusable. |
| `not_applicable` | The transaction has no phase-2 scripts to evaluate. |

## Error Boundary

Malformed transaction hex, malformed CBOR, malformed operation envelopes, and
unknown operations keep the existing command-level error behavior. They are not
`result.script_evaluation` payloads.

Once a `tx.evaluate.scripts` request is decoded, no-script transactions, script
failures, missing context, and rejected evaluation context are represented in
the successful response envelope.

## Schema Artifacts

Draft feature schemas:

- [schemas/tx-evaluate-scripts-args.schema.json](./schemas/tx-evaluate-scripts-args.schema.json)
- [schemas/tx-evaluate-scripts-result.schema.json](./schemas/tx-evaluate-scripts-result.schema.json)

Implementation tasks must promote the result schema to
`specs/001-ledger-functional-layer/schemas/tx-evaluate-scripts-result.schema.json`,
add it to the generated OpenAPI source, and make `just check-openapi` compare
the committed artifact against the flake output.
