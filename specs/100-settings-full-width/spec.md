# Issue 100 — Settings Config And Full-Width Inspect

## User Story

As a transaction inspector user, I want chain-data provider settings to live
on a dedicated Settings page so the Inspect page can focus on transaction
input and decoded results.

## Scope

- Move provider, API key, network, and credential persistence controls from
  `/inspect` to `/settings`.
- Keep the existing localStorage keys:
  `blockfrost_project_id`, `koios_bearer_token`, `provider`, `network`, and
  `persist_api_keys`.
- Let `/inspect` read the shared settings state while `/settings` edits it.
- Show a compact `/inspect` affordance with the active network and provider
  plus a link to Settings.
- Reframe visible product copy as a general Cardano transaction inspector,
  with implementation technology de-emphasized.

## Non-Goals

- Do not add a local book store or export/import flow.
- Do not restructure decoded results into tabs.
- Do not add SPARQL lens explainers.
- Do not add a catalog backend.
- Do not change ledger operation semantics or provider API adapters.

## Acceptance Criteria

- `/inspect` has no chain-data configuration panel and uses the freed width for
  Input and Decoded JSON/results.
- `/settings` contains the provider, API key, network, persist toggle, and
  cleartext-storage warning.
- Changing provider, network, or keys on `/settings` affects hash decode on
  `/inspect`.
- Persisted settings survive reload through the existing localStorage keys,
  including `network`.
- Decode by pasted CBOR still works end-to-end.
- Playwright covers moved settings, full-width inspect, and subpath navigation
  plus refresh for `/inspect`, `/settings`, and `/library`.
- `nix build .#packages.x86_64-linux.tx-inspector-ui`, `just ui-check`, and
  `just test-playwright` pass before completion.
