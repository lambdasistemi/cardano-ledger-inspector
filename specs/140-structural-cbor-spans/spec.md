# Issue 140: Exact Structural CBOR Source Spans

## P1 user story

As a transaction-analysis client, I inspect a decoded structural path and
observe exact byte coordinates into the original transaction CBOR.

## Architectural invariants

- Every span is a real half-open `[start, end)` byte interval into the original
  supplied CBOR.
- Spans are never derived from reserialization and never computed by browser
  JavaScript.
- Paths are stable, CDDL-aligned, and distinguish repeated array and map
  occurrences.
- Child spans are contained by their structural parent where applicable.
- Existing operation consumers can ignore the additive span data.
- Malformed CBOR returns the existing decode error and never a partial or
  guessed span map.

## Deliverables

- A documented ledger-operation and schema contract for structural source
  spans.
- A Haskell/WASM implementation and fixture/corpus checks.
- Generated OpenAPI, schema, and public API documentation updates.
- A feasibility decision record if the upstream ledger decoder cannot retain
  exact original offsets.

## Acceptance criteria

- [ ] A time-boxed feasibility test proves exact original-byte offsets can be
  obtained in Haskell; if it cannot, work stops with evidence before choosing
  another architecture.
- [ ] The contract defines stable paths and half-open byte offsets with bounds
  and containment semantics.
- [ ] Representative body, witness, input, output, redeemer, datum, and
  metadata nodes carry exact spans when present.
- [ ] Property/fixture tests prove `0 <= start < end <= input_length` and
  applicable child containment.
- [ ] Tests prove each reported slice equals the corresponding bytes in the
  original input, including nested and repeated values.
- [ ] Malformed CBOR returns the existing decode error and no partial/guessed
  span map.
- [ ] Browser JavaScript contains no CBOR parser or offset reconstruction.
- [ ] Schemas, OpenAPI, public API documentation, WASI smoke checks, and
  `nix develop --quiet -c just ci` pass.

## Non-goals

- Rendering or highlighting bytes in the browser.
- Changing decoded ledger values.
- Supporting non-Cardano general CBOR.
- A JavaScript decoder fallback.

## Feasibility stop condition

No production contract or implementation work is authorized until a bounded
spike demonstrates that offsets are measured while consuming the original
decoded transaction bytes. A reserialization-derived match, a browser-side
parser, or an offset inferred by searching for equal byte strings is a failed
spike. If exact offsets cannot practically survive the Haskell decode path to
stable structural nodes, the ticket stops with a written decision record and
evidence; it does not substitute approximate spans.
