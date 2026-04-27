# Quickstart: `tx.validate`

This quickstart describes the planned validation flow for implementers.

## 1. Build the WASI Operation

```bash
nix build .#packages.x86_64-linux.wasm-tx-inspector -o result-wasm
```

## 2. Validate Without Context

Start with the committed Conway fixture and no external context. The expected
result is `incomplete`, not a guessed failure.

```bash
jq -n \
  --rawfile tx specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex \
  '{
    ledger_functional_layer: "cardano-ledger-functional/v1",
    tx_cbor: ($tx | gsub("\\s"; "")),
    op: "tx.validate",
    args: {
      input_policy: "preserve",
      context: {}
    }
  }' > /tmp/tx-validate-request.json

wasmtime result-wasm/wasm-tx-inspector.wasm \
  < /tmp/tx-validate-request.json \
  > /tmp/tx-validate-response.json

jq '.result.validation.status' /tmp/tx-validate-response.json
```

Expected status:

```json
"incomplete"
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

## 4. Add Ledger State Context

Full validation requires more than producer transaction bytes. Provide explicit
network, slot/epoch, protocol parameters, and any certificate, stake, script, or
governance state required by the transaction.

Implementation status: `tx.validate` reports missing/invalid context before
validation. When the modeled context is complete, it builds the Conway
`LedgerState`/`LedgerEnv` from producer transaction outputs, protocol
parameters, network, slot, and epoch, then calls upstream `applyTx`. Ledger
rejections are returned in `failures` with the raw predicate text preserved.

If a required item is absent, the operation returns:

- `status: "incomplete"`
- a `missing_context` item naming what to provide next
- `checks[*].status: "not_evaluated"` for blocked checks

Positive fixture: `specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json`
contains a mainnet Conway transaction, the consumed input producer transaction,
both reference-input producer transactions, network/slot/epoch, and the Koios
CLI protocol parameters used for the supplied slot. Running it through the WASI
operation returns:

```json
{
  "status": "valid",
  "complete": true,
  "valid_for_supplied_context": true,
  "errors": [],
  "missing_context": [],
  "failures": []
}
```

The fixture is a validation example, not a submission guarantee. Live unspent
status is still outside this operation unless supplied by a separate live-chain
check.

## 5. Verify Contracts and CI Checks

Implementation tasks should add these commands:

```bash
just check-openapi
just check-swagger
just check-validate
just test
```

`just check-validate` should build the WASI artifact, run `tx.validate` against
fixtures, and assert the validation result shape. UI changes should also run:

```bash
just test-playwright
```

## 6. Browser Flow

After the WASI operation and contract checks are stable, the browser workbench
can add a validation panel:

1. Keep the selected transaction CBOR in the browser workspace.
2. Fetch producer transaction CBOR for visible inputs through provider byte
   fetchers when the user asks for validation context.
3. Fetch network, current slot, current epoch, and protocol parameters through
   the selected provider adapter. Koios uses `tip` plus `cli_protocol_params`;
   Blockfrost uses `blocks/latest` plus `epochs/latest/parameters`.
   If Blockfrost has no project ID, fall back to keyless Koios for this
   validation environment and keep producer transaction CBOR reported as
   missing until a byte provider is available.
4. Call `tx.validate` with current `tx_cbor` and explicit `args.context`.
5. Render `status`, `checks`, `failures`, `missing_context`, and resolved input
   rows with copyable hashes and paths back into the transaction browser.
