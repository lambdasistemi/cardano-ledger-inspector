# Tasks: Exact Structural CBOR Source Spans

Only Slice 0 is scheduled. Implementation tasks are intentionally absent until
the feasibility outcome is verified and accepted through the parent Q/A
protocol.

## Slice 0 — time-boxed feasibility gate

- [ ] T140-S0A Confirm the existing pinned Conway decoder accepts the selected
  committed fixture and identify the exact original-byte decoder/cursor API
  available in the pinned native and WASM closure.
- [ ] T140-S0B Produce a bounded Haskell probe demonstrating, or disproving,
  direct original-byte intervals for root, body, witness set, and distinct
  repeated/nested structural paths without reserialization or byte searching.
- [ ] T140-S0C Record bounds, containment, exact-slice, malformed-input, and
  WASM-availability evidence under the driver runtime root.
- [ ] T140-S0D Obtain navigator verification of the probe and evidence, then
  publish the feasibility outcome through `Q-001-feasibility-outcome` before
  scheduling any implementation slice.

## Deferred after the gate

Contract, implementation, corpus/property tests, generated artifacts,
documentation, and final CI tasks will be added only if the parent accepts a
passing feasibility result.
