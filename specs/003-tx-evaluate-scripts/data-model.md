# Data Model: Transaction Script Evaluation Operation

## Candidate Transaction

The selected transaction document supplied by the host.

Fields:

- `tx_cbor`: hex-encoded transaction CBOR. Required on every operation call.
- `tx_id`: derived transaction identifier, returned when decoding succeeds.
- `body_hash`: derived transaction body hash, returned when decoding succeeds.
- `era`: initially `Conway` for the implemented WASI inspector.

Rules:

- The ledger layer never treats a previously decoded transaction as
  authoritative.
- Script evaluation never mutates the candidate transaction.

## Evaluation Context

Explicit external facts supplied with the request.

Fields:

- `producer_txs`: map from producer transaction id to producer transaction
  evidence.
- `resolution`: optional host/provider metadata describing how producer
  transaction bytes or context facts were fetched.
- `network`: caller-supplied network label or identifier.
- `slot`: current slot for time-sensitive script context, represented as a
  decimal string in canonical responses.
- `epoch`: current epoch when epoch-sensitive checks need it.
- `protocol_parameters`: caller-supplied protocol parameter object.
- `cost_models`: caller-supplied cost model context when not already contained
  in protocol parameters.
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

## Redeemer Evaluation

The per-redeemer script evaluation result.

Fields:

- `key`: stable result key, for example `spend#0` or `mint#1`.
- `purpose`: script purpose such as `spend`, `mint`, `cert`, `withdrawal`,
  `vote`, or `proposal`.
- `index`: redeemer index within its purpose.
- `status`: `succeeded`, `failed`, `not_evaluated`, or `rejected`.
- `path`: navigation path back to the relevant candidate transaction area.
- `script_hash`: related script hash when available.
- `redeemer_data_hash`: related redeemer data hash when available.
- `datum_hash`: related datum hash when available.
- `budget_ex_units`: memory and steps declared in the transaction when
  available.
- `evaluated_ex_units`: memory and steps consumed by evaluation when available.
- `failure`: related evaluation failure when the redeemer failed.
- `missing_context`: context items blocking this redeemer when not evaluated.
- `warnings`: non-fatal warnings for this redeemer.

Rules:

- A redeemer may be reported before evaluation if it can be associated with the
  transaction.
- Missing context is not a script failure.
- Evaluated units are reported only when the ledger evaluation reaches that
  redeemer successfully enough to measure them.

## Execution Units

The memory and step costs reported by script evaluation.

Fields:

- `memory`: decimal string.
- `steps`: decimal string.

Rules:

- Decimal strings avoid precision loss in JavaScript runtimes.
- Totals are the sum of evaluated redeemers only; incomplete evaluation must
  state when totals are partial.

## Evaluation Failure

A ledger-reported reason a script did not evaluate successfully.

Fields:

- `code`: stable failure identifier when available.
- `severity`: `error` or `warning`.
- `redeemer`: related redeemer key.
- `message`: user-readable explanation.
- `path`: optional navigation path to candidate transaction data.
- `details`: optional structured ledger details.

Rules:

- Failures describe evaluated scripts only.
- Ledger-originated failures should preserve enough structured data for the UI
  to navigate without parsing prose.

## Missing Context Item

A required fact that prevented complete script evaluation.

Fields:

- `kind`: context category, such as `source_output`, `datum`,
  `reference_script`, `cost_model`, `protocol_parameters`, `slot`, `network`,
  `certificate_state`, or `governance_state`.
- `message`: user-readable next action.
- `path`: optional transaction navigation path.
- `tx_id`: referenced transaction id when relevant.
- `index`: referenced output index when relevant.
- `required_for`: redeemer keys or check ids blocked by this item.

Rules:

- Missing context is not a script failure.
- Missing source outputs should identify the exact input or reference input.

## Script Evaluation Result

The complete response payload under `result.script_evaluation`.

Fields:

- `status`: `succeeded`, `failed`, `incomplete`, `rejected`, or
  `not_applicable`.
- `scripts_evaluate_for_supplied_context`: `true`, `false`, or `null`.
- `tx_id`: candidate transaction id when available.
- `body_hash`: candidate transaction body hash when available.
- `complete`: whether all required script evaluations ran for supplied context.
- `redeemers`: redeemer evaluation results.
- `total_ex_units`: total memory and steps for evaluated redeemers.
- `failures`: script evaluation failures.
- `missing_context`: missing context items.
- `resolved_inputs`: source-output resolution for regular inputs.
- `resolved_reference_inputs`: source-output resolution for reference inputs.
- `context`: context summary.
- `warnings`: non-fatal warnings.
- `errors`: request/context errors when status is `rejected`.

State transitions:

- `succeeded`: all phase-2 scripts evaluated successfully and
  `missing_context` is empty.
- `failed`: at least one phase-2 script failed and no missing context prevents
  the failure decision.
- `incomplete`: one or more required context items are missing.
- `rejected`: supplied context is malformed, contradictory, or unusable.
- `not_applicable`: the transaction has no phase-2 scripts to evaluate.
