# Cardano Ledger WASI Functional API

Status: draft 0.1

Envelope: `cardano-ledger-functional/v1`

This contract defines the functional boundary between host applications and
Cardano ledger code compiled to WASI. It is not a stateful RPC service. Each
operation is a ledger-backed function over explicit inputs.

The host owns transaction workspace state. The ledger layer receives the
transaction CBOR plus operation arguments and returns explicit JSON results.

## Design Rules

- The Haskell ledger code is authoritative for decoding and ledger semantics.
- `tx_cbor` is the canonical transaction document for every transaction
  operation.
- JSON is the control plane and response view language.
- CBOR remains the data plane for full transactions and fidelity-sensitive
  ledger values.
- Validation, evaluation, balancing, and similar operations MUST receive all
  external context explicitly in `args`.
- Operations that transform a transaction MUST return the resulting
  transaction as `result.tx_cbor`.
- Normal inspection and patch operations SHOULD preserve the transaction input
  set. Operations that may extend or replace inputs MUST declare that through
  `args.input_policy` and MUST report the input diff in their result.

## Input Context Model

For most edit workflows, transaction inputs are the stable anchor. A `TxIn`
references an immutable historical output, so the resolved output data can be
cached by the host workspace and reused while the candidate transaction changes.

The ledger layer still receives that context explicitly on each call:

```json
{
  "input_policy": "preserve",
  "context": {
    "utxo": {
      "<tx_id>#<index>": {
        "tx_id": "<64 hex chars>",
        "index": 0,
        "address": "addr1...",
        "lovelace": "10000000",
        "assets": {},
        "datum_hash": null,
        "inline_datum_cbor": null,
        "reference_script_hash": null,
        "source": "blockfrost.txs.utxos.outputs",
        "unspent_status": "not_checked"
      }
    },
    "resolution": {
      "provider": "blockfrost",
      "source": "tx-input-producer-outputs",
      "requested_input_count": 1,
      "requested_reference_input_count": 0,
      "resolved_count": 1,
      "missing": [],
      "errors": [],
      "unspent_status": "not_checked"
    }
  }
}
```

Resolved output data and live chain status are intentionally separate:

- Resolved output data is immutable and safe to cache by `TxIn`.
- Live unspent status is mutable and must be checked again before submission or
  live-chain validation.

`input_policy` has three draft values:

`preserve`
: The operation must not change the input set. This is the default for
  inspection, witness planning, and ordinary patch operations.

`may_extend`
: The operation may add inputs, for example when balancing needs extra slack.
  It must report exactly which inputs were added.

`replace`
: The operation may rebuild the input set, for example coin selection. It must
  report added and removed inputs.

## Invocation Model

The first implementation is a WASI command:

- stdin: either a JSON ledger-operation request or legacy raw transaction hex.
- stdout: one successful JSON response.
- stderr: one error category and detail on failure.
- process status: zero on success, non-zero on failure.

Embedders MAY expose the same contract through an in-process function call.
They must preserve the same request and response shapes.

## Request Envelope

Canonical requests are JSON objects:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "tx_cbor": "<hex-encoded Conway transaction>",
  "op": "tx.inspect",
  "args": {}
}
```

Fields:

`ledger_functional_layer`
: Optional request envelope version. New callers SHOULD send
  `cardano-ledger-functional/v1`. The current WASI executable ignores unknown
  top-level fields, so this is advisory until request version enforcement is
  added.

`tx_cbor`
: Required. Hex-encoded transaction CBOR. Whitespace may be accepted by a
  command-line frontend, but callers SHOULD send continuous hex.

`op`
: Required. Ledger operation name.

`args`
: Optional. Operation-specific JSON arguments. Omitted `args` is equivalent to
  `{}`.

Common argument fields:

`input_policy`
: Optional. Defaults to `preserve`.

`context.utxo`
: Optional resolved UTxO map keyed by `tx_id#index`. The host workspace owns
  this state and sends it with operations that need input context.

Browser navigation example:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "tx_cbor": "<hex>",
  "op": "tx.browse",
  "args": {
    "path": ["body", "outputs", "#4", "value"]
  }
}
```

## Response Envelope

Successful ledger operations return JSON:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "op": "tx.inspect",
  "result": {}
}
```

Fields:

`ledger_functional_layer`
: Response envelope version.

`op`
: Operation that ran after compatibility normalization.

`result`
: Operation-specific JSON result.

Mutating operations MUST include the resulting transaction CBOR in
`result.tx_cbor`:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "op": "tx.patch",
  "result": {
    "tx_cbor": "<hex-encoded patched transaction>",
    "changes": []
  }
}
```

## Error Model

The current WASI command writes no partial JSON response on failure. It writes
`<category>: <detail>` to stderr and exits non-zero.

Current categories:

`malformed_hex`
: `tx_cbor` or legacy raw stdin was not valid hex.

`malformed_cbor`
: Hex decoded, but the ledger CBOR decoder rejected the transaction.

`malformed_ledger_operation`
: stdin looked like a JSON request but did not parse as a ledger-operation
  request.

`unknown_ledger_operation`
: The request was well formed, but `op` is not implemented.

A future host adapter may wrap these categories in a JSON error envelope, but
the command-line WASI boundary is stderr plus exit status for draft 0.1.

## Data Encoding

`tx_cbor`
: Hex string containing the full transaction CBOR.

Ledger bytes
: Hex strings. Field names should end in `_cbor`, `_hash`, `_id`, or another
  precise suffix that identifies the value.

Lovelace and token quantities
: Decimal strings when exactness matters across JavaScript runtimes. Small
  derived counts may be JSON numbers.

Paths
: Request paths are JSON arrays of strings. Object fields use their key name.
  Array indexes use `#<zero-based-index>`, for example `"#0"`.

Browser view paths
: The current `tx.browse` response returns `currentPath`, breadcrumb `path`,
  and row `path` as JSON-encoded path strings so the browser can pass them back
  unchanged. New request calls still send `args.path` as an array.

## Browser View

`tx.inspect` and `tx.browse` return a browser view used by the transaction UI:

```json
{
  "valid": true,
  "title": "outputs",
  "subtitle": "array / 5 items",
  "currentPath": "[\"body\",\"outputs\"]",
  "currentJson": "[...]",
  "breadcrumbs": [
    { "label": "tx", "path": "[]" },
    { "label": "body", "path": "[\"body\"]" },
    { "label": "outputs", "path": "[\"body\",\"outputs\"]" }
  ],
  "rows": [
    {
      "label": "#0",
      "path": "[\"body\",\"outputs\",\"#0\"]",
      "kind": "object",
      "summary": "4 fields",
      "copyValue": "{...}",
      "canDive": true
    }
  ]
}
```

`copyValue` is always the best available copyable representation for that row.
For strings it is the raw string value. For objects, arrays, booleans, numbers,
and null it is compact JSON.

## Operation Registry

| Operation | Status | Purpose |
| --- | --- | --- |
| `tx.inspect` | implemented | Decode transaction CBOR and return a compact summary plus root browser view. |
| `tx.browse` | implemented | Decode transaction CBOR and return a browser view at a path. |
| `tx.identify` | implemented | Return stable identifiers and metadata such as transaction id, body hash, era, size, and witness counts. |
| `tx.witness.plan` | implemented | Explain body-declared signer hashes, present witnesses, scripts, redeemers, datums, and reference inputs that are visible from the transaction alone. |
| `tx.validate` | 0.1 target | Run ledger validation with explicit UTxO, protocol, epoch, slot, and network context. |
| `tx.evaluate.scripts` | 0.1 target | Evaluate phase-2 scripts and report execution units or failures with explicit context. |
| `tx.patch` | 0.1 target | Apply a controlled structural patch and return new transaction CBOR. |
| `tx.balance` | 0.1 target | Try to balance fees, change, collateral, and return value when explicit context gives enough slack. |
| `tx.submit` | out of scope | Submission belongs to a node, wallet, or provider layer, not the ledger WASI layer. |
| `tx.sign` | out of scope | Private key custody and signing are outside this repository. |
| `workspace.*` | out of scope | Multi-transaction workspace state belongs to the host application. |

## Implemented Operations

### `tx.inspect`

Decode the supplied transaction CBOR with the Haskell ledger and return:

```json
{
  "inspection": {},
  "browser": {}
}
```

`inspection` is a compact transaction summary. `browser` is the root browser
view used by the UI.

Arguments:

`path`
: Optional path array. If supplied, the returned browser view opens at that
  path. If omitted, the browser view opens at the transaction root.

### `tx.browse`

Decode the supplied transaction CBOR with the Haskell ledger and return the
browser view at `args.path`:

```json
{
  "browser": {}
}
```

Arguments:

`path`
: Optional path array. Invalid paths fall back to the transaction root in the
  current implementation.

The browser MUST send the full current `tx_cbor` on every browse operation.
The ledger layer MAY cache decoded values, but cache state is not authoritative.

### `tx.identify`

Decode the supplied transaction CBOR with the Haskell ledger and return stable
identifiers plus byte-level metadata:

```json
{
  "identification": {
    "era": "Conway",
    "tx_id": "<transaction id hex>",
    "body_hash": "<body hash hex>",
    "tx_size_bytes": 1234,
    "fee_lovelace": "0",
    "input_count": 0,
    "reference_input_count": 0,
    "output_count": 0,
    "cert_count": 0,
    "withdrawal_count": 0,
    "required_signer_count": 0,
    "witness_counts": {
      "vkey": 0,
      "bootstrap": 0,
      "native_script": 0,
      "plutus_v1": 0,
      "plutus_v2": 0,
      "plutus_v3": 0,
      "redeemer": 0,
      "datum": 0
    }
  }
}
```

Arguments: none.

### `tx.witness.plan`

Decode the supplied transaction CBOR with the Haskell ledger and return the
transaction-derived witness plan:

```json
{
  "witness_plan": {
    "required_signers": [],
    "present_vkey_witnesses": [],
    "present_bootstrap_witnesses": [],
    "missing_vkey_witnesses": [],
    "scripts": [],
    "redeemers": [],
    "datums": [],
    "reference_inputs": [],
    "summary": {
      "required_signer_count": 0,
      "present_vkey_witness_count": 0,
      "present_bootstrap_witness_count": 0,
      "missing_vkey_witness_count": 0,
      "script_count": 0,
      "redeemer_count": 0,
      "datum_count": 0,
      "reference_input_count": 0
    },
    "warnings": []
  }
}
```

Arguments:

`input_policy`
: Optional. Defaults to `preserve`.

`context.utxo`
: Optional. Resolved UTxO map keyed by `tx_id#index`.

When `context.utxo` is absent, the operation remains transaction-only. It can
compare `required_signers` from the transaction body with vkey/bootstrap
witnesses already present in the witness set, and it can report script
witnesses, redeemers, witness datums, and reference inputs. It cannot infer
input address credentials, datum hashes needed by consumed UTxOs, or reference
scripts without explicit UTxO context, so it returns a transaction-only warning.

When `context.utxo` is present, the operation reports coverage in
`witness_plan.context`, plus `resolved_inputs` and
`resolved_reference_inputs`. This first context-aware slice verifies that every
visible input has immutable resolved-output context; deeper ledger TxOut
reconstruction and credential inference are follow-up work.

## 0.1 Target Operations

These operations define the next API surface. They are intentionally explicit
about context because a transaction alone is not enough for full ledger checks
or balancing.

### `tx.validate`

Run ledger validation for a transaction in an explicit context.

Arguments:

```json
{
  "network": "mainnet",
  "slot": 0,
  "epoch": 0,
  "protocol_parameters": {},
  "utxo": {},
  "governance_state": {},
  "cert_state": {},
  "stake_distribution": {}
}
```

The exact context schema will be refined against the ledger API used by the
implementation. If a check requires state not supplied in `args`, the operation
MUST return a structured missing-context failure rather than guessing.

Result:

```json
{
  "valid": true,
  "checks": [],
  "failures": [],
  "warnings": []
}
```

### `tx.evaluate.scripts`

Evaluate scripts and report execution units or ledger failures.

Arguments:

```json
{
  "network": "mainnet",
  "slot": 0,
  "protocol_parameters": {},
  "utxo": {},
  "cost_models": {}
}
```

Result:

```json
{
  "valid": true,
  "redeemers": [],
  "total_ex_units": {
    "memory": "0",
    "steps": "0"
  },
  "failures": [],
  "warnings": []
}
```

### `tx.patch`

Apply a controlled transaction patch and return new transaction CBOR.

Arguments:

```json
{
  "patches": [
    {
      "op": "replace",
      "path": ["body", "fee"],
      "value": { "lovelace": "200000" }
    }
  ]
}
```

Patch operations should be ledger-aware rather than arbitrary JSON mutation.
For example, replacing a fee must rebuild the transaction body through ledger
types and return the new CBOR.

Result:

```json
{
  "tx_cbor": "<hex>",
  "changes": [],
  "warnings": []
}
```

### `tx.balance`

Best-effort transaction balancing. Balancing may fail when the transaction has
insufficient slack, missing context, no suitable change output, or incompatible
collateral requirements.

Arguments:

```json
{
  "network": "mainnet",
  "slot": 0,
  "protocol_parameters": {},
  "utxo": {},
  "change": {
    "address": "<bech32 or hex address>",
    "policy": "preserve-existing-or-add"
  },
  "constraints": {
    "max_extra_inputs": 0,
    "allow_output_reordering": false,
    "allow_collateral_change": true
  }
}
```

Result:

```json
{
  "balanced": true,
  "tx_cbor": "<hex>",
  "fee": { "lovelace": "0" },
  "selected_inputs": [],
  "change_outputs": [],
  "warnings": []
}
```

## Schemas

Machine-readable draft schemas are tracked next to this contract:

- `../openapi/cardano-ledger-functional.openapi.json`
- `../schemas/ledger-operation-request.schema.json`
- `../schemas/ledger-operation-response.schema.json`
- `../schemas/utxo-context.schema.json`
- `../schemas/browser-view.schema.json`
- `../schemas/tx-identify-result.schema.json`
- `../schemas/tx-witness-plan-result.schema.json`

The OpenAPI document is packaged as the `ledger-functional-openapi` flake
output and rendered by the published Swagger UI. The schemas describe the draft
0.1 envelopes, currently implemented browser view, and implemented operation
results.

## Compatibility

During the transition from the earlier browser prototype, the WASI executable
MAY accept legacy requests containing `method` and top-level `path`. New callers
MUST use `op` and `args.path`.

Legacy operation names are normalized:

| Legacy | Canonical |
| --- | --- |
| `inspect` | `tx.inspect` |
| `browse` | `tx.browse` |
| `identify` | `tx.identify` |
| `witness.plan` | `tx.witness.plan` |
