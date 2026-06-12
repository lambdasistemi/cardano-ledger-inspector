# Design: RDF semantics composability (browser-local book merge)

> Status: **design / proposal**. Tracks the epic
> [#NNN](https://github.com/lambdasistemi/cardano-ledger-inspector/issues).
> This document is the architecture narrative; per-feature specs land under
> `specs/0NN-*` as the work is sliced.

## One sentence

Make the inspector *fundamentally* better than monolithic CBOR decoders
(e.g. CQuisitor) by turning every transaction into a **composable RDF
graph** that the user enriches, **entirely in the browser**, by merging
**local "books"** — RDF asset bundles anyone can publish — and reading,
querying, and validating the result in the publisher's own vocabulary.

## Why this beats a closed decode tree

A conventional inspector (CQuisitor, Cardanoscan, etc.) ships **one
vendor's labels baked in**: the decode tree is whatever that team coded.
Cardano's surface — dApps, treasuries, governance, NFT standards — is
open-ended, so any single baked-in vocabulary is permanently incomplete.

RDF inverts this. The transaction becomes a **generic graph keyed by
canonical IRIs**; *anyone* can publish a bundle that annotates those IRIs
with meaning; bundles **merge by IRI with no central schema** (open-world
assumption). An application developer ships a book "the way they ship a
policy id," and from then on every author and auditor gets the rich UX
**for free, with no bespoke tooling**. That open-world composability is
the differentiator a closed decode tree cannot match.

The user-facing promise: *you hold your books locally; you pick which
parts to merge into the transaction in front of you; nothing is uploaded;
nothing depends on a SaaS API.*

## The pieces already exist

This is an **integration**, not a green-field build. Four repos under
`lambdasistemi` already contain every part; this epic composes them in the
browser.

| Repo | Language → target | Role in the composition |
|---|---|---|
| [`cardano-ledger-rdf`](https://github.com/lambdasistemi/cardano-ledger-rdf) (`cq-rdf`) | Haskell → **wasm32-wasi** | tx → `cardano:` RDF graph; merge the book assets onto it |
| [`rdf-shapes-wasm`](https://github.com/lambdasistemi/rdf-shapes-wasm) | Rust → **wasm32 (wasm-bindgen)** | client-side SPARQL 1.1 (Oxigraph) + SHACL Core (rudof) |
| **`cardano-ledger-inspector`** (this repo) | Haskell→wasm + PureScript/Halogen | the browser home: orchestration + the **Books** UX |
| [`amaru-treasury-tx`](https://github.com/lambdasistemi/amaru-treasury-tx) | Haskell server | the **server-side proof** the model works (do not depend on it) |

### `cardano-ledger-rdf` — the generic engine + the book model

`cq-rdf` (the `tx-graph` app) already defines exactly the model we want.
It emits a **deterministic** RDF graph in the `cardano:` vocabulary with
**stable, content-derived IRIs** — these are the merge backbone:

- `urn:cardano:tx:<txid>`
- `urn:cardano:id:<leafType>:<hex>` — a `cardano:Identifier` leaf for each
  key/script hash (so two graphs that mention the same hash join on it)
- `cardano:bech32` literals for addresses, `cardano:fromTxOutRef` for UTxO
  references

A **"book" is one of `cq-rdf`'s app asset bundles**:

| `cq-rdf` slot | Book content | Already in this repo as JSON |
|---|---|---|
| `overlay` | entities, labels, attestations (operator/app reference data) | `docs/inspector/protocols/amaru-treasury/journal-2026.json` |
| `blueprint` | CIP-57 typed datum/redeemer decode so contract fields are queryable | `docs/inspector/protocols/sundaeswap-v3/plutus.json` (issues [#35](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/35), [#36](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/36)) |
| `metadata` | typed interpretation of tx-metadata labels | — |
| `shapes` | SHACL conformance + hygiene constraints (author gate / auditor classifier) | — |

**The inspector's existing `docs/inspector/protocols/` registry is already
a proto-book system, just in bespoke JSON.** This epic reframes the
registry as RDF books and makes the merge happen client-side.

Merging is RDF union by IRI — the canonical `cq-rdf` pipeline today is:

```bash
cq-rdf overlay --in overlay.yaml > overlay.ttl
cq-rdf body --provider … <txid>  > bodies.ttl
cat overlay.ttl bodies.ttl | cq-rdf blueprint --blueprints b/ > package.ttl
cq-rdf shacl  --shapes s/ < package.ttl     # author gate / classifier
arq --data package.ttl --query lens.rq       # auditor lens
```

### `rdf-shapes-wasm` — the browser query/validate engine

The pipeline above ends in **`cq-rdf shacl`** (which shells out to an
external `shacl` binary via `readProcessWithExitCode`) and **`arq`**
(Apache Jena, JVM). Neither runs in a browser. `rdf-shapes-wasm` is the
drop-in replacement, **already shipped** with a
[live playground](https://lambdasistemi.github.io/rdf-shapes-wasm/app/):

- **Oxigraph** → SPARQL 1.1 query
- **rudof** → SHACL Core validation
- one Rust core, reproducibly built to a `wasm-bindgen` browser bundle
  (also FFI lib + CLI). Browser API:

  ```js
  query(graph_ttl: string, sparql: string)  -> rows
  validate(data_ttl: string, shapes_ttl: string) -> report
  ```

  The bundle is **vendored and the `.wasm` is inlined** (esbuild
  `--loader:.wasm=binary`), so there is **no runtime fetch** — evaluation
  is fully client-side, matching this repo's trust stance (crypto/logic
  runs as compiled wasm, never a JS reimplementation).

## The gap = browser-local composition

Everything above except the browser wiring exists. The work is to make the
**emit + merge + query + validate** pipeline run in the page, driven by a
**Books** UX, with **no Blockfrost** in the trust path.

```mermaid
flowchart TD
  tx[tx CBOR + resolved context] --> emit
  subgraph WASI [Haskell → wasm32-wasi]
    emit[cq-rdf body / overlay / blueprint<br/>pure Turtle emit + merge]
  end
  books[(local Books<br/>overlay / blueprint / shapes / lenses)] -->|user selects parts| emit
  emit --> pkg[package.ttl<br/>cardano: graph, IRI-keyed]
  pkg --> engine
  subgraph BINDGEN [Rust → wasm-bindgen]
    engine[rdf-shapes-wasm<br/>query() SPARQL · validate() SHACL]
  end
  engine --> ui[Halogen UI<br/>resolved labels · lens rows · conformance]
```

### Four work areas

1. **wasm-compile `cq-rdf` emit.** `body | overlay | blueprint` are pure
   Turtle in/out — they compile cleanly under this repo's `nix/wasm/`,
   exactly as `wasm-tx-inspector.wasm` already does. Invoke them through
   the **same WASI stdin/stdout contract** the inspector uses today
   (`runInspector(stdin) -> { stdout, stderr, exitOk }`, wrapped in
   PureScript `Aff`). The `cq-rdf shacl` subcommand is **not** ported — it
   is replaced by area 3.

2. **Books UX (PureScript/Halogen).** A book is a local RDF asset bundle.
   The page must: store books locally (IndexedDB / file import — amaru's
   `BooksPage` import/export is the seed), let the user **select which
   parts of which books to merge** (per the explicit requirement), union
   the selection into the in-wasm graph, and render the result. *Merge,
   not upload* — selection happens against local data.

3. **Integrate `rdf-shapes-wasm`.** Vendor its wasm-bindgen bundle
   (the existing `wasm-pkg` Nix derivation) beside the WASI artifact. Two
   wasm modules coexist in one page: WASI (`browser_wasi_shim`) for the
   Haskell emit, `wasm-bindgen` (`initSync`) for the Rust engine. Wire
   `query()`/`validate()` into the Halogen layer as the **lens runner**
   and the **conformance gate**.

4. **Context without Blockfrost.** A tx body needs its consumed inputs
   resolved for full context (value flow, datums). `amaru-treasury-tx`
   gets this from a local chain-sync indexer, *not* Blockfrost. The
   browser cannot run an indexer, so resolved context becomes **local
   input**: pasted alongside the tx, carried in a **context book**, or
   pulled from a user-pointed local provider. No SaaS in the trust path
   (cf. issue [#45](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/45)).

## Spec-level invariants (acceptance)

These are the properties the design must preserve; each becomes a checked
acceptance criterion in the child specs.

- **I1 — Determinism.** Same tx + same selected book parts ⇒ byte-identical
  `package.ttl`. (Inherited from `cq-rdf`'s deterministic emit.)
- **I2 — Merge is IRI-union.** A book contributes meaning *only* by sharing
  canonical IRIs (`urn:cardano:id:…`, `urn:cardano:tx:…`, `cardano:bech32`,
  `cardano:fromTxOutRef`) with the body graph. No bespoke join logic.
- **I3 — Open-world composability.** Two independently authored books merge
  without coordination; neither needs to know the other exists.
- **I4 — No network in the trust path.** Emit, merge, query, and validate
  execute in wasm in the page. The only permitted network is *fetching the
  tx/context the user asked for*, and that must be a user-chosen source,
  never a hardwired SaaS.
- **I5 — Selectivity.** The user chooses which books and which parts merge;
  an unselected book has zero effect on the graph or the rendered result.
- **I6 — Engine fidelity.** Query is full SPARQL 1.1 (Oxigraph) and
  validation is SHACL Core (rudof) — the same engines the native CLI and
  W3C-conformance gate use, so browser results match CLI results.

## Staged plan (child tickets)

Bisect-safe, each a `resolve-ticket` PR. Ordering reflects dependencies.

1. **RDF-1 — wasm-compile `cq-rdf body`** and render the raw `cardano:`
   graph in the UI (no books yet). Proves the emit path end-to-end.
2. **RDF-2 — vendor `rdf-shapes-wasm`**; add a SPARQL "lens" panel running
   a fixed named query over the RDF-1 graph. Proves the Rust engine in
   the page.
3. **RDF-3 — overlay books**: import an overlay book, select parts, merge,
   show **resolved labels**. Reframes `journal-2026.json` as an overlay
   book. Subsumes part of [#66](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/66).
4. **RDF-4 — blueprint books**: CIP-57 typed datum/redeemer decode via
   `cq-rdf blueprint`. Converges with [#35](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/35)/[#36](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/36).
5. **RDF-5 — SHACL shapes books**: `validate()` as the author gate /
   auditor classifier; render conformance.
6. **RDF-6 — context without Blockfrost**: context book / local provider;
   close the SaaS dependency ([#45](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/45)).

## Open questions

- **Book distribution & trust.** How are books named, versioned, pinned,
  and trust-rooted? (The existing `pin.json` carries upstream `ref` +
  `refresh_command` — extend that, or a new manifest?) A malicious book
  can only *mislabel* (it cannot change ledger validation, which stays in
  the Haskell wasm), but mislabeling is itself an attack surface.
- **Arbitrary SPARQL vs named lenses.** `rdf-shapes-wasm` supports
  arbitrary SPARQL; `amaru-treasury-tx` deliberately exposes only *fixed
  named* lenses. Start with named lenses (curated, shareable) and gate a
  raw-query affordance behind an "advanced" mode?
- **Where do shapes/lenses live** — inside a book, or a separate "lens
  book" the user merges independently of the data overlay?
- **Engine packaging.** Two wasm modules (WASI + wasm-bindgen) in one
  bundle: confirm size budget and that `nix/wasm` can vendor the
  `rdf-shapes-wasm` derivation as a flake input cleanly.
