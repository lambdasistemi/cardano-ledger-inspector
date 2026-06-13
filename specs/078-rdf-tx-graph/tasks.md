# Tasks: RDF Transaction Graph

## Slice 1 - WASI RDF Operation

- [X] T078-S1 Add the pinned `tx-rdf-core` source repository package to Cabal project files.
- [X] T078-S1 Add the executable dependencies needed by the WASI wrapper.
- [X] T078-S1 Implement `tx.rdf` and `tx.graph` in the WASI artifact without changing existing operation behavior.
- [X] T078-S1 Add `just check-rdf` fixture smoke coverage for deterministic Turtle.
- [X] T078-S1 Update the public contract/schema docs for the new RDF result.
- [X] T078-S1 Run `just build-wasm`, `just check-rdf`, and `./gate.sh`.
- [X] T078-S1 Commit as `feat: emit rdf transaction graphs`.

## Slice 2 - Browser Rendering

- [X] T078-S2 Add browser JSON extraction/state for the RDF result.
- [X] T078-S2 Call the RDF operation during decode and reset it with the existing operation state.
- [X] T078-S2 Render a graph panel with the emitted Turtle.
- [X] T078-S2 Add Playwright coverage proving the fixture graph appears.
- [X] T078-S2 Run `just ui-check`, `just test-playwright`, and `./gate.sh`.
- [X] T078-S2 Commit as `feat: render rdf transaction graphs`.
