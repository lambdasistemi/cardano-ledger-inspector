# Implementation Plan: Decode auxiliary transaction metadata

## Context

The pinned `cardano-ledger-wasm` kernel already returns human-oriented
`metadata_claims`, but its recursive `value` projection is deliberately
JSON-friendly and therefore cannot distinguish integers, bytes, and text.
This repository's WASI `Main.hs` already decodes the Conway transaction for
`tx.rdf`; it can use the same ledger value to enrich successful `tx.intent`
responses locally, without changing the external kernel pin or crossing the
repository boundary.

## Wire shape

Add `result.intent.auxiliary_data.metadata`, always an array. Each row is:

```json
{
  "label": "1694",
  "value": { "type": "map", "entries": [] }
}
```

The recursive node union is:

- integer: `{"type":"int","value":"-1"}`;
- bytes: `{"type":"bytes","hex":"00ff"}`;
- text: `{"type":"text","value":"hello"}`;
- list: `{"type":"list","items":[...]}`;
- map: `{"type":"map","entries":[{"key":...,"value":...}]}`.

Decimal strings preserve unbounded ledger integers across JavaScript hosts.
Hex preserves byte strings. Entry arrays preserve arbitrary key types, order,
and duplicates. The existing `claims` and `metadata_claims` fields are not
changed.

## Slice 1 — typed metadata vertical

One bisect-safe slice owns the complete behavior because the response change,
its proof, and its public contract must land together.

Owned files:

- `libs/cardano-ledger-inspector/app/Main.hs`
- `flake.nix`
- `specs/001-ledger-functional-layer/fixtures/` (one focused fixture or request,
  only if needed for hermetic all-constructor coverage)
- `specs/001-ledger-functional-layer/schemas/tx-intent-result.schema.json`
- `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`
- `nix/ledger-functional-openapi.nix`
- `specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json`

Implementation shape:

1. Extend the intent smoke first and observe it fail because
   `auxiliary_data.metadata` is absent. The regression must exercise int,
   bytes, text, list, and map nodes including nested values; it must also prove
   empty metadata and compatibility fields.
2. Parse only successful `tx.intent` envelopes in the WASI wrapper, decode the
   same supplied transaction through the ledger, and insert the typed metadata
   tree into `result.intent`. Preserve the kernel's error classification and
   all other operation responses byte-semantically.
3. Document the tagged recursive union in the JSON schema, API narrative and
   example; regenerate the committed OpenAPI artifact if the repository check
   requires it.
4. Run the focused checks and then `./gate.sh`.

## Verification

Focused proof:

- `just check-intent`
- `just check-openapi`
- `just format-check`
- `just hlint`

Final proof: `./gate.sh`.

No live boundary exists: the feature is a pure CBOR-to-JSON transformation over
committed fixtures.
