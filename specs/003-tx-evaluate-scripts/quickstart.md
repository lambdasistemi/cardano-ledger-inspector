# Quickstart: `tx.evaluate.scripts`

This quickstart describes the planned script-evaluation flow for implementers.

## 1. Build the WASI Operation

```bash
nix build .#packages.x86_64-linux.wasm-tx-inspector -o result-wasm
```

## 2. Evaluate Without Context

Start with a committed Conway transaction fixture and no external context. For
a transaction with phase-2 scripts, the expected result is `incomplete`, not a
guessed script failure.

```bash
jq -n \
  --rawfile tx specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex \
  '{
    ledger_functional_layer: "cardano-ledger-functional/v1",
    tx_cbor: ($tx | gsub("\\s"; "")),
    op: "tx.evaluate.scripts",
    args: {
      input_policy: "preserve",
      context: {}
    }
  }' > /tmp/tx-evaluate-scripts-request.json

wasmtime result-wasm/wasm-tx-inspector.wasm \
  < /tmp/tx-evaluate-scripts-request.json \
  > /tmp/tx-evaluate-scripts-response.json

jq '.result.script_evaluation.status' /tmp/tx-evaluate-scripts-response.json
```

Expected status for a scripted transaction without enough context:

```json
"incomplete"
```

A transaction without phase-2 scripts should return:

```json
"not_applicable"
```

## 3. Add Producer Transaction Context

When producer transaction bytes are available, pass them under
`args.context.producer_txs` keyed by transaction id. The ledger layer decodes
the producer transaction and resolves referenced outputs by output index.

```json
{
  "args": {
    "input_policy": "preserve",
    "context": {
      "producer_txs": {
        "<producer_tx_id>": {
          "tx_cbor": "<producer transaction hex>",
          "source": "blockfrost.txs.cbor"
        }
      },
      "resolution": {
        "provider": "blockfrost",
        "source": "tx-cbor",
        "unspent_status": "not_checked"
      }
    }
  }
}
```

The result should report each regular input and reference input under
`resolved_inputs` and `resolved_reference_inputs`.

## 4. Add Script Evaluation Context

Script evaluation requires more than producer transaction bytes. Provide
explicit network, slot/epoch, protocol parameters, cost models, and any
certificate, stake, datum, script, or governance context required by the
transaction.

If a required item is absent, the operation returns:

- `status: "incomplete"`
- a `missing_context` item naming what to provide next
- `redeemers[*].status: "not_evaluated"` for blocked redeemers

When complete context is supplied, the operation returns:

```json
{
  "status": "succeeded",
  "complete": true,
  "scripts_evaluate_for_supplied_context": true,
  "total_ex_units": {
    "memory": "123",
    "steps": "456",
    "partial": false
  },
  "errors": [],
  "missing_context": [],
  "failures": []
}
```

The result is a script-evaluation example, not a submission guarantee. Full
transaction validation, fee balancing, signing, and live-chain checks are
separate operations.

## 5. Verify Contracts and CI Checks

Implementation tasks should add these commands:

```bash
just check-openapi
just check-swagger
just check-evaluate-scripts
just test
```

UI changes should also run:

```bash
just test-playwright
```

## 6. Browser Flow

After the WASI operation and contract checks are stable, the browser workbench
can add a script-evaluation panel:

1. Keep the selected transaction CBOR in the browser workspace.
2. Fetch producer transaction CBOR for visible inputs through provider byte
   fetchers when the user asks for evaluation context.
3. Fetch network, current slot, current epoch, protocol parameters, and cost
   models through the selected provider adapter where available.
4. Call `tx.evaluate.scripts` with current `tx_cbor` and explicit
   `args.context`.
5. Render `status`, per-redeemer execution units, failures, missing context,
   and resolved input rows with copyable hashes and paths back into the
   transaction browser.
