# Implementation Plan: RDF Verifiable Provider Layer

## Architecture

The browser remains a byte-fetching host. It discovers TxIns from
`tx.inspect`, fetches producer transaction CBOR by tx id from the selected
provider, fetches the current network/protocol parameters, and passes all data
as explicit `args.context` to each ledger operation.

The checkable trust boundary lives in the WASM Haskell code:

1. `tx.rdf` parses `args.context.producer_txs`.
2. Each producer transaction CBOR is decoded through the same Haskell ledger
   path used by existing operations.
3. The decoded producer transaction id is recomputed in WASM from the decoded
   body using ledger APIs.
4. A producer tx is eligible only when the recomputed id equals the TxIn tx id.
5. The referenced output index is selected from the verified producer
   transaction and inserted into `TxGraph.ResolvedUTxO`.
6. `TxGraph.emit tx resolvedUtxo [] blueprints` emits resolved input/value-flow
   graph content.

Provider errors are part of the browser contract. Failed tx-CBOR fetches,
parameter fetches, malformed provider JSON, and incomplete producer context
must be visible to the user and must not degrade to an empty context without a
diagnostic.

## Slice 1 - WASM RDF Input Resolution

Owned by driver/navigator.

Implement producer-context parsing for `tx.rdf`, verify producer transaction
ids in WASM, pass the verified `ResolvedUTxO` to `TxGraph.emit`, and extend RDF
smokes/contracts for both success and mismatch failure.

Focused proof:

```bash
just check-rdf
just build-wasm
```

## Slice 2 - Browser Provider Surface and Error Surfacing

Owned by driver/navigator.

Keep the browser provider layer to the two allowed request shapes, call
`tx.rdf` with the resolved producer context, and surface resolution errors in
the UI/Playwright path.

Focused proof:

```bash
nix develop --quiet -c just ui-check
nix develop --quiet -c just test-playwright
```

## Final Gate

The ticket-orchestrator reruns:

```bash
./gate.sh
```

Then it pushes, audits PR #96, waits for Build Gate CI to turn green, drops
`gate.sh`, marks the PR ready if appropriate, and only then reports `COMPLETE`.
