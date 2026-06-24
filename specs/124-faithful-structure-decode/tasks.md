# Tasks

## Slice 1: Faithful Structure Parity

- [ ] T124 Add hermetic RED Playwright parity coverage that key-walks the Amaru Conway transaction CBOR corpus, asserts non-empty corpus, and fails on missing, merged, duplicated, or mis-ordered Structure fields.
- [ ] T125 Add the `18d57a4f...` exact CQuisitor field-tree golden assertion from `/tmp/ux121/faithful-decode-spec.md`.
- [ ] T126 Update the decoded Structure tree to render body, witness_set, is_valid, and auxiliary_data fields in Conway CDDL order with explicit NULLs.
- [ ] T127 Keep `inputs`, `collateral`, and `reference_inputs` distinct; show `ttl`, `withdrawals`, `required_signers`, expanded `auxiliary_data.metadata`, and remove the duplicate Fee section.
- [ ] T128 Prove RED then GREEN in the driver/navigator protocol and run the focused parity command plus `./gate.sh`.
