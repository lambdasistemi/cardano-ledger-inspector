# Research: Transaction Script Evaluation Operation

## Decision: Extend the Existing Ledger Operation Envelope

`tx.evaluate.scripts` will use the current `cardano-ledger-functional/v1`
request and response envelope:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "tx_cbor": "<hex>",
  "op": "tx.evaluate.scripts",
  "args": {}
}
```

**Rationale**: Script evaluation is a pure ledger operation over the current
transaction bytes and explicit context. It should compose with `tx.inspect`,
`tx.browse`, `tx.identify`, `tx.witness.plan`, and `tx.validate` instead of
introducing a second call boundary.

**Alternatives considered**:

- Separate script-evaluation RPC endpoint: rejected because it conflicts with
  the transaction-document and explicit-context principles.
- Browser/provider-only script evaluation: rejected because script semantics
  must remain in the WASI ledger layer.

## Decision: Use a Status Enum, Not a Boolean-Only Result

The evaluation result will expose `status` with these values:

- `succeeded`: all phase-2 scripts evaluated successfully for the supplied
  context.
- `failed`: enough context was supplied and at least one script failed.
- `incomplete`: script evaluation could not finish because required context is
  missing.
- `rejected`: supplied context is malformed, contradictory, or unusable.
- `not_applicable`: the transaction has no phase-2 scripts to evaluate.

**Rationale**: A boolean alone would collapse script failure, missing context,
bad context, and no-script transactions into the same shape. Users need to know
whether to edit the transaction, fetch more context, fix the request, or move on
to another operation.

**Alternatives considered**:

- `valid: false` for every non-success case: rejected because it makes provider
  or context problems look like script failures.
- Treat no-script transactions as command errors: rejected because users may run
  the operation generically against any transaction.

## Decision: Reuse Explicit Context and Producer Transaction CBOR

The operation will read `args.context.producer_txs` in the same transaction-id
map shape used by `tx.witness.plan` and `tx.validate`. The ledger layer decodes
producer transactions and resolves `tx_id#index` outputs for source-output
evidence.

**Rationale**: Phase-2 script context depends on the outputs consumed or
referenced by the candidate transaction. Producer transaction CBOR is stable,
cacheable by transaction id, and avoids making provider-specific UTxO JSON an
authoritative ledger input.

**Alternatives considered**:

- Provider UTxO JSON as the primary source-output input: rejected because it
  makes provider adapters ledger interpreters.
- Hidden decoded-output cache inside the operation: rejected because results
  would depend on prior calls.

## Decision: Evaluation Does Not Patch Budgets or Fees

`tx.evaluate.scripts` reports evaluated execution units and comparisons with
transaction budgets when available. It does not update redeemer budgets,
recalculate fees, add collateral, or return modified transaction CBOR.

**Rationale**: Evaluation, patching, and balancing have different side effects
and context requirements. Keeping this operation read-only makes the result
deterministic and lets callers decide whether to call `tx.patch` or
`tx.balance` later.

**Alternatives considered**:

- Auto-update redeemer budgets: rejected because that mutates the transaction
  and belongs to a controlled patch/balance workflow.
- Auto-balance after evaluation: rejected because balancing may need extra
  inputs/change/collateral policy and is a separate 0.1 target.

## Decision: Report Partial Association Before Complete Evaluation

The operation should report redeemers that can be associated with transaction
areas even when evaluation cannot fully run. Missing context is reported
separately from script failures.

**Rationale**: The user still benefits from seeing which redeemers exist,
what they are attached to, and which exact facts block evaluation.

**Alternatives considered**:

- Return only a top-level `incomplete`: rejected because it loses useful
  navigation and next-action data.
- Fail fast on the first missing context item: rejected because users need a
  complete shopping list of context to fetch.

## Decision: Successful JSON Carries Evaluation Outcomes; Stderr Carries Request Decoding Failures

Malformed hex, malformed CBOR, malformed operation envelopes, and unknown
operation names remain command-level errors. No-script transactions, missing
evaluation context, script failures, and rejected evaluation context are
successful response envelopes under `result.script_evaluation`.

**Rationale**: Invalid scripts and incomplete context are expected user data,
not infrastructure failures. Existing WASI behavior already uses stderr plus
non-zero exit for request decoding failures.

**Alternatives considered**:

- Encode script failures as process failures: rejected because a script failure
  is the operation's primary diagnostic output.
- Return partial JSON on malformed CBOR: deferred because it changes the common
  command error model for all operations.
