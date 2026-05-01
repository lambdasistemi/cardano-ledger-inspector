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

Browser provider adapters expose byte-fetch and context-fetch capabilities for
the current 0.1 inspection path:

```text
fetchTxCbor(network, credentials, tx_id) -> tx_cbor
fetchValidationContext(network, credentials) -> { network, slot, epoch, protocol_parameters }
```

`fetchTxCbor` opens the user-selected transaction and fetches producer
transactions needed for input context. Provider modules do not expose UTxO JSON
projection or ledger reconstruction helpers; producer-context arguments are
built by the host and interpreted by the Haskell ledger layer.

The browser host resolves validation context from the selected provider instead
of asking users to paste it. Koios uses `tip` plus `cli_protocol_params`;
Blockfrost uses `blocks/latest` plus `epochs/latest/parameters`, translating
the Blockfrost protocol-parameter response into the ledger-compatible shape.
If Blockfrost is selected but no project ID is configured, the browser still
fetches keyless Koios tip/protocol-parameter context and reports only the
producer transaction CBOR that could not be fetched.

## Current Operations

`tx.inspect`
: Decode and summarize the transaction using the ledger code.

`tx.browse`
: Return a navigable representation suitable for expanding transaction
  structure in the UI.

`tx.identify`
: Return stable transaction identifiers, byte-level metadata, and witness
  counts from the ledger-decoded transaction.

`tx.intent`
: Return the signer-focused answer to "what am I signing?" from the
  ledger-decoded transaction: visible effects, self-declared metadata claims,
  required signers, scripts, withdrawals, mint/burn, collateral, and explicit
  context coverage. Metadata is surfaced as self-declared intent, not verified
  off-chain truth.

`tx.witness.plan`
: Return transaction-derived signer, witness, script, redeemer, datum, and
  reference-input planning data. When `args.context.producer_txs` is present,
  Haskell decodes producer transactions and reports whether every visible input
  has resolved immutable output context. Without that context, it warns that
  input address credentials and reference scripts cannot be inferred from
  transaction CBOR alone.

`tx.validate`
: Return structured validation status for the selected transaction and explicit
  context. The operation reports `valid`, `invalid`, `incomplete`, or
  `rejected`, lists ledger check groups, preserves missing-context diagnostics,
  and runs Conway `applyTx` when producer transactions, network, slot, epoch,
  and protocol parameters are complete. It never mutates or returns transaction
  CBOR.

`tx.evaluate.scripts`
: Return structured phase-2 script evaluation status for the selected
  transaction and explicit context. The operation reports `succeeded`, `failed`,
  `incomplete`, `rejected`, or `not_applicable`, lists redeemers with budgeted
  and evaluated execution units, and preserves missing-context diagnostics. It
  never mutates or returns transaction CBOR.

The browser inspector now calls `tx.inspect`, `tx.identify`, `tx.intent`,
`tx.witness.plan`, and `tx.validate` from the same selected transaction CBOR.
When provider credentials are available, producer transaction CBOR fetched by
transaction id is passed as explicit `args.context.producer_txs`, and provider
tip/protocol-parameter data is passed as explicit validation context. Missing
governance, certificate, or failed provider context remains visible as
validation diagnostics rather than being guessed by the UI.

`tx.evaluate.scripts` is available through the WASI/API boundary; a dedicated
browser panel can be added separately once its UI flow is selected.

A complete positive request is committed at
[`specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json`](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json).
It validates the current mainnet fixture with producer transaction CBOR,
network, slot, epoch, and protocol parameters, and the smoke check asserts
`status: "valid"` and `valid_for_supplied_context: true`.

## Contract Source

The readable API page and detailed contract are tracked here:

- [API definition](api.md)
- [`specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`](https://github.com/lambdasistemi/cardano-ledger-wasi/blob/main/specs/001-ledger-functional-layer/contracts/ledger-functional-api.md)

## Direction

The 0.1 surface should keep growing around useful ledger operations: script
verification, transformation, patching, and eventually balancing where the
transaction has enough slack. Each operation should keep the same boundary
discipline: explicit inputs, ledger-owned semantics, CBOR for transaction
bytes, JSON for control and results.
