# Implementation Plan: RDF-4 blueprint books

RDF-1 emits deterministic `cardano:` Turtle through `tx.rdf`. RDF-2 queries
that Turtle through `rdf-shapes-wasm`. RDF-3 imports and selectively merges
overlay books. RDF-4 adds blueprint books: selected CIP-57 `plutus.json` assets
are supplied to the WASI RDF emitter, which asks `tx-rdf-core` to decode
matching datums/redeemers into typed RDF fields.

## Architecture

- **WASI args**: extend the local `RdfRequest` parser in
  `libs/cardano-ledger-inspector/app/Main.hs` to accept
  `args.blueprints[]`, where each entry carries an `id` and the raw CIP-57
  JSON text/object for a selected blueprint book part.
- **Blueprint index**: parse each selected CIP-57 JSON using
  `Cardano.Tx.Blueprint.parseBlueprintJSON`; derive `(ScriptHash, Blueprint,
  title)` entries from the blueprint's validators whose JSON contains a
  56-character `hash`; pass that list as the fourth argument to
  `Cardano.Tx.Graph.Emit.emit`.
- **Smoke**: extend `tx-rdf-smoke` to prove no-blueprint output remains
  deterministic and a blueprint request against the SundaeSwap fixture emits a
  typed field predicate/value while a no-blueprint request does not.
- **Books UX**: extend the RDF-3 book parser/model to distinguish overlay
  Turtle parts from blueprint JSON parts. Selected overlays are still merged by
  RDF union; selected blueprints are sent to `tx.rdf` and require a WASI RDF
  re-run against the current transaction CBOR.
- **Typed fields lens**: add a named SPARQL query over the returned Turtle for
  blueprint-decoded fields and render compact rows next to the existing
  resolved-label and transaction-output lenses.
- **Selectivity**: unselected blueprint parts are excluded from `tx.rdf` args.
  Changing selection after a decode must not silently imply typed data is in
  scope; applying/re-decoding with the selected set is the state transition.

## Slice 1 - WASI Blueprint Decode

Driver/navigator implement the WASI arg parser, blueprint index construction,
schema contract update, and Nix smoke.

Focused proof:

```bash
just check-rdf
```

## Slice 2 - Browser Books UX And Typed Lens

Driver/navigator implement blueprint book import/select/apply, typed-field
rendering, and Playwright coverage over the bundled SundaeSwap V3 blueprint.

Focused proof:

```bash
nix develop --quiet -c just ui-check
nix develop --quiet -c just test-playwright
./gate.sh
```

## Finalization

After all tasks are checked and the final local gate passes, update PR
metadata, drop `gate.sh`, mark the PR ready, push, and wait for GitHub Build
Gate CI to report green before writing `COMPLETE`.

