# Plan: Exact Structural CBOR Source Spans

## Current decoder boundary

The local WASI executable delegates all eight JSON operations to
`Conway.Inspector.runLedgerOperationInput` from the pinned
`cardano-ledger-wasm` package. That package hex-decodes the request into the
original `ByteString` and calls `Cardano.Ledger.Binary.decodeFullAnnotator` for
the Conway transaction. The browser structure from issue #124 is useful path
prior art, but its JavaScript CBOR key walker is test-only and cannot be reused
as a span implementation.

The feasibility spike must therefore test the actual pinned Haskell dependency
closure. It must distinguish these possible outcomes rather than assuming one:

1. ledger `DecCBOR` / `Annotator` instrumentation can retain offsets directly;
2. a Cardano-specific Haskell structural scan can consume the same original
   bytes alongside the successful ledger decode without reserialization; or
3. neither route is practical under the WASM and stable-path constraints.

## Slice 0: Time-boxed feasibility gate

Time box: at most 90 minutes of active investigation and probe work. A cold Nix
dependency fetch may wait outside that budget, but after one failed build retry
the pair must report the environmental blocker rather than expanding the
spike.

This slice makes no production, schema, OpenAPI, or browser changes. A visible
driver/navigator pair will produce a reproducible probe and evidence under its
runtime root. The probe must use the pinned native/WASM dependency versions and
must first establish that the same input is accepted by the existing Conway
ledger decoder.

Pass requires all of the following:

- offsets are observed while consuming the original decoded bytes, using a
  decoder byte-count/offset primitive or an equivalently direct cursor;
- at least a transaction root, body, witness set, and two repeated/nested
  structural occurrences receive distinct stable CDDL-aligned paths;
- every demonstrated interval is non-empty, in bounds, contained by its parent
  where applicable, and its direct slice equals the bytes consumed for that
  node;
- the method does not serialize ledger values, search the input for matching
  values, or decode in JavaScript;
- the APIs and dependencies used are available to the pinned Haskell/WASI
  package closure, with build evidence or a precise compile-level argument;
- malformed input follows the existing `MalformedCbor` path and emits no span
  result.

Fail means the pair records the attempted APIs, compiler/build output, and why
the result cannot satisfy one or more pass conditions. Ambiguity is not a pass.

After navigator verification, the ticket owner writes a feasibility decision
record and a `BLOCKED Q-001-feasibility-outcome` file to the epic owner. No
later slice starts until the answer is received.

## Conditional work after a confirmed pass

Only after the feasibility answer authorizes continuation will this plan and
`tasks.md` be amended with exact owned files and one bisect-safe commit per
slice. The implementation plan must then cover, without weakening the issue:

- the additive structural span contract and stable path vocabulary;
- Haskell/WASM emission for body, witness, input, output, redeemer, datum, and
  metadata nodes;
- bounds, containment, exact original-slice, nested/repeated, and malformed
  input tests;
- schema, OpenAPI, public documentation, and WASI smoke updates;
- the full `nix develop --quiet -c just ci` gate.

Browser rendering and browser-side decoding remain forbidden throughout.

## Slice 0R: Authorized environment-corrected rerun

The epic owner rejected the first spike's environmental stop as a real
feasibility result. One fresh 90-minute rerun of the same probe is authorized.
It must use the repository-standard `nix develop --quiet -c <command>` entry
point which prior epic tickets used for the full Haskell/crypto toolchain; it
must not construct another ad hoc Haskell.nix `shellFor` environment.

The pair starts from the archived probe and evidence but receives cleared
contexts and fresh runtime roots. The only permitted changes are adjustments
under the new runtime root needed to run that same probe through the approved
entry point. The original pass criteria remain unchanged.

- If the proper dev shell still cannot compile/run the probe, the pair records
  the specific error and returns a navigator-verified feasibility failure to
  the epic owner.
- If the probe runs and demonstrates every pass criterion, the ticket owner
  records and reports the successful decision, then amends this plan with
  exact acceptance-criteria implementation slices.

No production, schema, OpenAPI, dependency-pin, generated-artifact, gate, or
browser edit is authorized in Slice 0R.
