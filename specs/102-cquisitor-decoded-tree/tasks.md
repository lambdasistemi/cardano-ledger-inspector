# Tasks

## Slice 1 — Material Baseline And Two-Pane Workspace

- [X] T102 Add Material Symbols and Roboto font loading to the inspector HTML shell.
- [X] T103 Convert available shell and inspector controls to bundled `md-*` Material Web components.
- [X] T104 Reshape `/inspect` into a responsive two-pane workspace with input, active chain-data, and books placeholder on the left.
- [X] T105 Update Playwright coverage for icon rendering, typography signal, and two-pane layout.
- [X] T106 Run `./gate.sh`, record evidence, and commit the slice.

## Slice 2 — SPARQL Decoded Structure Tree

- [X] T107 Add graph/SPARQL decoded-tree query rows and PureScript FFI types.
- [X] T108 Render an expandable decoded-structure tree from SPARQL rows over `tx.rdf`.
- [X] T109 Include transaction/body/input/output/mint/cert/withdrawal/fee/validity/signer/witness/redeemer/metadata sections when graph data is present.
- [X] T110 Keep optional label/type bindings for future book resolution while rendering raw opaque leaves for this child.
- [X] T111 Update Playwright coverage for fixture decode, decoded tree visibility, expand/collapse, and subpath safety.
- [X] T112 Run `./gate.sh`, record evidence, and commit the slice.

## Finalization — Orchestrator Owned

- [X] T113 Verify the full local gate and non-root subpath browser smoke at HEAD.
- [X] T114 Verify PR preview renders `/inspect`, `/settings`, `/library`, and fixture decode.
- [X] T115 Update PR body, run finalization audit, drop `gate.sh`, and leave PR draft for epic-owner review.

## Corrective Slice 3 — Use Genuine Conway Fixture

- [X] T116 Restore the branch gate for returned PR work and record the corrective scope.
- [X] T117 Replace the malformed `/tmp/epic-97/clins-102/sample-tx.cbor` corrective input with the genuine in-repo `specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex` fixture.
- [X] T118 Cancel the S4 dependency fix after A-002 and remove the uncommitted dependency cabal/test scaffolding without flake, pin, hash, or dependency PR changes.
- [X] T119 Remove the failed browser-side CBOR normalization/fallback experiment and restore the simple inspector FFI wrapper.
- [X] T120 Verify the decoded-structure tree renders from the genuine Conway fixture RDF graph and is not left pending.
- [X] T121 Update preview subpath coverage to decode the genuine in-repo Conway fixture.
- [ ] T122 Re-run final PR CI/preview smoke, update PR body/status, drop `gate.sh`, and leave PR draft for epic-owner review.
