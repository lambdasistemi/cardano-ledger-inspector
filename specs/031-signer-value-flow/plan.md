# Implementation Plan: Signer-Facing Transaction Review

## Context

The pinned external kernel already implements `tx.intent`, including signer
credential matching, resolved-input accounting, output buckets, fee,
withdrawals, collateral summary, scripts, and explicit context coverage. The
local wrapper added by #165 enriches that result with typed metadata and
protocol-registry datum/redeemer annotations, and all three targets now call
that same wrapper.

`tx.review` will build on that boundary. The wrapper recognizes a review
request, invokes the kernel's `tx.intent` path with the same transaction and
arguments, applies the existing local intent enrichments, then passes the
enriched intent plus the already-decoded Conway transaction to a pure review
module. The emitted envelope restores `op: tx.review` and contains
`result.review`. Existing operations take their current path unchanged.

This makes review semantics target-independent and prevents a browser, native
CLI, or Extism-specific implementation from drifting.

## Data and Evidence Model

`Conway.Inspector.Review` owns the JSON vocabulary and pure projection:

- `ControlCategory`: signer-controlled, external key, script, bootstrap, or
  unknown.
- `EvidenceProvenance`: ledger-proven, context-proven, registry-decoded,
  metadata-claim, or heuristic.
- `ControlGroup`: deterministic grouping by category, address, and role.
- `ReviewSource`: regular inputs, withdrawals, conditional collateral, and
  read-only reference inputs.
- `ReviewResult`: identity, context, sources, groups, high-value projection,
  fee, collateral, net status, claims, and warnings.

The module reuses `tx.intent` buckets and signer net values. It uses Conway
ledger lenses only for structured body facts that the current intent result
does not expose structurally, notably total collateral and collateral return.
It does not parse human-readable strings from `metrics`, `effects`, or
`sections`.

Roles are selected in descending authority:

1. a same-address continuation from a resolved input
   (`context_proven`), retaining any registry-decoded protocol label and
   `registry_decoded` evidence;
2. a protocol label from a decoded registered datum
   (`registry_decoded`);
3. signer-controlled return/change candidate (`heuristic`);
4. generic external-key, script-lock, bootstrap, or unknown role
   (`ledger_proven`).

Metadata claims are copied separately and never enter this selection.

## Slice 1 — Review Vocabulary and Native Contract Test

This is the calibration slice for the unproven Qwen driver. It does not wire a
new operation and does not touch classification logic. It adds the review
types/encoders, an Hspec contract test over a small synthetic value, and a Nix
check reached by `just check-review-types` and `just ci`.

Owned files:

- `libs/cardano-ledger-inspector/src/Conway/Inspector/Review.hs` (new)
- `libs/cardano-ledger-inspector/test/ReviewSpec.hs` (new)
- `libs/cardano-ledger-inspector/cardano-ledger-inspector.cabal`
- `nix/host/tx-deep-diagnosis-native/default.nix`
- `nix/host/default.nix`
- `flake.nix`
- `justfile`

The focused RED is the missing review test component/check. GREEN proves exact
encoding of the five control categories, five provenance tags, version string,
decimal-string amounts, nullable net amount, and deterministic record shape.

## Slice 2 — Shared Review Projection and Three-Target Contract

The second slice extends the reviewed vocabulary with projection logic, wires
`tx.review` through the shared local wrapper, and adds the public contract,
issue-fixture smoke, and Extism export. It may modify the Slice 1 files and:

- `libs/cardano-ledger-inspector/src/Conway/Inspector.hs`
- `apps/wasm-extism-spike/src/Extism/Spike.hs`
- `apps/wasm-extism-spike/wasm-extism-spike.cabal`
- `apps/wasm-extism-spike/README.md`
- `specs/001-ledger-functional-layer/schemas/tx-review-result.schema.json`
  (new)
- `specs/001-ledger-functional-layer/schemas/ledger-operation-response.schema.json`
- `specs/001-ledger-functional-layer/openapi/cardano-ledger-functional.openapi.json`
- `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`
- `nix/ledger-functional-openapi.nix`
- `README.md`
- `gh-docs/api.md`
- `gh-docs/functional-layer.md`
- `gh-docs/architecture.md`
- `gh-docs/installation.md`
- `.github/workflows/release-assets.yml`

No new CBOR fixture is allowed. The smoke derives review requests from
`tx-validate-complete-request.json` and
`sundae-swap-usdm-disbursement.hex` plus its existing producer fixture.

The focused RED first calls `tx.review` and observes
`unknown_ledger_operation`/missing `tx_review`; GREEN asserts:

- the stable review schema and provenance vocabulary;
- all five control-category values are schema-valid, even when a particular
  fixture does not exercise every value;
- complete versus incomplete net-signer status;
- deterministic grouping and high-value ordering;
- exact issue-fixture indices, amounts, roles, fee, collateral, and missing
  input count;
- metadata claim isolation;
- byte-identical registered and unknown-registry responses across WASI,
  native, and Extism;
- unchanged existing `tx.intent` behavior.

## Verification

Slice 1 focused proof:

- `just check-review-types`
- `just format-check`
- `just hlint`
- `./gate.sh`

Slice 2 focused proof:

- `just check-review`
- `just check-intent`
- `just check-extism-spike`
- `just check-openapi`
- `just format-check`
- `just hlint`
- `./gate.sh`

The ticket owner independently inspects every diff and reruns each focused
check plus the permanent gate after the navigator verifies the commit. Final
remote proof requires fresh required GitHub checks on the pushed final head.

## Constitution and Scope Check

- Ledger/crypto semantics remain in Haskell.
- CBOR remains the data plane; JSON remains the explicit control/result plane.
- Producer context is explicit and never fetched by the operation.
- The local library remains canonical across WASI, native, and Extism.
- No `cardano-swiss-knife` file is touched.
- The permanent repository `gate.sh` remains present; this ticket extends the
  `just ci` graph, not the gate script.
