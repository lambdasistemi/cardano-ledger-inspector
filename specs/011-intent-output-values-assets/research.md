# Research: Formalize tx.intent Output Rows and Asset Detail

## Findings

1. The live `tx.intent` implementation already emits `value.outputs[]` through
   `intentOutputJson`, and each row already includes `index`, `bucket`,
   `address_hex`, `coin_lovelace`, `assets`, and `datum`.
2. The committed schema for `tx.intent` does not describe `value.outputs[]`, so
   contract consumers only see it today through `additionalProperties`.
3. The current markdown Outputs table already reads `value.outputs[]`, but it
   only shows output index, bucket, destination, ADA, and datum preview. Asset
   detail is hidden.
4. The existing `conway-mainnet-tx.hex` fixture already produces non-empty
   `value.outputs[].assets` rows under `tx.intent`, so no new chain fixture is
   required to verify asset-bearing outputs.

## Decision

Use the existing `value.outputs[]` payload as the source of truth:

- formalize it in the schema/docs/OpenAPI
- strengthen the `tx-intent-smoke` assertions around it
- surface its `assets` field in the human-readable Outputs table

No library-level wire-format expansion is needed for this slice.
