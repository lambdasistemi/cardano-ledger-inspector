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
| `tx.review` | implemented | Project the shared enriched `tx.intent` result into a versioned signer-facing review: output control groups, value sources, high-value movements, fee, conditional collateral, net-signer-value status, and isolated self-declared metadata claims. Alias `review`. |
| `tx.witness.plan` | implemented | Explain body-declared signer hashes, present witnesses, scripts, redeemers, datums, and reference inputs that are visible from the transaction alone. |
| `tx.witness.attach` | implemented | Attach or replace one vkey witness in transaction CBOR, preserve all other witness-set content, and return patched transaction bytes plus stable diagnostics. |
| `tx.validate` | implemented | Report whether explicit validation context is usable or incomplete; run Conway `applyTx` when modeled context is complete. |
| `tx.evaluate.scripts` | implemented | Evaluate phase-2 scripts and report per-redeemer execution units or failures with explicit context. |
| `tx.rdf` | implemented | Decode transaction CBOR and return deterministic Turtle for the transaction graph. |
| `tx.graph` | implemented | Alias of `tx.rdf`; returns the same deterministic Turtle result while preserving the requested operation name. |
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
    "auxiliary_data": {
      "metadata": [
        {
          "label": "1694",
          "value": {
            "type": "map",
            "entries": [
              {
                "key": { "type": "text", "value": "label" },
                "value": { "type": "text", "value": "Swap ADA<->USDM" }
              }
            ]
          }
        }
      ]
    },
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
    "scripts": [
      {
        "purpose": "minting",
        "index": 0,
        "redeemer_cbor_hex": "d8799f9f584008de75f552e48fac7e6c33231729e2bfeae5349683e70b73389ab1c3e45fe1580753d43cb6d411722a12a648358532c2179c9c4a48b04e6ccc975521687367015840c765b4606449269e6dde0d490cc1328fa1b71d426bc5a4a333d47491ed81b4800c73692bfc1f946665e2a7588be87f73d1f381e482f0b04659c2159d938cb00358405142c2b29786e5cf0c415258acf38417b8ec76e9f057bb7d46533eeea1465c07e07a0f78e08e7f741451095be602eafd4e2a40c85b2214618e2bc195c5fe3f09584001628d4fc6146db2de64c3572dfdb8eda0a85c472f180acd680f5a224746e0e402393d524affb475e821c022e8885a66ed99b2c46ccbde9c397772f81a678803ffff",
        "ex_units_committed": {
          "memory": "376813",
          "steps": "369524043"
        }
      }
    ],
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
      ],
      "outputs": [
        {
          "index": 0,
          "bucket": "script",
          "address_hex": "71193ee65211bb3b4e0ea5f751f415269355a650e2e3706f625cdf1a4b",
          "coin_lovelace": "1400750",
          "assets": {
            "193ee65211bb3b4e0ea5f751f415269355a650e2e3706f625cdf1a4b": {
              "": "1"
            }
          },
          "datum": {
            "kind": "inline_datum",
            "cbor_hex": "d8799fd8799f4e4345522f4144412d555344412f331b0000019dc5b5da20d8799f1a94ab3f2d1b00000002540be400ffffd8799f581c3c12f6735ef87655c5b27bced3f828d857d0a27fd20f2cda18ebf2fbffff",
            "decoded": { "kind": "constr" }
          }
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
additional structured fields (`auxiliary_data.metadata`, `metadata_claims`, `signing`, `scripts`,
`value`, `features`, `withdrawals`, `effects`, and `context`) remain available
for API consumers. Each `scripts[]` row exposes the redeemer purpose, its
body-local index, the redeemer CBOR, and the committed ex-units budget; for
`spending` rows the contract may also include the targeted canonical `input`
reference. Each `withdrawals[]` row exposes the serialized reward-account hex,
its network and staking credential, and the withdrawn lovelace amount. Each
`signing.required_signers[]` row exposes the declared signer hash, its source,
and whether that signer is already covered by a vkey witness, a bootstrap
witness, or still missing. Each `value.outputs[]` row exposes the exact output
address, its lovelace amount, its native-asset map (`policy_id -> asset_name ->
quantity`), and its datum state (`no_datum`, `datum_hash`, or `inline_datum`).
When a payment script hash is registered and its inline datum conforms to the
registered schema, the row additionally contains `decoded_datum`. Successful
script rows may similarly contain `decoded_redeemer` after their ledger purpose
is resolved through explicit producer context. An annotation carries protocol
identity, parameterization, stable `schema_ref`, constructor and named fields;
nested data uses lossless tagged constructor/map/list/integer/bytes nodes.
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

`auxiliary_data.metadata` is always an array of label/value rows. Labels and
integer values are decimal strings. Each value preserves its ledger constructor
as `int`, `bytes` (lowercase hex), `text`, `list`, or `map`; maps use ordered
`entries` with recursive `key` and `value` nodes so non-text and duplicate keys
are not collapsed into a JSON object.

### `tx.review`

Project the shared, locally enriched `tx.intent` result plus the same decoded
Conway transaction into one versioned signer-facing review. The operation is
recognized only in the target-independent wrapper: it routes the request
through the kernel's `tx.intent` path, applies the same local typed-metadata
and protocol-registry enrichments, then projects the enriched intent into
`result.review` and restores `op` to `tx.review`. WASI, native, and Extism
therefore return byte-identical review bytes. The legacy short name `review`
is accepted. Existing operations, including `tx.intent`, keep their current
response bytes.

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "op": "tx.review",
  "result": {
    "review": {
      "version": "cardano-tx-review/v1",
      "tx_id": "<hex>",
      "body_hash": "<hex>",
      "context": {
        "input_status": "incomplete",
        "regular_input_count": 2,
        "resolved_regular_input_count": 1,
        "missing_regular_input_count": 1
      },
      "sources": [
        { "kind": "regular_input", "count": 2, "resolved_count": 1, "missing_count": 1, "resolved_lovelace": "1041836734694" },
        { "kind": "withdrawal", "count": 1, "lovelace": "0" },
        { "kind": "collateral", "conditional": true, "input_count": 1, "body_total_lovelace": "1565693", "return_lovelace": "50005673583" },
        { "kind": "reference_input", "read_only": true, "count": 4 }
      ],
      "control_groups": [
        {
          "category": "script",
          "addresses": ["<address hex>"],
          "output_indices": [0],
          "output_count": 1,
          "lovelace": "1041836734694",
          "asset_class_count": 0,
          "role": "Amaru Network Compliance treasury",
          "role_provenance": "context_proven",
          "evidence": ["ledger_proven", "context_proven", "registry_decoded"]
        }
      ],
      "high_value_movements": [],
      "fee": { "lovelace": "1043795" },
      "collateral": { "conditional": true, "input_count": 1, "body_total_lovelace": "1565693", "return_lovelace": "50005673583" },
      "net_signer_value": {
        "provable": false,
        "lovelace": null,
        "note": "missing input context, net signer gain/loss unprovable"
      },
      "claims": [
        { "label": "Swap ADA<->USDM", "value": "...", "detail": "...", "provenance": "metadata_claim", "self_declared": true }
      ],
      "warnings": []
    }
  }
}
```

Output control categories are exactly `signer_controlled`, `external_key`,
`script`, `bootstrap`, and `unknown`; the existing `tx.intent` signer matching
is the authority for the first four and anything unrecognized maps to
`unknown`. Control groups are deterministic, grouped by control category,
address, and authoritative role. Role authority descends from a
context-proven same-address continuation, to a registry-decoded protocol
label, to a heuristic signer return/change candidate, to a generic
ledger-proven role; metadata never selects a role. Evidence provenance uses
the explicit tags `ledger_proven`, `context_proven`, `registry_decoded`,
`metadata_claim`, and `heuristic`.

Sources keep regular inputs, withdrawals, conditional collateral, and
read-only reference inputs separate. High-value movements list every control
group holding at least one percent of total output lovelace, with the largest
non-empty group always included, in descending lovelace order. Every ledger
amount is a decimal string. The net-signer-value object is unprovable, with
the literal note `missing input context, net signer gain/loss unprovable`,
unless every regular input resolves from explicit producer transaction CBOR.
Metadata claims are copied into a separate collection tagged `metadata_claim`
and marked self-declared; they never change a control category, role, amount,
or high-value decision.

Arguments:

`context.producer_txs`
: Optional producer transaction CBOR map keyed by transaction id, exactly as
for `tx.intent`. Resolving every regular input makes the net signer value
provable.

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

### `tx.witness.attach`

Decode the supplied Conway transaction, decode one hex-encoded vkey witness,
and attach it to the witness set. The operation only inserts or replaces a
vkey witness with the same verification key hash; it preserves all non-target
witness-set content. It does not sign, hold secret keys, or prove that the
witness matches the transaction body.

Arguments:

```json
{
  "vkey_witness_cbor_hex": "<hex-encoded CBOR for one Shelley/Conway vkey witness>"
}
```

Successful result payload:

```json
{
  "status": "applied",
  "tx_id": "<transaction id hex>",
  "body_hash": "<transaction body hash hex>",
  "tx_cbor": "<patched transaction CBOR hex>",
  "signed_tx_cbor_hex": "<patched transaction CBOR hex>",
  "witness_patch_action": "inserted",
  "errors": [],
  "warnings": []
}
```

Rejected result payload:

```json
{
  "status": "rejected",
  "tx_id": "<transaction id hex>",
  "body_hash": "<transaction body hash hex>",
  "errors": [
    {
      "code": "missing_vkey_witness_cbor_hex",
      "message": "Supply args.vkey_witness_cbor_hex as hex-encoded CBOR for a single vkey witness.",
      "path": ["args", "vkey_witness_cbor_hex"],
      "details": null
    }
  ],
  "warnings": []
}
```

When the attachment succeeds, the response also includes the same patched bytes
at `result.tx_cbor` to satisfy the shared mutation contract. Within
`witness_attachment`, `witness_patch_action` is `inserted` when the
verification key was absent and `replaced` when an existing vkey witness for
the same key hash was updated.

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

### `tx.rdf` / `tx.graph`

Decode the supplied Conway transaction and return a deterministic RDF graph
serialized as Turtle. `tx.graph` is an alias accepted by the WASI boundary; the
response `op` matches the requested operation. When producer transaction CBOR is
supplied in `args.context.producer_txs`, the WASM ledger code decodes each
producer transaction, recomputes its transaction id, checks it against the
referenced input tx id, and only then uses the referenced output index to add
resolved input/value-flow triples.

Arguments:

```json
{
  "context": {
    "producer_txs": {
      "<producer_tx_id>": {
        "tx_cbor": "<hex-encoded producer transaction>",
        "source": "blockfrost.txs.cbor"
      }
    }
  },
  "blueprints": []
}
```

`context.producer_txs` follows the same explicit producer-transaction context
shape used by validation and script evaluation. The map value may also be the
producer transaction CBOR string directly. Provider adapters remain byte
fetchers: they may fetch transaction CBOR by tx id, but MUST NOT pass
provider-specific UTxO JSON as the ledger-facing RDF input.

Malformed producer CBOR, producer transaction id mismatches, and missing
producer output indexes are reported as `malformed_ledger_operation`
diagnostics.

Result:

```json
{
  "rdf": {
    "format": "text/turtle",
    "turtle": "@prefix cardano: <https://w3id.org/cardano/> .\n..."
  }
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
- `../schemas/tx-witness-attach-result.schema.json`
- `../schemas/tx-validate-result.schema.json`
- `../schemas/tx-evaluate-scripts-result.schema.json`
- `../schemas/tx-rdf-result.schema.json`

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
| `witness.attach` | `tx.witness.attach` |
