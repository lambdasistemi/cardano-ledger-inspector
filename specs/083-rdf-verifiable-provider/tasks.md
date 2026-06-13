# Tasks: RDF Verifiable Provider Layer

## Slice 1 - WASM RDF Input Resolution

- [X] T083-S1 Parse `args.context.producer_txs` for `tx.rdf` / `tx.graph`.
- [X] T083-S1 Decode each producer transaction CBOR through the Haskell ledger
  path and recompute its transaction id in WASM.
- [X] T083-S1 Reject mismatched producer CBOR and missing producer output
  indexes before adding entries to `TxGraph.ResolvedUTxO`.
- [X] T083-S1 Pass verified resolved inputs to `TxGraph.emit`.
- [X] T083-S1 Extend `tx-rdf-smoke` and public contracts for resolved input
  value-flow and producer txid mismatch diagnostics.
- [X] T083-S1 Run `just check-rdf`, `just build-wasm`, and `./gate.sh`.
- [X] T083-S1 Commit as `feat: verify rdf producer inputs in wasm`.

## Slice 2 - Browser Provider Surface and Error Surfacing

- [ ] T083-S2 Keep the provider adapter surface to transaction-CBOR fetch plus
  network/protocol-parameter fetch.
- [ ] T083-S2 Feed the resolved producer context into `tx.rdf` during browser
  decode.
- [ ] T083-S2 Surface provider resolution errors instead of swallowing them
  into `{}` or invisible context fields.
- [ ] T083-S2 Add Playwright coverage for provider error surfacing and resolved
  input/value-flow RDF output.
- [ ] T083-S2 Run `nix develop --quiet -c just ui-check`,
  `nix develop --quiet -c just test-playwright`, and `./gate.sh`.
- [ ] T083-S2 Commit as `feat: surface rdf provider resolution`.
