# Tasks: Exact Structural CBOR Source Spans

Only Slice 0 is scheduled. Implementation tasks are intentionally absent until
the feasibility outcome is verified and accepted through the parent Q/A
protocol.

## Slice 0 — time-boxed feasibility gate

- [X] T140-S0A Confirm the existing pinned Conway decoder accepts the selected
  committed fixture and identify the exact original-byte decoder/cursor API
  available in the pinned native and WASM closure.
- [X] T140-S0B Produce a bounded Haskell probe demonstrating, or disproving,
  direct original-byte intervals for root, body, witness set, and distinct
  repeated/nested structural paths without reserialization or byte searching.
- [X] T140-S0C Record bounds, containment, exact-slice, malformed-input, and
  WASM-availability evidence under the driver runtime root.
- [X] T140-S0D Obtain navigator verification of the probe and evidence, then
  publish the feasibility outcome through `Q-001-feasibility-outcome` before
  scheduling any implementation slice.

## Deferred after the gate

Contract, implementation, corpus/property tests, generated artifacts,
documentation, and final CI tasks will be added only if the parent accepts a
passing feasibility result.

## Slice 0R — environment-corrected feasibility rerun

- [X] T140-S0R-A Restore the archived probe into a fresh runtime root without
  editing the repository and identify the repo-standard
  `nix develop --quiet -c <command>` invocation.
- [X] T140-S0R-B Attempt to compile and run the same ledger-first Conway span
  probe in the proper dev shell within a fresh 90-minute time box.
- [X] T140-S0R-C Record executed bounds, containment, exact original-slice,
  repeated-path, malformed-input, and pinned WASM evidence, or the exact proper
  dev-shell error if it still cannot run.
- [X] T140-S0R-D Obtain navigator verification and publish the executed rerun
  outcome before scheduling production work.

## Slice 0N — hermetic Nix feasibility check

Outcome: stopped before a behavior-specific RED because the native solve
coupled the inspector package's shipping executable and pinned `tx-rdf-core`
into the GHC 9.8.4 plan. These tasks remain incomplete and are superseded by
the final component-isolated retry below.

- [-] T140-S0N-A Add a non-shipping Haskell test executable and expose it from
  the existing native haskell.nix project.
- [-] T140-S0N-B Wire a real flake `runCommand` check which invokes the test on
  the committed Conway fixture, then observe RED from the focused assertion.
- [-] T140-S0N-C Implement the minimal ledger-first, Conway-specific scanner
  using direct cborg byte offsets and observe the hermetic check GREEN for
  bounds, containment, exact original slices, repeated paths, and malformed
  zero-span behavior.
- [-] T140-S0N-D Run format, lint, and inherited gates; obtain navigator
  verification of the single feasibility commit and publish the final gate
  outcome before any production slice.

## Slice 0I — final component-isolated hermetic check

- [X] T140-S0I-A Remove the uncommitted Slice 0N package coupling and add a
  separate non-shipping Cabal package whose dependency graph excludes
  `wasm-tx-inspector` and `tx-rdf-core` without changing their pins or bounds.
- [-] T140-S0I-B Expose that isolated component through the native haskell.nix
  host targets and observe a behavior-specific RED from the existing focused
  flake check.
- [-] T140-S0I-C Implement the minimal ledger-first Conway scanner and observe
  GREEN for direct offsets, exact slices, bounds, containment, repeated paths,
  and malformed zero-span behavior.
- [X] T140-S0I-D Run the focused check, obtain navigator verification of the
  pre-RED source-filter failure, revert all probe wiring, and publish the final
  accepted unproved stop without another retry.

`[-]` marks tasks cancelled by the exhausted feasibility gate rather than
completed. Slice 0I did not reach RED because the new untracked package was
omitted from the Git-backed flake source. A-003 cancels T140-S0I-B and
T140-S0I-C rather than authorizing a correction or fourth attempt. All deferred
production, schema, corpus, generated-artifact, and documentation
implementation work is cancelled for issue #140.
