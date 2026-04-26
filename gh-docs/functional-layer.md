# Functional Layer

The functional layer is the boundary between host tools and ledger-backed
WASI operations. It is a functional API, not a stateful RPC service: the host
owns workspace state and passes the selected transaction CBOR into every
operation.

## Request Shape

Operations use a JSON control envelope. Transaction bytes remain CBOR hex.

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "tx_cbor": "84a4...",
  "op": "tx.inspect",
  "args": {
    "path": []
  }
}
```

## Response Shape

The response is JSON so browser tools, tests, and command-line users can
inspect it directly.

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "op": "tx.inspect",
  "result": {}
}
```

Transforming operations must return the resulting transaction as
`result.tx_cbor`.

## Workspace Context

The host owns workspace state. A selected transaction is sent as `tx_cbor` on
every operation, and immutable producer transaction bytes can be sent as
`args.context.producer_txs`.

The default `args.input_policy` is `preserve`: ordinary inspect, browse,
witness-planning, and patch operations keep the transaction input set unchanged.
Operations that add inputs for balancing use `may_extend`; operations that run
coin selection use `replace`.

Producer transaction CBOR is stable because transaction bytes are immutable.
The ledger layer derives referenced outputs by `tx_id#index`. Current unspent
status is not stable and belongs to live-chain validation or submission checks.

## Provider Boundary

Browser provider adapters expose one capability for the current 0.1 inspection
path:

```text
fetchTxCbor(network, credentials, tx_id) -> tx_cbor
```

The same capability opens the user-selected transaction and fetches producer
transactions needed for input context. Provider modules do not expose UTxO JSON
projection or ledger reconstruction helpers; producer-context arguments are
built by the host and interpreted by the Haskell ledger layer.

## Current Operations

`tx.inspect`
: Decode and summarize the transaction using the ledger code.

`tx.browse`
: Return a navigable representation suitable for expanding transaction
  structure in the UI.

`tx.identify`
: Return stable transaction identifiers, byte-level metadata, and witness
  counts from the ledger-decoded transaction.

`tx.witness.plan`
: Return transaction-derived signer, witness, script, redeemer, datum, and
  reference-input planning data. When `args.context.producer_txs` is present,
  Haskell decodes producer transactions and reports whether every visible input
  has resolved immutable output context. Without that context, it warns that
  input address credentials and reference scripts cannot be inferred from
  transaction CBOR alone.

## Contract Source

The readable API page and detailed contract are tracked here:

- [API definition](api.md)
- [`specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/contracts/ledger-functional-api.md)

## Direction

The 0.1 surface should grow around useful ledger operations: inspection,
validation, verification, transformation, patching, and eventually balancing
where the transaction has enough slack. Each operation should keep the same
boundary discipline: explicit inputs, ledger-owned semantics, CBOR for
transaction bytes, JSON for control and results.
