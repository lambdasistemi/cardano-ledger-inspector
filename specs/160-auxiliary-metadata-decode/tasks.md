# Tasks: Decode auxiliary transaction metadata

## Slice 1 — typed metadata vertical

- [ ] T160 Add a hermetic RED regression for
      `intent.auxiliary_data.metadata`, covering int, bytes, text, list, map,
      arbitrary nesting, empty metadata, and existing claim compatibility.
- [ ] T161 Enrich successful `tx.intent` responses in the Haskell/WASI wrapper
      with the lossless tagged metadata tree while preserving other operations
      and error behavior.
- [ ] T162 Document the recursive metadata union in the result schema, API
      contract, example, and generated OpenAPI artifact where applicable.
- [ ] T163 Prove GREEN with `just check-intent`, `just check-openapi`,
      `just format-check`, `just hlint`, and `./gate.sh`; commit as one
      bisect-safe slice with `Tasks: T160, T161, T162, T163`.

