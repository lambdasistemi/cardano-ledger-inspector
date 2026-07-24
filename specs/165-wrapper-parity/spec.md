# Feature Specification: Reusable `tx.intent` Wrapper Parity

**Feature Branch**: `refactor/165-wrapper-parity`
**Created**: 2026-07-24
**Status**: Ready for implementation
**Input**: GitHub issue #165, follow-ups from #160 and #35 / PR #164, and
constitution principles III and V.

## User Story

As a consumer of the Cardano ledger inspector, I need `tx.intent` to return
the same enriched result whether I invoke the WASI reactor, the native Haskell
library, or the Extism plugin, so typed metadata and registered datum/redeemer
meaning do not depend on a packaging target.

## Acceptance Scenarios

1. Given any supported ledger-operation envelope, the WASI reactor delegates
   to the local `cardano-ledger-inspector` library entry point rather than
   owning operation enrichment in its executable.
2. Given the typed auxiliary-metadata fixture, every target that calls
   `tx.intent` returns the existing lossless metadata tree without changing its
   wire shape or bytes.
3. Given the registered SundaeSwap/Amaru fixture and explicit producer
   context, WASI, native, and Extism return the existing decoded datum and
   redeemer annotations, including deployment reference-input matches.
4. Given a representative transaction with unknown script hashes, all three
   targets preserve the existing raw fallback and return byte-identical
   `tx.intent` response bytes.
5. Given a non-`tx.intent` operation, the local wrapper preserves the external
   kernel's response and error behavior without target-specific enrichment.

## Functional Requirements

- **FR-001**: The local `cardano-ledger-inspector` package MUST expose the
  canonical `Conway.Inspector.runLedgerOperationInput` entry point and
  `InspectError` type from a reusable library component.
- **FR-002**: The local entry point MUST delegate base ledger semantics to the
  pinned `cardano-ledger-wasm` kernel, then apply the existing typed metadata
  and protocol-registry enrichments only to successful `tx.intent` responses.
- **FR-003**: The WASI executable MUST be an I/O and local-operation shell; it
  MUST NOT retain a second copy of the `tx.intent` enrichment implementation.
- **FR-004**: `tx-deep-diagnosis` MUST depend on and call the local wrapper
  library rather than linking the external kernel as its operation boundary.
- **FR-005**: The Extism plugin MUST depend on and call the same local wrapper
  library and MUST expose a `tx_intent` export accepting the standard JSON
  envelope.
- **FR-006**: The embedded protocol registry and its manifest-referenced files
  MUST be generated into every source assembly that builds the local wrapper
  (WASI, native, and Extism), with no runtime filesystem or network lookup in
  the operation.
- **FR-007**: Registry generation MUST remain manifest-driven: adding a
  declared blueprint or deployment-registry file MUST NOT require a Haskell
  source edit.
- **FR-008**: A native raw-envelope runner MAY exist solely as a conformance
  harness, but `tx-deep-diagnosis` remains the supported native product and
  MUST link the same library component exercised by that runner.
- **FR-009**: A hermetic check MUST run representative registered and
  unknown-script `tx.intent` envelopes through WASI, native, and Extism and
  compare the emitted response files as raw bytes, not merely parsed JSON.
- **FR-010**: The registered case MUST assert typed auxiliary metadata where
  present, decoded registered datums, a decoded registered spending redeemer,
  and deployment reference-input matches; the unknown case MUST assert raw
  fallback without invented decoded annotations.
- **FR-011**: Existing `tx.intent` fixtures and response bytes MUST not change
  as a consequence of extracting the wrapper.
- **FR-012**: Repository and Extism documentation MUST name the local wrapper
  as the target-independent owner and describe the tested parity guarantee
  without retaining the temporary #160/#35 exception.
- **FR-013**: The permanent tracked `gate.sh` MUST remain unchanged unless the
  new conformance check is not reached by `just ci`; it MUST NOT be deleted at
  finalization.

## Success Criteria

- **SC-001**: The existing `just check-intent` remains green with byte-stable
  fixture output after the wrapper extraction.
- **SC-002**: `just check-extism-spike` proves byte-identical registered and
  unknown-script `tx.intent` responses across all three targets.
- **SC-003**: `tx-deep-diagnosis`, the WASI reactor, and the Extism plugin all
  build against the local `cardano-ledger-inspector` library component.
- **SC-004**: `./gate.sh` succeeds at final HEAD and fresh required pull
  request checks all conclude successfully.

## Edge Cases

- Legacy operation name `intent` must receive the same enrichment as
  `tx.intent`.
- Malformed envelopes, malformed CBOR, unknown operations, registry decode
  failures, absent producer context, and unknown script hashes must retain
  current error or raw-fallback behavior.
- Direct registry matches continue to precede parameterized instances.
- Generated registry bytes must be identical across GHC 9.12 WASI builds and
  the GHC 9.8.4 native build.
- JSON object encoding order must remain deterministic across targets because
  parity is asserted on serialized bytes.

## Non-goals

- Implementing issue #31's signer-review operation.
- Changing `tx.intent` semantics, schemas, or existing fixture expectations.
- Adding provider calls or implicit context to the wrapper.
- Moving the WASI-only `tx.rdf` operation into the cross-target contract.
- Replacing the external ledger kernel; the local library wraps and enriches
  its typed operation entry point.
