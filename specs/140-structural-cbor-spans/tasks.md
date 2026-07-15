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
