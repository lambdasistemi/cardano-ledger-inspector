# Implementation Plan: RDF Transaction Graph

## Architecture

The local WASI executable remains the browser-facing artifact. It delegates all existing operations to `cardano-ledger-wasm` unchanged, and handles only the new RDF operation locally:

1. Parse the existing JSON envelope enough to detect `op`.
2. For `tx.rdf` or `tx.graph`, decode `tx_cbor` with `Cardano.Tx.Decode.decodeConwayTxInput`.
3. Emit a body-only graph with `Cardano.Tx.Graph.Emit.emit tx Map.empty [] []`.
4. Serialize with `serialize Turtle "tx-rdf" graph`.
5. Return the normal ledger-operation response envelope with result fields:
   - `rdf.format = "text/turtle"`
   - `rdf.turtle = <Turtle text>`

The PureScript UI calls the new operation after the existing inspection calls and renders the Turtle in a dedicated graph panel. No browser-side RDF parsing is required for RDF-1.

## Slices

## Slice 1 - WASI RDF Operation

Owned by driver/navigator. Add the pinned `tx-rdf-core` source repository package, executable dependency, local operation handling, deterministic smoke recipe, and contract/schema doc updates.

Focused proof:

```bash
just build-wasm
just check-rdf
```

## Slice 2 - Browser Rendering

Owned by driver/navigator. Add UI state, JSON extraction helper, RDF panel rendering, and Playwright coverage for the fixture graph.

Focused proof:

```bash
just ui-check
just test-playwright
```

## Final Gate

The orchestrator reruns:

```bash
./gate.sh
```

Then updates the draft PR and stops for review.
