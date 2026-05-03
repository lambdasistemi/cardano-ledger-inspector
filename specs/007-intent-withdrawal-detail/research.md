# Research: tx.intent Withdrawal Detail

## Findings

- `tx.intent` already counts withdrawals via `withdrawalsCount`, but currently
  drops the per-withdrawal data from the response.
- The upstream ledger API exposes `serialiseRewardAccount`, so the branch can
  emit full reward-account bytes in a stable hex form instead of inventing a
  custom string encoding.
- `tx-deep-diagnosis` already renders `intent.scripts[]`; rewarding redeemers
  currently degrade to `rewarding #<n>`, so structured withdrawals can improve
  both the new section and the existing script table.
- The report snapshot harness is pure JSON-in / markdown-out, so the golden
  `input.json` must be updated explicitly when new intent fields are added.
- Contract surfaces that need synchronized updates are:
  `specs/001-ledger-functional-layer/schemas/tx-intent-result.schema.json`,
  `specs/001-ledger-functional-layer/contracts/ledger-functional-api.md`,
  `nix/ledger-functional-openapi.nix`, and the committed generated OpenAPI JSON.

## Rejected Alternatives

- **Credential-only rows**: rejected because the issue explicitly calls out
  withdrawal addresses plus amounts, and the ledger already exposes reward
  account serialization.
- **Renderer-only parsing of `effects[].detail`**: rejected because the issue is
  about dropped envelope fields, not string parsing.
- **Folding withdrawals into the existing effects table only**: rejected
  because readers need one row per withdrawal, not just a count or prose note.
