# Quickstart: Formalize tx.intent Scripts Detail

## Goal

Verify that the public `tx.intent` contract documents the structured redeemer
detail that the runtime already emits.

## Steps

1. Build and run `tx-intent-smoke`.
2. Confirm the schema defines `scripts[]`.
3. Confirm the ledger-functional API docs include a concrete `scripts[]`
   example.
4. Confirm the smoke fixture still exposes a minting redeemer row with
   committed ex-units and redeemer CBOR.

## Expected Result

- The smoke check proves `scripts[]` remains present and structured.
- The schema/docs make that surface official for downstream consumers.
