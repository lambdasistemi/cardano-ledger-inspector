# API Definition

The Cardano Ledger WASI API is a functional call boundary around Haskell ledger
code compiled to WASI. It is not a stateful RPC service: each operation receives
the current transaction CBOR and explicit arguments, then returns an explicit
result.

## Envelope

Requests use JSON for control data and CBOR hex for the transaction:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "tx_cbor": "<hex-encoded Conway transaction>",
  "op": "tx.inspect",
  "args": {}
}
```

Successful responses use the same versioned envelope:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "op": "tx.inspect",
  "result": {}
}
```

Transforming operations must return the new transaction bytes as
`result.tx_cbor`.

## Input Context

The host workspace owns transaction state and any fetched chain context. For
normal inspection and patch workflows, `TxIn`s are treated as the stable anchor:
producer transaction CBOR can be cached by transaction id and sent back on each
ledger call through `args.context.producer_txs`. The Haskell ledger layer
decodes those producer transactions and derives referenced outputs by
`tx_id#index`.

`args.input_policy` declares whether an operation may change inputs:

| Policy | Meaning |
| --- | --- |
| `preserve` | Default. The operation must keep the input set unchanged. |
| `may_extend` | The operation may add inputs and must report the additions. |
| `replace` | The operation may rebuild the input set and must report added and removed inputs. |

Producer transaction bytes are immutable. Live unspent status is mutable and
must be checked again before submission or live-chain validation.

## Implemented Operations

| Operation | Description |
| --- | --- |
| `tx.inspect` | Decode transaction CBOR with the Haskell ledger and return a compact summary plus the root browser view. |
| `tx.browse` | Decode transaction CBOR and return a browser view at `args.path`. |
| `tx.identify` | Return transaction id, body hash, era, byte size, fee, structural counts, and witness counts. |
| `tx.witness.plan` | Return signer, witness, script, redeemer, datum, reference-input, and explicit producer-transaction context coverage data. |

`tx.browse` request paths are arrays of strings. Object fields use their key
name and array indexes use `#<index>`, for example:

```json
{
  "tx_cbor": "<hex>",
  "op": "tx.browse",
  "args": {
    "path": ["body", "outputs", "#0"]
  }
}
```

## 0.1 Target Surface

The next API surface is organized around ledger operations that are useful to
wallets, inspectors, and transaction builders:

| Operation | Description |
| --- | --- |
| `tx.validate` | Full ledger validation with explicit UTxO, protocol, epoch, slot, governance, and network context. |
| `tx.evaluate.scripts` | Phase-2 script evaluation and execution-unit reporting with explicit context. |
| `tx.patch` | Ledger-aware structural patches that return new transaction CBOR. |
| `tx.balance` | Best-effort balancing of fees, change, collateral, and return value when the supplied context gives enough slack. |

Submitting transactions, signing with private keys, and multi-transaction
workspace management stay outside the ledger WASI layer.

## Source Contract

The detailed contract and schemas are tracked in the repository:

- [Functional API contract](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/contracts/ledger-functional-api.md)
- [OpenAPI document](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json)
- [Request schema](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/schemas/ledger-operation-request.schema.json)
- [Response schema](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/schemas/ledger-operation-response.schema.json)
- [Producer transaction context schema](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/schemas/producer-tx-context.schema.json)
- [Browser view schema](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/schemas/browser-view.schema.json)
- [tx.identify result schema](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/schemas/tx-identify-result.schema.json)
- [tx.witness.plan result schema](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/schemas/tx-witness-plan-result.schema.json)

The same OpenAPI bundle is a flake output:

```bash
nix build .#packages.x86_64-linux.ledger-functional-openapi -o result-openapi
```

It is also rendered in the published [Swagger UI](swagger.md).

## Current WASI Errors

The current WASI command writes no partial JSON response on failure. It writes
an error category to stderr and exits non-zero:

| Category | Meaning |
| --- | --- |
| `malformed_hex` | Transaction hex was not valid. |
| `malformed_cbor` | Hex decoded, but the ledger CBOR decoder rejected the transaction. |
| `malformed_ledger_operation` | stdin looked like JSON but did not parse as a ledger-operation request. |
| `unknown_ledger_operation` | `op` is not implemented. |
