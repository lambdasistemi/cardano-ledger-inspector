# Issue 124: Faithful Structural Decode

## User Story

As a transaction analyst using the Structure tab, I need the decoded tree to be a faithful Conway transaction mirror rather than a lossy summary, so I can compare it with CQuisitor and inspect all structural fields without guessing what was omitted or merged.

## Requirements

- The Structure tree MUST render the Conway transaction as `transaction_hash` plus `transaction` with `body`, `witness_set`, `is_valid`, and `auxiliary_data`.
- The `body` fields MUST appear in Conway CDDL order: `inputs`, `outputs`, `fee`, `ttl`, `certs`, `withdrawals`, `update`, `auxiliary_data_hash`, `validity_start_interval`, `mint`, `script_data_hash`, `collateral`, `required_signers`, `network_id`, `collateral_return`, `total_collateral`, `reference_inputs`, `voting_procedures`, `voting_proposals`, `donation`, `current_treasury_value`.
- The `witness_set` fields MUST appear in Conway CDDL order: `vkeys`, `native_scripts`, `bootstraps`, `plutus_scripts`, `plutus_data`, `redeemers`.
- `inputs`, `collateral`, and `reference_inputs` MUST render as distinct body fields and MUST NOT be merged into a single input section.
- Absent CDDL fields MUST render explicitly as `NULL`.
- `fee` MUST render only as the body field, with no duplicate top-level Fee section.
- `ttl`, `withdrawals`, `required_signers`, `is_valid`, and `auxiliary_data.metadata` MUST be visible when present in the transaction structure, with metadata expanded beyond a collapsed label count.
- Existing books, CURIE annotation, validation, graph, and layout behavior MUST continue to pass.

## Acceptance

- A hermetic automated parity test globs every `/code/amaru-treasury-tx/transactions/2026/**/signed-tx.hex` fixture, asserts the corpus is non-empty, key-walks each top-level Conway transaction CBOR without new dependencies, maps body and witness-set integer keys through the Conway CDDL table, and fails on any missing, merged, duplicated, or mis-ordered Structure field.
- The same test includes an exact field-set and order golden for the `18d57a4f...` contingency transaction matching the captured CQuisitor tree in `/tmp/ux121/faithful-decode-spec.md`.
- The parity test is observed RED against the current lossy decode, then GREEN after the Structure implementation.
- `nix build .#packages.x86_64-linux.tx-inspector-ui`, `just test-playwright`, `just format-check`, and `just hlint` pass before the draft PR is left for epic-owner re-verification.

## Non-Goals

- No layout polish.
- No history view.
- No deduplication beyond removing the duplicate Fee row required by this ticket.
- No production deploy or merge.
