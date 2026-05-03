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
references an immutable historical output. The host can fetch and cache the
producer transaction CBOR by transaction id while the candidate transaction
changes.

The ledger layer still receives that context explicitly on each call:

```json
{
  "input_policy": "preserve",
  "context": {
    "producer_txs": {
      "<producer_tx_id>": {
        "tx_cbor": "<hex-encoded producer transaction>",
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
    }
  }
}
```

Producer transaction data and live chain status are intentionally separate:

- Producer transaction CBOR is immutable and safe to cache by transaction id.
- Haskell derives referenced outputs from decoded producer transactions by
  `tx_id#index`.
- Live unspent status is mutable and must be checked again before submission or
  live-chain validation.

## Provider Boundary

Provider adapters are byte fetchers, not ledger interpreters. The current
required provider capabilities are:

```text
fetchTxCbor(network, credentials, tx_id) -> tx_cbor
fetchValidationContext(network, credentials) -> { network, slot, epoch, protocol_parameters }
```

`fetchTxCbor` opens the transaction selected by hash and fetches producer
transactions for `context.producer_txs`. Provider modules MUST NOT expose
provider-specific UTxO JSON as the core ledger interface. If later operations
need additional mutable chain state, that capability must be added explicitly
with a ledger-facing schema and must not replace transaction CBOR as the byte
data plane.

Browser hosts use provider tip and protocol-parameter endpoints to populate the
explicit validation context. The ledger operation still receives those values
inside `args.context` on every call; it does not reach out to providers or hold
hidden state.

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

`context.producer_txs`
: Optional producer transaction CBOR map keyed by transaction id. The host
  workspace owns this byte cache and sends it with operations that need input
  context.

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
| `tx.intent` | implemented | Return a signer-focused summary of visible transaction effects, signer value perspective, self-declared metadata intent, required signers, scripts, withdrawals, mint/burn, collateral, and context coverage. |
| `tx.witness.plan` | implemented | Explain body-declared signer hashes, present witnesses, scripts, redeemers, datums, and reference inputs that are visible from the transaction alone. |
| `tx.validate` | implemented | Report whether explicit validation context is usable or incomplete; run Conway `applyTx` when modeled context is complete. |
| `tx.evaluate.scripts` | implemented | Evaluate phase-2 scripts and report per-redeemer execution units or failures with explicit context. |
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

### `tx.intent`

Decode the supplied transaction CBOR with the Haskell ledger and return the
signer-focused answer to "what am I signing?" The operation is informational:
it does not sign, validate, submit, balance, patch, or mutate the transaction.

```json
{
  "intent": {
    "title": "Signing summary",
    "subtitle": "1 metadata claim / 2 missing required signers / 2 redeemers",
    "metrics": [
      { "label": "Fee", "value": "1.043795 ADA" },
      { "label": "Signer net ADA", "value": "unknown" },
      { "label": "Missing signers", "value": "2 missing required signers" }
    ],
    "claims": [
      {
        "label": "Swap ADA<->USDM",
        "value": "Swapping ADA for $100k at a rate of $0.245 per ADA",
        "detail": "Required to pay Antithesis as vendor / destination Network Compliance's treasury / metadata label 1694 / self-declared"
      }
    ],
    "sections": [
      {
        "title": "Signer value perspective",
        "empty": "No signer value perspective available.",
        "rows": [
          {
            "label": "Net signer ADA",
            "value": "unknown",
            "path": "[\"intent\",\"value\",\"signer_perspective\",\"#0\"]",
            "copyValue": "unknown",
            "detail": "producer transaction CBOR must resolve every regular input before signer net can be known"
          }
        ]
      },
      {
        "title": "Critical effects",
        "empty": "No transaction effects reported.",
        "rows": []
      },
      {
        "title": "Declared required signers",
        "empty": "No declared required signers.",
        "rows": [
          {
            "label": "declared required signer",
            "value": "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1",
            "path": "[\"intent\",\"signing\",\"required_signers\",\"#0\",\"hash\"]",
            "copyValue": "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1",
            "detail": "declared required signer not present in vkey or bootstrap witnesses"
          }
        ]
      },
      {
        "title": "Missing required signers",
        "empty": "None missing.",
        "rows": [
          {
            "label": "declared required signer not present in vkey or bootstrap witnesses",
            "value": "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1",
            "path": "[\"intent\",\"signing\",\"missing_vkey_witnesses\",\"#0\",\"hash\"]",
            "copyValue": "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1",
            "detail": "declared required signer not present in vkey or bootstrap witnesses"
          }
        ]
      }
    ],
    "signing": {
      "missing_vkey_witness_count": 2,
      "missing_vkey_witnesses": [
        {
          "hash": "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1",
          "reason": "declared required signer not present in vkey or bootstrap witnesses"
        }
      ],
      "present_bootstrap_witness_count": 0,
      "present_bootstrap_witnesses": [],
      "present_vkey_witness_count": 0,
      "present_vkey_witnesses": [],
      "required_signer_count": 2,
      "required_signers": [
        {
          "hash": "8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1",
          "source": "tx_body.required_signers",
          "witness_status": "missing"
        },
        {
          "hash": "f3ab64b0f97dcf0f91232754603283df5d75a1201337432c04d23e2e",
          "source": "tx_body.required_signers",
          "witness_status": "missing"
        }
      ]
    },
    "withdrawals": [
      {
        "index": 0,
        "reward_account_hex": "f1a64d1b9e1aeffe54056034d84977061b45a92691efc282fbee3fc094",
        "network": "mainnet",
        "credential": {
          "kind": "script",
          "hash": "a64d1b9e1aeffe54056034d84977061b45a92691efc282fbee3fc094"
        },
        "amount_lovelace": "0"
      }
    ],
    "value": {
      "net_spend_known": false,
      "net_spend_note": "Signer net is unknown until producer transaction CBOR resolves every regular input; output totals are still ledger facts.",
      "signer_lovelace": {
        "known": false,
        "resolved_input_lovelace": "0",
        "output_lovelace": "0",
        "external_or_script_output_lovelace": "1212430755481",
        "net_lovelace": null,
        "basis": "payment key credentials matching declared required signers or present key witnesses"
      },
      "resolved_input_buckets": [],
      "output_buckets": [
        {
          "bucket": "script",
          "label": "Script",
          "tx_out_count": 11,
          "lovelace": "1162532800000",
          "asset_class_count": 0
        }
      ]
    },
    "warnings": [
      "Metadata describes intent but is self-declared; verify it against the destination addresses and contract policy."
    ]
  }
}
```

The summary fields are generated by the WASI ledger operation. Browser hosts
may render `metrics`, `claims`, `sections`, and `warnings` directly, while the
additional structured fields (`metadata_claims`, `signing`, `value`,
`features`, `withdrawals`, `effects`, and `context`) remain available for API
consumers. Each `withdrawals[]` row exposes the serialized reward-account hex,
its network and staking credential, and the withdrawn lovelace amount. Each
`signing.required_signers[]` row exposes the declared signer hash, its source,
and whether that signer is already covered by a vkey witness, a bootstrap
witness, or still missing.
When `context.producer_txs` resolves every regular input, `value.signer_lovelace`
reports a known net ADA amount from resolved signer-controlled inputs minus
signer-controlled outputs. Ownership is intentionally conservative: only output
payment key credentials matching declared required signers or present key
witnesses count as signer-controlled. Other outputs are bucketed as external
key, script, or bootstrap/other.

Arguments:

`input_policy`
: Optional. Defaults to `preserve`.

`context.producer_txs`
: Optional producer transaction CBOR map keyed by transaction id. When present,
  source-output totals and context coverage are derived by decoding those
  producer transactions. Live unspent status is still not checked here.

Metadata claims are self-declared transaction metadata. The operation surfaces
them prominently because they are often the only human explanation attached to
a transaction, but callers MUST NOT treat them as verified off-chain facts.

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

`context.producer_txs`
: Optional. Producer transaction CBOR map keyed by transaction id.

When `context.producer_txs` is absent, the operation remains transaction-only.
It can compare `required_signers` from the transaction body with
vkey/bootstrap witnesses already present in the witness set, and it can report
script witnesses, redeemers, witness datums, and reference inputs. It cannot
infer input address credentials, datum hashes needed by consumed UTxOs, or
reference scripts without producer transaction context, so it returns a
transaction-only warning.

When `context.producer_txs` is present, Haskell decodes those producer
transactions and resolves visible inputs by selecting `outputs[index]` from the
matching producer transaction. The operation reports coverage in
`witness_plan.context`, plus `resolved_inputs` and
`resolved_reference_inputs`.

### `tx.validate`

Decode the supplied Conway transaction and report whether explicit validation
context is missing or contradictory. When producer transaction CBOR, network,
slot, epoch, and protocol parameters are complete, the WASI layer builds a
Conway `LedgerEnv`/`LedgerState` and calls upstream `applyTx`. The operation
does not mutate the transaction and never returns replacement transaction CBOR.

Arguments:

```json
{
  "input_policy": "preserve",
  "context": {
    "producer_txs": {
      "<producer tx id hex>": {
        "tx_cbor": "<producer transaction CBOR hex>",
        "source": "blockfrost.txs.cbor"
      }
    },
    "network": "mainnet",
    "slot": "123456789",
    "epoch": "507",
    "protocol_parameters": {}
  }
}
```

`context.protocol_parameters` must be the complete
`Cardano.Ledger.Core.PParams ConwayEra` JSON shape expected by the Haskell
ledger package. A partial object is invalid context. `context.producer_txs` is
the CBOR-backed source of input and reference-input outputs; provider-specific
UTxO JSON is not accepted as ledger evidence.

The implementation returns `status: "incomplete"` with actionable
`missing_context` when required context is absent, `status: "rejected"` with
`errors` for malformed or contradictory context, or `status: "valid"`/`"invalid"`
from the upstream ledger result when `applyTx` runs. Ledger rejections are
returned in `failures` with the rule category, user-facing message, and raw
predicate text.

Result:

```json
{
  "status": "valid",
  "valid_for_supplied_context": true,
  "complete": true,
  "tx_id": "<transaction id hex>",
  "body_hash": "<transaction body hash hex>",
  "checks": [],
  "failures": [],
  "missing_context": [],
  "resolved_inputs": [],
  "resolved_reference_inputs": [],
  "context": {},
  "errors": [],
  "warnings": []
}
```

The result never includes `tx_cbor` and never mutates the transaction.

### `tx.evaluate.scripts`

Decode the supplied Conway transaction and evaluate phase-2 scripts when the
explicit evaluation context is complete. The operation reports every redeemer
from the witness set with its purpose, index, budgeted execution units,
evaluated execution units when available, failures, and missing context. It
does not mutate the transaction and never returns replacement transaction CBOR.

Arguments:

```json
{
  "input_policy": "preserve",
  "context": {
    "producer_txs": {
      "<producer tx id hex>": {
        "tx_cbor": "<producer transaction CBOR hex>",
        "source": "blockfrost.txs.cbor"
      }
    },
    "network": "mainnet",
    "slot": "123456789",
    "epoch": "507",
    "protocol_parameters": {}
  }
}
```

`context.protocol_parameters` must be the complete
`Cardano.Ledger.Core.PParams ConwayEra` JSON shape expected by the Haskell
ledger package. `context.producer_txs` is the CBOR-backed source of regular and
reference-input outputs. Provider-specific UTxO JSON is not accepted as ledger
evidence.

The implementation returns `status: "not_applicable"` for transactions with no
phase-2 redeemers, `status: "incomplete"` with actionable `missing_context`
when required context is absent, `status: "rejected"` with `errors` for
malformed or contradictory context, or `status: "succeeded"`/`"failed"` from
upstream ledger script evaluation when context is complete.

Result:

```json
{
  "status": "succeeded",
  "scripts_evaluate_for_supplied_context": true,
  "complete": true,
  "tx_id": "<transaction id hex>",
  "body_hash": "<transaction body hash hex>",
  "redeemers": [],
  "total_ex_units": {
    "memory": "0",
    "steps": "0",
    "partial": false
  },
  "failures": [],
  "missing_context": [],
  "resolved_inputs": [],
  "resolved_reference_inputs": [],
  "context": {},
  "errors": [],
  "warnings": []
}
```

The result never includes `tx_cbor` and never mutates the transaction.

## 0.1 Target Operations

These operations define the next API surface. They are intentionally explicit
about context because a transaction alone is not enough for full ledger checks
or balancing.

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
- `../schemas/producer-tx-context.schema.json`
- `../schemas/browser-view.schema.json`
- `../schemas/tx-identify-result.schema.json`
- `../schemas/tx-intent-result.schema.json`
- `../schemas/tx-witness-plan-result.schema.json`
- `../schemas/tx-validate-result.schema.json`
- `../schemas/tx-evaluate-scripts-result.schema.json`

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
| `intent` | `tx.intent` |
| `witness.plan` | `tx.witness.plan` |
