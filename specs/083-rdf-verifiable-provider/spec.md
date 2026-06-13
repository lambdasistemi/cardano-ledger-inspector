# Feature Specification: RDF Verifiable Provider Layer

## User Story

As a browser workbench user inspecting a transaction's `cardano:` RDF graph, I
can fetch the consumed inputs through Koios or Blockfrost while the WASM ledger
verifies every producer transaction id before any fetched output is trusted.

## Scope

- Keep provider adapters at exactly two request shapes:
  1. fetch transaction CBOR by tx id for input resolution;
  2. fetch network/protocol parameters for validation context.
- Resolve transaction inputs by fetching producer transaction CBOR, decoding it
  in the WASM ledger, recomputing the producer transaction id from the decoded
  body, checking it equals the requested TxIn tx id, and then taking output
  `ix`.
- Feed the verified `TxIn -> TxOut` map into `tx.rdf` so the emitted graph
  contains resolved input value-flow context.
- Surface provider errors in the browser rather than silently dropping failed
  resolution.

## Out Of Scope

- CSMT-UTxO proofs or proof verification.
- Provider-specific resolved-UTxO JSON endpoints.
- New provider request shapes beyond transaction CBOR and network parameters.
- Hidden state shared between ledger operations.

## Functional Requirements

- FR-001: Browser provider modules MUST expose only transaction-CBOR fetch and
  network-parameter fetch capabilities to the ledger-facing layer.
- FR-002: `tx.rdf` MUST accept producer transaction CBOR in
  `args.context.producer_txs` using the same explicit context convention as
  validation and evaluation.
- FR-003: `tx.rdf` MUST recompute each producer transaction id inside the WASM
  Haskell ledger path and reject mismatched producer CBOR before using any
  output.
- FR-004: `tx.rdf` MUST select the referenced output index only after the
  producer txid check passes.
- FR-005: The RDF graph MUST include resolved input value-flow triples when
  complete producer context is supplied.
- FR-006: Provider resolution errors MUST be visible in browser state/UI and
  must not be swallowed into `{}`.
- FR-007: Network/protocol parameters remain provider-trusted explicit context;
  they are not claimed verifiable in this release.

## Acceptance

- `just check-rdf` proves resolved-input RDF output for a fixture request and
  proves mismatched producer CBOR is rejected by the WASM path.
- Playwright proves browser decode surfaces provider resolution errors and that
  fetched producer transaction CBOR flows into the `cardano:` RDF graph.
- `./gate.sh` passes locally.
- Draft PR #96 Build Gate CI is green before this child emits `COMPLETE`.
