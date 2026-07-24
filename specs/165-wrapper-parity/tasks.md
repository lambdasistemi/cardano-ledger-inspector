# Tasks: Reusable `tx.intent` Wrapper Parity

## Slice 1 — canonical wrapper and three-target parity

- [X] T165 Add a hermetic RED extension to `tx-extism-spike-smoke` that invokes
      `tx.intent` for registered and unknown-script requests and requires raw
      response-byte equality across WASI, native, and Extism.
- [X] T166 Turn `libs/cardano-ledger-inspector` into a reusable library that
      exposes the canonical `Conway.Inspector` operation entry point, delegates
      base semantics to the package-qualified external kernel, and owns the
      existing typed metadata and registry enrichment.
- [X] T167 Move the protocol-registry decoder and generated embedded-registry
      module boundary from the WASI executable tree into the local library
      without changing lookup, decode, fallback, or serialized output.
- [X] T168 Reduce the WASI executable to target I/O plus its separate RDF path,
      routing ledger-operation envelopes through the local library and
      preserving existing error behavior.
- [X] T169 Link `tx-deep-diagnosis` to the local wrapper library, and add the
      native raw-envelope conformance runner that exercises the same library
      component.
- [X] T170 Link the Extism plugin to the local wrapper library and add the
      `tx_intent` foreign export with the existing envelope/error contract.
- [X] T171 Generate identical embedded registry bytes for WASI, native, and
      Extism source assemblies; wire local package paths, `tx-rdf-core`, native
      host outputs, and any regenerated fixed dependency hashes.
- [X] T172 Prove GREEN for registered datum/redeemer/deployment enrichment,
      typed metadata, unknown-script fallback, and raw byte identity across all
      three targets.
- [X] T173 Document the local wrapper's target ownership, `tx_intent` Extism
      export, and tested parity guarantee in repository, architecture,
      installation, release, and plugin documentation.
- [X] T174 Run the focused checks and permanent `./gate.sh`, then commit one
      bisect-safe vertical slice as
      `refactor: share tx.intent wrapper across targets` with
      `Tasks: T165, T166, T167, T168, T169, T170, T171, T172, T173, T174`.
