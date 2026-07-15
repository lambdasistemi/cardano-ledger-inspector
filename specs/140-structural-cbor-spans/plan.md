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

## Slice 0N: Hermetic Nix feasibility check

Time box: three hours, including normal Nix evaluation and compilation time.

The pair will add one tracked, non-shipping Haskell test executable which uses
the pinned native package plan and the existing committed Conway fixture. The
native haskell.nix project will expose that executable component, and a new
flake `runCommand` check will invoke it. `nix build` must execute the assertion;
merely packaging a script or compiling an executable is not a pass.

Owned files:

- `libs/cardano-ledger-inspector/test/StructuralCborSpanFeasibility.hs`
- `libs/cardano-ledger-inspector/cardano-ledger-inspector.cabal`
- `nix/host/tx-deep-diagnosis-native/default.nix`
- `nix/host/default.nix`
- `flake.nix`

RED adds the component/check wiring and a focused failing assertion, then runs:

```sh
nix build --print-build-logs \
  .#checks.x86_64-linux.structural-cbor-span-feasibility
```

The observed failure must come from the test assertion, not evaluation,
dependency resolution, a missing fixture, or an unexecuted wrapper. GREEN
implements only the minimal Conway-specific ledger-first scanner necessary to
flip that assertion and prove:

- offsets come from `decodeWithByteSpan` / `peekByteOffset` while consuming the
  original decoded bytes;
- root, body, witness set, and at least two indexed nested/repeated paths have
  distinct, non-empty, in-bounds intervals;
- child containment and exact original-slice equality hold;
- malformed input uses the existing `MalformedCbor` path and produces no
  spans;
- no reserialization, byte search, guessed offset, JavaScript, or general CBOR
  architecture is introduced.

After GREEN the pair runs the focused check again, `just format-check`,
`just hlint`, and inherited `./gate.sh` without modifying it. A navigator-
verified single commit closes the slice. Production/schema/OpenAPI/browser
work remains forbidden until the ticket owner records the successful gate and
amends the remaining implementation plan.

Slice 0N stopped before a valid RED. Adding the inspector package to the native
GHC 9.8.4 plan also enabled its shipping `wasm-tx-inspector` executable. After
one wiring correction, Cabal reported an irreconcilable plan between the
compiler's boot `containers-0.6.8` and the shipping executable's pinned
`tx-rdf-core`, which requires `containers >=0.7 && <0.8`. No offset assertion
executed, so this result neither proves nor disproves the cborg cursor API.

## Slice 0I: Final component-isolated hermetic check

Time box: the same three-hour bound. This is the final authorized feasibility
retry regardless of outcome.

The pair will remove the uncommitted Slice 0N wiring and place the probe in a
separate, non-shipping Cabal package. That package must depend only on the core
ledger/CBOR libraries used by the probe, so the native solve cannot include
`wasm-tx-inspector` or `tx-rdf-core`. No `tx-rdf-core` pin or bound may change.

Owned files:

- `tests/structural-cbor-span-feasibility/structural-cbor-span-feasibility.cabal`
- `tests/structural-cbor-span-feasibility/Main.hs`
- `nix/host/tx-deep-diagnosis-native/default.nix`
- `nix/host/default.nix`
- `flake.nix`

The prior uncommitted additions to
`libs/cardano-ledger-inspector/cardano-ledger-inspector.cabal` and
`libs/cardano-ledger-inspector/test/StructuralCborSpanFeasibility.hs` must be
removed. The separate package is added only to the native haskell.nix project,
exposed through the host targets, and invoked by the same
`checks.x86_64-linux.structural-cbor-span-feasibility` `runCommand` against the
committed Conway fixture.

RED and GREEN use the same command and behavior criteria as Slice 0N. A valid
RED must reach and fail the behavior-specific assertion. If component
isolation cannot reach that assertion, the pair records the exact compiler or
planner error and stops; no further wiring correction or retry is authorized.
If GREEN proves every criterion, the gate releases full implementation
planning. Either outcome is navigator-verified and reported through the parent
Q/A protocol before any subsequent work.

Final result: the isolated package was untracked, so the Git-backed flake
source omitted it and the native planner reported that its package location did
not exist. The navigator verified this as a source-filter mistake rather than
Haskell, cborg, or component-isolation evidence. Per A-003's unconditional
retry cap, no correction or rerun is authorized. All probe wiring was reverted,
the gate remains unproved, and the conditional production plan is cancelled
for this ticket.
