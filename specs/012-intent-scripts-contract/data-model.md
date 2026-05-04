# Data Model: Formalize tx.intent Scripts Detail

## Intent Script Row

- **Location**: `result.intent.scripts[]`
- **Fields**:
  - `purpose`: one of `spending`, `minting`, `certifying`, `rewarding`,
    `voting`, `proposing`
  - `index`: body-local redeemer index
  - `redeemer_cbor_hex`: full redeemer CBOR as lowercase hex
  - `ex_units_committed.memory`: committed memory budget as decimal string
  - `ex_units_committed.steps`: committed step budget as decimal string
  - `input` (optional): canonical input reference for spending redeemers

## Input Reference

- **Location**: `scripts[].input`
- **Fields**:
  - `tx_id`: input transaction id
  - `index`: output index within that transaction

## Constraints

- `scripts[]` may be empty.
- `input` is optional and purpose-specific.
- The schema should preserve the emitted lowercase purpose strings exactly.
