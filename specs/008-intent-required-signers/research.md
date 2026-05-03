# Research: tx.intent Required Signer Coverage

## Findings

- `tx.witness.plan` already emits `required_signers`,
  `present_vkey_witnesses`, and `present_bootstrap_witnesses`; `tx.intent`
  computes the same counts but currently drops those arrays.
- `tx.intent.sections` already feeds the generic markdown section renderer, so
  adding one more signer coverage table there avoids bespoke renderer logic.
- The current SundaeSwap diagnosis fixture already contains two declared
  required signers and zero present witnesses, so it exercises the non-empty
  missing case without needing a new transaction fixture.
- The `tx-intent` schema currently treats `signing` as an open object; this
  branch can make the signer arrays explicit in the contract.

## Rejected Alternatives

- **Renderer-only join against `tx.witness.plan`**: rejected because the issue
  is specifically about fields missing from `tx.intent`.
- **Only expose `required_signers[]` without witness arrays**: rejected because
  the reader still would not know whether each signer is already satisfied.
- **Replace the existing `Missing required signers` section**: rejected because
  that table still usefully highlights the failure-specific subset.
