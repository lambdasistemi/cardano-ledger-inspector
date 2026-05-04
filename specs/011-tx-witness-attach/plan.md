# Implementation Plan: Attach a VKey Witness to Transaction CBOR

**Branch**: `011-tx-witness-attach` | **Date**: 2026-05-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/011-tx-witness-attach/spec.md`

## Summary

Add `tx.witness.attach` to the Cardano Ledger WASI functional layer. The
operation accepts transaction CBOR plus `vkey_witness_cbor_hex`, patches the
transaction witness set through Haskell ledger types, returns the patched
transaction CBOR artifact, reports whether the operation inserted or replaced a
vkey witness, and returns structured rejection diagnostics for witness-input
problems that happen after the request envelope is decoded.

## Technical Context

**Language/Version**: Haskell2010 compiled with GHC 9.12 to `wasm32-wasi`; Nix
flakes for packages and checks

**Primary Dependencies**: `cardano-ledger-api`, `cardano-ledger-conway`,
`cardano-ledger-core`, `cardano-ledger-binary`, `aeson`, `bytestring`,
`containers`, `microlens`

**Storage**: None. The host owns the transaction document and detached witness
material and sends both on every call.

**Testing**: Nix smoke checks, OpenAPI regeneration checks, Fourmolu format
check, and existing repo test gates

**Target Platform**: WASI command artifact, native library consumers, generated
OpenAPI/docs artifacts

**Project Type**: Ledger-operation library with generated schema/docs surface

**Constraints**: Ledger code is authoritative, CBOR remains the data plane,
secret keys stay out of scope, non-target witness content must survive, and the
operation must not mutate inputs, outputs, or transaction body content.

## Constitution Check

- **Ledger Code Is Authoritative**: PASS. The patch happens in Haskell ledger
  code instead of browser JavaScript.
- **Transaction Documents Own State**: PASS. The operation consumes the current
  `tx_cbor` and returns a new `tx_cbor` artifact without hidden state.
- **JSON Control Plane, CBOR Data Plane**: PASS. JSON carries operation name
  and witness argument; transaction and witness data remain CBOR hex.
- **Explicit Context Only**: PASS. No hidden provider lookup or signing state is
  introduced.
- **The Library Is the Canonical Artifact**: PASS. Browser and CLI hosts will
  share the same typed entry point.

## Project Structure

### Documentation

```text
specs/011-tx-witness-attach/
├── spec.md
├── plan.md
└── tasks.md
```

### Source Code

```text
libs/cardano-ledger-inspector/src/Conway/
├── Inspector.hs
└── Common.hs

specs/001-ledger-functional-layer/
├── contracts/ledger-functional-api.md
├── openapi/cardano-ledger-functional.openapi.json
└── schemas/

flake.nix
justfile
.github/workflows/ci.yml
scripts/setup-branch-protection.sh
```

## Phase Plan

1. **Contract first**: Add the feature spec artifacts, public contract text,
   result schema, OpenAPI source wiring, and generated OpenAPI JSON updates.
2. **Red test**: Add a new smoke check for `tx.witness.attach` plus `just`/CI
   wiring and watch it fail before the operation exists.
3. **Implementation**: Add witness-payload decoding, vkey witness set
   insert/replace logic, transaction re-encoding, and structured result/error
   helpers.
4. **Verification**: Re-run the new smoke, then the relevant contract and repo
   checks.

## Design Notes

- Operation name: `tx.witness.attach`, with compatibility normalization for
  legacy `witness.attach`.
- Successful result shape: nested under `result.witness_attachment` to match
  the existing operation envelope style.
- Success status: `applied` with `witness_patch_action` equal to `inserted` or
  `replaced`.
- Rejection status: `rejected` with `errors` describing missing or malformed
  `vkey_witness_cbor_hex`.
- Command-level error boundary remains unchanged for malformed transaction hex,
  malformed transaction CBOR, malformed top-level operation envelopes, and
  unknown operations.

## Complexity Tracking

No constitution violations or complexity exceptions are required.
