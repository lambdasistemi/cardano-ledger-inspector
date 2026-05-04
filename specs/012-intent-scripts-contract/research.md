# Research: Formalize tx.intent Scripts Detail

## Decision 1: Treat this as contract drift, not a runtime feature

- **Decision**: Do not change the runtime `tx.intent` producer unless schema
  exercise uncovers a mismatch.
- **Rationale**: `libs/cardano-ledger-inspector/src/Conway/Inspector.hs`
  already emits `scripts[]`, and
  `apps/tx-deep-diagnosis/src/TxDeepDiagnosisHost/Render/Summary.hs` already
  renders it as `## Smart-contract calls`.
- **Alternatives considered**:
  - Re-implement redeemer extraction: rejected because the capability already
    exists and the issue text is stale.

## Decision 2: Use the existing Conway fixture for smoke

- **Decision**: Extend `tx-intent-smoke` using the already-wired
  `tx-validate-complete-request.json` fixture.
- **Rationale**: the fixture already yields a non-empty `scripts[]` array with a
  minting redeemer row, so no new fixture or golden input is required.
- **Alternatives considered**:
  - Reuse the deep-diagnosis golden envelope: rejected because smoke checks
    should stay bound to a direct `tx.intent` operation result.

## Decision 3: Model the spending input as optional

- **Decision**: define `scripts[]` with universal fields
  `purpose/index/redeemer_cbor_hex/ex_units_committed` and an optional `input`
  reference.
- **Rationale**: only spending redeemers currently carry an `input`; minting and
  rewarding rows in committed fixtures do not.
- **Alternatives considered**:
  - Require `input` for every row: rejected because it would misdescribe live
    minting and rewarding entries.
