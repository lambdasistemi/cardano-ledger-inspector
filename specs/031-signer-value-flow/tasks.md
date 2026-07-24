# Tasks: Signer-Facing Transaction Review

## Slice 1 — review vocabulary and native contract test

- [X] T031 Add RED Hspec expectations for the five output-control categories,
      five evidence-provenance tags, version, lossless decimal amounts,
      nullable net amount, and deterministic review-record JSON shape.
- [X] T032 Add the internal `Conway.Inspector.Review` vocabulary and JSON
      encoders needed to turn the focused contract test GREEN, without wiring
      `tx.review` or implementing output classification.
- [X] T033 Expose and execute the native review contract test as a real Nix
      check using the haskell.nix test component.
- [X] T034 Add `just check-review-types` and include the check in `just ci`
      while leaving permanent `gate.sh` unchanged.
- [X] T035 Run the focused check, format, hlint, and permanent gate, then
      commit one bisect-safe slice as
      `test: establish tx.review vocabulary contract` with
      `Tasks: T031, T032, T033, T034, T035`.

## Slice 2 — shared review projection and three-target contract

- [X] T036 Add RED operation smokes for complete-context and issue-fixture
      `tx.review` requests, including the explicit unprovable-net message.
- [X] T037 Project the shared enriched `tx.intent` result into the versioned
      signer-review result without parsing human-readable intent strings or
      changing existing operation bytes.
- [X] T038 Group outputs deterministically into signer-controlled, external
      key, script, bootstrap, and unknown categories with authoritative role
      selection and explicit evidence provenance.
- [X] T039 Surface high-value groups in descending order and separately report
      regular inputs, withdrawals, conditional collateral, read-only reference
      inputs, fee, and net-signer-value status.
- [X] T040 Prove the issue fixture's treasury continuation, nine SundaeSwap
      order locks, unlabeled script lock, external-key destination, fee,
      collateral values, and one missing regular input.
- [X] T041 Keep self-declared metadata claims isolated from ledger facts,
      context-proven facts, registry annotations, and heuristic labels.
- [X] T042 Export `tx_review` from Extism and prove registered plus
      unknown-registry response-byte parity across WASI, native, and Extism.
- [X] T043 Publish the `tx.review` JSON schema and regenerate the committed
      OpenAPI document.
- [X] T044 Update the operation registry, API/architecture/installation
      documentation, release export descriptions, and operation count.
- [X] T045 Re-run existing intent and wrapper-parity checks to prove no
      regression in `tx.intent`.
- [X] T046 Run all focused checks, format, hlint, and permanent gate, then
      commit one bisect-safe slice as
      `feat: explain signer-facing transaction value flow` with
      `Tasks: T036, T037, T038, T039, T040, T041, T042, T043, T044, T045, T046`.
