# Feasibility decision: exact structural CBOR source spans

Date: 2026-07-15

Current decision: **UNPROVED — neither bounded ad hoc attempt executed the
probe, so production implementation remains stopped.** The epic owner verified
that the default dev shell intentionally has no Haskell toolchain and ruled
that both prior failures answer only whether an ad hoc script can run. Q-002
therefore authorizes Slice 0N: a real hermetic Nix build/check target. This
record preserves the earlier evidence but is not the final feasibility
decision.

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
browser work follows this record unless Slice 0R executes successfully and is
navigator-verified. The first environmental stop must not be relabelled as an
architectural proof, and no approximate span map may be substituted.

## Parent decision on Q-001

The epic owner authorized only an environment-corrected rerun of the same
probe. The fresh pair must use `nix develop --quiet -c <command>`, must not
recreate the failing ad hoc `shellFor`, and must return the specific error if
the proper dev shell still cannot compile or run it. A successful executed
probe releases planning for the original acceptance-criteria implementation;
it does not itself authorize unrelated scope.

## Slice 0R result

The pair copied `Main.hs`, `cabal.project`, and
`feasibility-probe.cabal` byte-for-byte from the first archive and received
navigator approval for this single command:

```sh
nix develop --quiet -c bash \
  /tmp/epic-97/cardano-ledger-inspector-140/feasibility-rerun-driver/handoffs/run-probe.sh
```

The command ran once and exited `127`. Discovery inside that exact dev shell
reported:

```text
cabal=MISSING
ghc=MISSING
ghci=MISSING
ghc-pkg=MISSING
pkg-config=MISSING
PKG_CONFIG_PATH=UNSET
```

The first compile command therefore failed with `cabal: command not found`.
There was no `--expr`, `shellFor`, bare-host compile, custom shell, retry,
fallback, assertion change, or repository edit. The navigator reproduced the
same environment result and verified `feasibility-fail`; the ticket owner then
independently reran read-only discovery through `nix develop --quiet -c` and
confirmed the same missing toolchain.

The copied probe hashes remained:

- `Main.hs`:
  `e4a1904a645cdc323c1d8407b6b98aae5d962867c585774769c6837259f5ece0`
- `cabal.project`:
  `b3a885143bbf5a4dfaf628847a1bbfec7d003fcec457de974989f8d635eecee2`
- `feasibility-probe.cabal`:
  `5db631f8f3231ec5b99400f6901306f91231c9ea336e0cd9a32afc272851b070`

No spans or slices were produced. Ledger acceptance inside the combined probe,
bounds, containment, exact original slicing, distinct repeated paths, and the
malformed zero-span outcome remain unproved. Per Q-001's conditional answer,
this specific proper-shell failure justifies the option-1 stop and is returned
to the epic owner through Q-002 before finalization.

## Parent decision on Q-002

The epic owner independently verified that `devShells.default` intentionally
contains no Cabal, GHC, or pkg-config toolchain and that this repository builds
Haskell only through hermetic package/check derivations. The exit-127 result is
real and reproducible, but it is not evidence against cborg's offset
capability.

One three-hour feasibility slice is authorized to add a small tracked Haskell
test executable and a real `checks.x86_64-linux` derivation which invokes it
against an existing fixture. A passing executed check proves feasibility and
releases full implementation planning. A compiler/runtime/assertion failure
caused by Haskell or the pinned library, rather than another tooling gap, is the
first acceptable feasibility stop.

## Slice 0N result and parent decision on Q-003

Slice 0N reached the native Cabal planner but never reached a behavior-specific
RED. Adding `cardano-ledger-inspector` to the GHC 9.8.4 plan also enabled its
shipping `wasm-tx-inspector` component. Reusing the existing pinned
`tx-rdf-core` source stanza then exposed a real constraint conflict:

```text
ghc-heap => containers==0.6.8/installed-0.6.8
tx-rdf-core => containers>=0.7 && <0.8
```

The driver stopped after that single reasoned correction, and the navigator
verified the conflict. No CBOR offset assertion executed.

The epic owner ruled that this is a component-coupling failure, not evidence
against `decodeWithByteSpan` or `peekByteOffset`, and authorized one final
three-hour retry. Slice 0I must isolate the probe in a separate non-shipping
Cabal package whose solve excludes `wasm-tx-inspector` and `tx-rdf-core`; their
pins and bounds are immutable. This is the final retry regardless of outcome.
A failure to reach behavior-specific RED is the accepted final stop. A passing
GREEN releases full acceptance-criteria implementation planning.
