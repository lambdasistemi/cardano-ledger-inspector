# Research: Transaction Validation Operation

## Decision: Extend the Existing Ledger Operation Envelope

`tx.validate` will use the current `cardano-ledger-functional/v1` request and
response envelope:

```json
{
  "ledger_functional_layer": "cardano-ledger-functional/v1",
  "tx_cbor": "<hex>",
  "op": "tx.validate",
  "args": {}
}
```

**Rationale**: The repository already exposes `tx.inspect`, `tx.browse`,
`tx.identify`, and `tx.witness.plan` through the same envelope. Validation is
another pure ledger operation over the current transaction bytes and explicit
arguments, not a stateful RPC service.

**Alternatives considered**:

- Separate RPC/service endpoint: rejected because it conflicts with the
  constitution's transaction-document and explicit-context principles.
- Browser-only validation helper: rejected because ledger semantics must remain
  in the WASI/Haskell layer.

## Decision: Use a Status Enum Instead of a Boolean-Only Result

The validation result will expose `status` with these values:

- `valid`: all required checks passed for the supplied context.
- `invalid`: enough context was supplied and at least one ledger check failed.
- `incomplete`: validation could not finish because context is missing.
- `rejected`: the request context is malformed or contradictory.

`valid` also includes `valid_for_supplied_context: true`; `invalid` includes
`valid_for_supplied_context: false`; `incomplete` and `rejected` use `null`.

**Rationale**: A boolean alone would collapse invalid transactions, incomplete
context, and malformed context into the same shape. The user needs to know
whether to edit the transaction, fetch more context, or fix the request.

**Alternatives considered**:

- `valid: false` for every non-valid case: rejected because it hides missing
  context and would make provider problems look like ledger failures.
- Throwing process errors for missing context: rejected because missing context
  is a normal validation outcome, not a malformed request.

## Decision: Reuse Producer Transaction CBOR for Input Resolution

The operation will read `args.context.producer_txs` in the same transaction-id
map shape used by `tx.witness.plan`. Haskell decodes producer transactions and
selects `outputs[index]` for each referenced input.

**Rationale**: Producer transaction CBOR is stable and cacheable by transaction
id. It avoids making provider-specific UTxO JSON an authoritative ledger input
and keeps input resolution inside the ledger layer.

**Alternatives considered**:

- Provider UTxO JSON as the primary input source: rejected because it makes the
  provider adapter a ledger interpreter.
- Hidden in-process cache of decoded producer transactions: rejected because it
  would make results depend on prior calls.

## Decision: Keep Live Chain State Explicit and Optional

Validation will distinguish immutable transaction evidence from mutable chain
state. Producer transaction CBOR can prove the source output existed. It does
not prove the output is still unspent, nor does it supply current protocol,
slot, epoch, stake, certificate, or governance state.

**Rationale**: A valid result is only meaningful for the context supplied in the
request. Live unspent checks and submission-readiness are separate from
transaction-byte validation unless the caller supplies that context explicitly.

**Alternatives considered**:

- Fetching live state inside `tx.validate`: rejected because provider access
  would make the operation non-deterministic and environment-dependent.
- Treating producer transaction CBOR as submission readiness: rejected because
  historical transaction bytes cannot prove current UTxO membership.

## Decision: Successful JSON Carries Validation Outcomes; Stderr Carries Request Decoding Failures

Malformed hex, malformed CBOR, malformed operation envelopes, and unknown
operation names remain command-level errors. Missing validation context,
ledger-rule failures, and contradictory supplied context are returned in the
successful response envelope under `result.validation`.

**Rationale**: Existing WASI behavior already uses stderr plus non-zero exit for
request decoding failures. Once a `tx.validate` request is decoded, the caller
benefits from structured diagnostics even when validation cannot pass.

**Alternatives considered**:

- Return partial JSON on malformed CBOR: deferred because it changes the
  existing command error model for all operations.
- Encode ledger failures as process failures: rejected because invalid
  transactions are expected user data, not infrastructure errors.

## Decision: Contract-First Vertical Slice

The implementation sequence starts with contract/schema updates and Nix smoke
tests, then exposes the Haskell operation, then updates documentation and UI.

**Rationale**: The constitution requires ledger operation contracts before UI or
provider behavior depends on them. A smoke check that proves the operation can
return `incomplete` without guessing context is valuable even before a complete
mainnet validation fixture exists.

**Alternatives considered**:

- Start with browser UI: rejected because it would make UI shape drive the
  ledger contract.
- Implement full balancing/evaluation together with validation: rejected
  because those are separate operations with different mutation and script
  evaluation semantics.
