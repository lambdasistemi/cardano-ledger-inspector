# Tasks: Decode registered Plutus data in tx.intent

## Slice 1 — embedded registry decoder vertical

- [X] T035 Add a hermetic RED extension to `tx-intent-smoke` in `flake.nix`
      using the issue #31 fixture and committed producer CBOR, covering direct
      and parameterized labels, all four deployment outref matches, redeemer
      decoding, unknown fallback, and deterministic repeat output.
- [X] T036 Generate the build-time embedded registry module from
      `docs/inspector/protocols/registry.json` and its manifest-referenced
      blueprint/deployment files in `flake.nix`, failing closed on missing
      files without runtime filesystem access.
- [X] T037 Implement pure registry parsing, lookup order, deployment
      enrichment, and lossless schema-driven constructor/map/list/integer/bytes
      decoding in
      `libs/cardano-ledger-inspector/app/Conway/Inspector/ProtocolRegistry.hs`.
- [X] T038 Enrich successful `tx.intent` output and script rows with
      `decoded_datum` and `decoded_redeemer` in
      `libs/cardano-ledger-inspector/app/Main.hs`, preserving raw fallback and
      explicit-context semantics.
- [X] T039 Wire the generated module and new engine module in
      `libs/cardano-ledger-inspector/cardano-ledger-inspector.cabal`, and
      finalize the existing interface note in
      `docs/inspector/protocols/registry.json`.
- [X] T040 Add the hermetic producer fixture at
      `specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement-input-64f27254.hex`.
- [X] T041 Document both decoded annotations and parameterization cases in
      `specs/001-ledger-functional-layer/schemas/tx-intent-result.schema.json`,
      `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`,
      `nix/ledger-functional-openapi.nix`, and the generated OpenAPI artifact.
- [X] T042 Prove GREEN with `just check-intent`, `just check-openapi`,
      `just format-check`, `just hlint`, and `./gate.sh`.
- [X] T043 Commit one bisect-safe vertical slice as
      `feat: decode registered Plutus data in tx.intent` with
      `Tasks: T035, T036, T037, T038, T039, T040, T041, T042, T043`.
