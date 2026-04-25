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

## Current Operations

`tx.inspect`
: Decode and summarize the transaction using the ledger code.

`tx.browse`
: Return a navigable representation suitable for expanding transaction
  structure in the UI.

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
