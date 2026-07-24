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

The response is JSON so host tools, tests, and command-line users can
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

Provider adapters belong to hosts, outside the ledger engine. A host can expose
byte-fetch and context-fetch capabilities such as:

```text
fetchTxCbor(network, credentials, tx_id) -> tx_cbor
fetchValidationContext(network, credentials) -> { network, slot, epoch, protocol_parameters }
```

`fetchTxCbor` can open a selected transaction and fetch producer
transactions needed for input context. Provider modules must not reconstruct
ledger state from lossy UTxO JSON; producer-context arguments are built by the
host and interpreted by the Haskell ledger layer. The cardano-swiss-knife
workbench owns the browser provider integrations that consume this boundary.

## Current Operations

`tx.inspect`
: Decode and summarize the transaction using the ledger code.

`tx.browse`
: Return a navigable representation suitable for expanding transaction
  structure in a host.

`tx.identify`
: Return stable transaction identifiers, byte-level metadata, and witness
  counts from the ledger-decoded transaction.

`tx.intent`
: Return the signer-focused answer to "what am I signing?" from the
  ledger-decoded transaction: visible effects, self-declared metadata claims,
  required signers, scripts, withdrawals, mint/burn, collateral, and explicit
  context coverage. Metadata is surfaced as self-declared intent, not verified
  off-chain truth.

`tx.review`
: Project the shared, locally enriched `tx.intent` result into one versioned
  signer-facing review (`result.review`): output control groups (signer
  controlled, external key, script, bootstrap, unknown), value sources kept
  separate (regular inputs, withdrawals, conditional collateral, read-only
  reference inputs), high-value movements in descending lovelace order, fee,
  collateral, net-signer-value status, and isolated self-declared metadata
  claims. The net signer result is provable only when every regular input
  resolves from explicit producer transaction CBOR; otherwise it is reported
  unprovable. Recognized in the target-independent wrapper, so WASI, native,
  and Extism return byte-identical review bytes.

`tx.witness.plan`
: Return transaction-derived signer, witness, script, redeemer, datum, and
  reference-input planning data. When `args.context.producer_txs` is present,
  Haskell decodes producer transactions and reports whether every visible input
  has resolved immutable output context. Without that context, it warns that
  input address credentials and reference scripts cannot be inferred from
  transaction CBOR alone.

`tx.witness.attach`
: Decode one hex-encoded vkey witness and attach it upstream in Haskell rather
  than browser-only JavaScript. The operation only inserts or replaces the
  matching vkey witness, preserves all other witness-set content, returns the
  patched bytes at `result.tx_cbor`, and reports stable `errors[]` diagnostics
  when the witness payload is missing or malformed. It does not handle secret
  keys.

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

Hosts call operations from the same selected transaction CBOR. When provider
credentials are available, producer transaction CBOR fetched by transaction id
is passed as explicit `args.context.producer_txs`, and provider
tip/protocol-parameter data is passed as explicit validation context. Missing
governance, certificate, or provider context remains visible as validation
diagnostics rather than being guessed by the engine.

`tx.witness.attach` is available through the same WASI/API boundary for
signing flows, so hosts can share the same witness-set patching logic.

`tx.evaluate.scripts` is available through the same WASI/API boundary for
hosts that need phase-2 evaluation.

A complete positive request is committed at
[`specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json`](https://github.com/lambdasistemi/cardano-ledger-inspector/blob/main/specs/001-ledger-functional-layer/fixtures/tx-validate-complete-request.json).
It validates the current mainnet fixture with producer transaction CBOR,
network, slot, epoch, and protocol parameters, and the smoke check asserts
`status: "valid"` and `valid_for_supplied_context: true`.

## Contract Source

The readable API page and detailed contract are tracked here:

- [API definition](api.md)
- [`specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`](https://github.com/lambdasistemi/cardano-ledger-inspector/blob/main/specs/001-ledger-functional-layer/contracts/ledger-functional-api.md)

## Direction

The 0.1 surface should keep growing around useful ledger operations: script
verification, transformation, patching, and eventually balancing where the
transaction has enough slack. Each operation should keep the same boundary
discipline: explicit inputs, ledger-owned semantics, CBOR for transaction
bytes, JSON for control and results.
