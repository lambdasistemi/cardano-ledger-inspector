# Data Model: Transaction Validation Operation

## Candidate Transaction

The selected transaction document supplied by the host.

Fields:

- `tx_cbor`: hex-encoded transaction CBOR. Required on every operation call.
- `tx_id`: derived transaction identifier, returned in validation results when
  decoding succeeds.
- `body_hash`: derived transaction body hash, returned in validation results
  when decoding succeeds.
- `era`: initially `Conway` for the implemented WASI inspector.

Rules:

- The ledger layer never treats a previously decoded transaction as
  authoritative.
- Validation never mutates the candidate transaction.

## Validation Context

Explicit external facts supplied with the request.

Fields:

- `producer_txs`: map from producer transaction id to producer transaction
  evidence.
- `resolution`: optional host/provider metadata describing how producer
  transaction bytes were fetched.
- `network`: caller-supplied network label or identifier.
- `slot`: current slot for time-sensitive validation, represented as a decimal
  string in canonical responses.
- `epoch`: current epoch when epoch-sensitive checks need it.
- `protocol_parameters`: caller-supplied protocol parameter object.
- `governance_state`: caller-supplied governance context when relevant.
- `cert_state`: caller-supplied certificate/stake credential context when
  relevant.
- `stake_distribution`: caller-supplied stake distribution context when
  relevant.

Rules:

- Every field is explicit caller input.
- Missing fields produce `missing_context` items instead of defaults guessed by
  the ledger layer.
- Provider metadata is diagnostic only and is not ledger evidence by itself.

## Producer Transaction Evidence

Canonical bytes for a historical transaction that created one or more outputs
referenced by the candidate transaction.

Fields:

- `tx_cbor`: hex-encoded producer transaction CBOR.
- `source`: optional label such as `blockfrost.txs.cbor`,
  `koios.transaction_cbor`, or `fixture`.

Rules:

- The map key must match the decoded producer transaction id.
- A referenced output resolves only when the candidate input's index exists in
  the decoded producer transaction outputs.
- Mismatched transaction ids or missing output indexes are invalid context.

## Resolved Source Output

An output referenced by a candidate transaction input or reference input.

Fields:

- `key`: `<tx_id>#<index>`.
- `tx_id`: referenced transaction id.
- `index`: referenced output index.
- `kind`: `input` or `reference_input`.
- `resolved`: boolean.
- `source`: evidence source when available.
- `path`: navigation path back to the candidate transaction field.
- `tx_out`: rendered output when resolved.
- `reason`: missing or rejection reason when unresolved.

Rules:

- Regular inputs and reference inputs are reported separately.
- Resolved outputs from producer transaction CBOR are stable historical
  evidence, not live unspent-status evidence.

## Validation Check Group

A user-visible group of checks attempted by `tx.validate`.

Fields:

- `id`: stable machine-readable identifier.
- `title`: user-readable group title.
- `status`: `passed`, `failed`, `not_evaluated`, or `warning`.
- `scope`: transaction area covered by the group.
- `required_context`: context categories required by the group.
- `path`: optional transaction navigation path.
- `message`: optional user-readable summary.

Rules:

- Checks that cannot run because context is absent use `not_evaluated`.
- A failed check creates at least one validation failure.

## Validation Failure

A specific reason the candidate transaction is invalid for supplied context.

Fields:

- `code`: stable failure identifier.
- `severity`: `error` or `warning`.
- `check`: related validation check id.
- `message`: user-readable explanation.
- `path`: optional navigation path to candidate transaction data.
- `related_inputs`: optional array of input keys.
- `details`: optional structured ledger details.

Rules:

- Failures describe evaluated checks only.
- Ledger-originated failures should preserve enough structured data for the UI
  to navigate without parsing prose.

## Missing Context Item

A required fact that prevented complete validation.

Fields:

- `kind`: context category, such as `source_output`,
  `protocol_parameters`, `slot`, `network`, `script_execution_context`,
  `certificate_state`, or `governance_state`.
- `message`: user-readable next action.
- `path`: optional transaction navigation path.
- `tx_id`: referenced transaction id when relevant.
- `index`: referenced output index when relevant.
- `required_for`: validation check ids blocked by this item.

Rules:

- Missing context is not a validation failure.
- Missing source outputs should identify the exact input or reference input.

## Validation Result

The complete response payload under `result.validation`.

Fields:

- `status`: `valid`, `invalid`, `incomplete`, or `rejected`.
- `valid_for_supplied_context`: `true`, `false`, or `null`.
- `tx_id`: candidate transaction id when available.
- `body_hash`: candidate transaction body hash when available.
- `complete`: whether all required checks ran for supplied context.
- `checks`: validation check groups.
- `failures`: validation failures from evaluated checks.
- `missing_context`: missing context items.
- `resolved_inputs`: source-output resolution for regular inputs.
- `resolved_reference_inputs`: source-output resolution for reference inputs.
- `context`: context summary.
- `warnings`: non-fatal warnings.
- `errors`: request/context errors when status is `rejected`.

State transitions:

- `valid`: all required check groups passed and `missing_context` is empty.
- `invalid`: at least one required check group failed and no missing context
  prevents the invalidity decision.
- `incomplete`: one or more required context items are missing.
- `rejected`: supplied context is malformed, contradictory, or unusable.
