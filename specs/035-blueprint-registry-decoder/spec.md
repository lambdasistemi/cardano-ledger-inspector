# Feature Specification: Decode registered Plutus data in tx.intent

**Feature Branch**: `feat/35-blueprint-registry-decoder`  
**Created**: 2026-07-22  
**Status**: Ready for implementation  
**Input**: GitHub issue #35 and its 2026-07-19 redeemer/blueprint corrections.

## User Story

As a transaction analyst or downstream workbench, I need `tx.intent` to
identify registered scripts and decode their inline datums and redeemers using
vendored CIP-57 blueprints, so I can understand known protocol activity without
hand-walking PlutusData or adding protocol-specific Haskell.

## Acceptance Scenarios

1. Given an output whose payment script hash directly matches
   `validators[]`, `tx.intent` preserves the raw datum and adds a
   `decoded_datum` labelled from that unparameterized registry entry.
2. Given an output whose payment script hash matches `instances[]`,
   `tx.intent` preserves the raw datum and adds a parameterized
   `decoded_datum` with its curated deployment label.
3. Given PlutusData and a matching datum or redeemer schema, the decoder
   handles constructors, maps, lists, integers, and byte strings recursively,
   using schema constructor and field names in deterministic JSON.
4. Given a matched redeemer whose purpose can be resolved to a registered
   script hash from the transaction and explicit producer context,
   `tx.intent.scripts[]` preserves `redeemer_cbor_hex` and adds
   `decoded_redeemer` from the same registry and decoder.
5. Given the issue #31 SundaeSwap fixture plus its committed producer context,
   cluster A is labelled `Amaru Network Compliance treasury`, cluster B
   outputs are labelled `SundaeSwap V3 order`, the treasury spend redeemer
   decodes against `TreasurySpendRedeemer`, and the four transaction
   reference inputs are cross-matched against the journal deployment outrefs.
6. Given an unknown script hash, absent producer context, or a schema mismatch,
   existing raw datum/redeemer fields and generic cross-reference behavior are
   preserved without inventing a protocol identity.
7. Given another valid blueprint or deployment registry added to
   `docs/inspector/protocols/registry.json`, rebuilding the engine consumes
   it without a Haskell source change.

## Functional Requirements

- **FR-001**: The engine MUST load the protocol registry, every referenced
  blueprint, and every referenced deployment registry at build time; runtime
  network or filesystem access MUST NOT be required.
- **FR-002**: Script lookup MUST prefer direct `validators[]` matches, then
  `instances[]`, then enrich a match from deployment registries.
- **FR-003**: Datum lookup MUST use the output payment script hash. Redeemer
  lookup MUST use the script hash resolved for its ledger purpose and MUST NOT
  identify a redeemer solely because one schema happens to parse it.
- **FR-004**: The pure decoder MUST support CIP-57 constructor, map, list,
  integer, byte-string, definition-reference, and alternative-schema forms,
  plus the registry scaffold's named schema vocabulary where an upstream
  blueprint intentionally declares opaque `Data`.
- **FR-005**: Successful decoded values MUST retain constructor names, schema
  field names, exact decimal integers, lowercase hexadecimal bytes, list order,
  and map entry order without lossy JSON-object coercion.
- **FR-006**: A decoded annotation MUST identify `protocol`, `version`,
  `validator`, `label`, and `parameterized`, expose decoded
  `fields`, and carry deployment metadata when available.
- **FR-007**: Parameterized annotations MUST distinguish unknown parameters
  from known parameters. Unparameterized annotations MUST explicitly report
  `parameterized: false`.
- **FR-008**: Deployment enrichment MUST expose journal scope, owner, address,
  script role, deployment outref, and which current reference-input outrefs
  matched the deployment.
- **FR-009**: `decoded_datum` MUST sit alongside the existing raw datum on
  `intent.value.outputs[]`; `decoded_redeemer` MUST sit alongside
  `redeemer_cbor_hex` on `intent.scripts[]`.
- **FR-010**: Unknown hashes, unavailable context, and decode failures MUST
  fall back to existing raw output without changing error classification for
  the ledger operation.
- **FR-011**: The public result schema, generated OpenAPI artifact, and API
  narrative MUST document decoded datum and redeemer annotations for both
  parameterized and unparameterized matches.
- **FR-012**: The issue #31 regression MUST be hermetic and MUST observe RED
  before implementation and GREEN afterward.
- **FR-013**: Registry loading and decoding MUST be pure and deterministic for
  identical transaction CBOR, explicit context, and embedded registry bytes.

## Success Criteria

- **SC-001**: One hermetic issue #31 check identifies all ten known script
  outputs: one Amaru Network Compliance treasury output and nine SundaeSwap V3
  order outputs.
- **SC-002**: The same check reports all four reference-input outrefs as
  journal deployment matches and decodes the registered treasury spend
  redeemer.
- **SC-003**: Focused coverage demonstrates all five required PlutusData
  containers/scalars and both `parameterized` boolean cases.
- **SC-004**: Repeated runs over identical inputs produce byte-identical JSON.
- **SC-005**: The permanent repository `./gate.sh` and fresh remote pull
  request checks complete successfully.

## Edge Cases

- Registry entries may point to a missing blueprint, validator title, or
  deployment file; the build/check must fail closed with the bad entry named.
- A known script may have no datum or no matching datum schema.
- A spending redeemer may lack the producer transaction needed to resolve its
  input script hash; it remains raw.
- A schema may contain recursive references, unsupported forms, ambiguous
  alternatives, constructor mismatches, or field-count mismatches; it remains
  raw and does not crash the operation.
- Multiple deployment entries may mention the same hash or outref; registry
  source order is stable and duplicates must not make output nondeterministic.

## Non-goals

- Protocol-specific Haskell decoder branches.
- Browser or provider-adapter decoding.
- Hidden network lookups or implicit prior-call state.
- Changing validation, script evaluation, or raw PlutusData projections.
- Deleting or replacing the repository's tracked permanent `gate.sh`.
- Refactoring the current wrapper back into a reusable library linked by the
  native CLI and Extism target. The parent authorized the same WASI-wrapper
  boundary used by issue #160 because the blocked cardano-swiss-knife consumers
  execute this WASI artifact. Native/Extism `tx.intent` will not gain these
  annotations in this ticket; that constitutional parity gap is tracked as a
  required follow-up issue linked from the pull request.
