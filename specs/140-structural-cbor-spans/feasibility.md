# Feasibility decision: exact structural CBOR source spans

Date: 2026-07-15

Decision: **FAIL — the bounded spike did not execute, so feasibility remains
unproved and implementation is stopped.**

## What the spike established

The pinned `cardano-ledger-wasm` source at
`5897e8da1c043eb53cdafa6ada9782b56c74b18e` depends on the pinned WASM cborg
fork `amesgen/cborg` at `2dff24d241d9940c5a7f5e817fcf4c1aa4a8d4bf`.
That source exports `Codec.CBOR.Decoding.decodeWithByteSpan` and
`peekByteOffset`; `decodeWithByteSpan` brackets its supplied decoder using
positions observed during byte consumption. This makes a direct original-byte
route source-level plausible.

The driver wrote an out-of-tree, Conway-specific candidate which:

- first calls the existing ledger operation decoder on the exact fixture;
- only after ledger acceptance consumes the same hex-decoded original bytes;
- recognizes the Conway transaction array, body/witness integer-key maps, and
  selected CDDL arrays;
- brackets root, body, witness, field, and indexed occurrences with
  `decodeWithByteSpan`;
- asserts bounds, containment, distinct indexed intervals, and direct slicing;
- does not serialize a ledger value, search the input for values, decode in
  JavaScript, or attempt a general-purpose CBOR model;
- keeps malformed input on the existing `MalformedCbor` path and does not
  invoke the scanner.

The complete candidate, scripts, transcripts, and decision matrix were
reviewed by the navigator under the ticket runtime root. The driver source
SHA-256 is
`e4a1904a645cdc323c1d8407b6b98aae5d962867c585774769c6837259f5ece0`.

## Why this is not a pass

The approved focused command had two permitted attempts, neither of which
reached probe compilation:

1. The repository's exported default dev shell did not contain `cabal`
   (`exit=127`).
2. The single retry entered the flake-owned Haskell.nix GHC 9.8.4
   `project.shellFor`, but its pinned plan failed dependency resolution because
   pkg-config could not find `libblst>=0.3.14` (`exit=1`).

The retry transcript SHA-256 is
`85888be352d004e173fe80a9c0274b37e6ed8d2d7086778f4e6f820813152061`.
No second retry was made.

Because the candidate never ran, it produced no intervals or original slices.
Fixture ledger acceptance inside the combined probe, bounds, containment,
exact-slice equality, distinct repeated paths, and malformed zero-span behavior
are all unproved. The issue and plan define ambiguity as failure; source-level
plausibility cannot authorize the production contract.

## Pass-criteria result

| Criterion | Result |
| --- | --- |
| Existing ledger decoder accepts the fixture in the combined probe | Unproved / fail |
| Offsets observed while consuming original bytes | Unproved / fail |
| Root, body, witness, and two indexed paths have intervals | Unproved / fail |
| Bounds and containment | Unproved / fail |
| Direct original slices equal bytes consumed for each node | Unproved / fail |
| No reserialization, search, JavaScript, or general-CBOR escape hatch | Pass by source review |
| Exact cursor API present in pinned native/WASM sources | Pass by source review |
| Malformed input returns `MalformedCbor` with no spans | Unproved / fail |

## Stop outcome

No schema, OpenAPI, production Haskell, dependency pin, generated artifact, or
browser work follows this record unless the epic owner explicitly approves a
new plan through `Q-001-feasibility-outcome`. The failed gate must not be
relabelled as an architectural proof, and no approximate span map may be
substituted.
