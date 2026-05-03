# Protocol registry

Vendored CIP-57 Plutus blueprints and deployment registries that let the
inspector identify on-chain script hashes and decode their datums against
typed schemas.

The registry is **bundled into `apps/tx-deep-diagnosis`** at build time
via cabal `data-files`, so the CLI loads these labels by default with
no `--registry` flag. Pass `--registry DIR` (repeatable) on the
command line to layer additional protocol identifications on top
without losing the bundled defaults; pass `--no-bundled-registry` to
skip the bundle entirely (rare; meant for testing a clean
replacement).

The decoder primitive that consumes the typed schemas inside each
`plutus.json` is tracked in
[issue #35](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/35);
the SundaeSwap V3 wiring in
[issue #36](https://github.com/lambdasistemi/cardano-ledger-inspector/issues/36).

## Layout

```
registry.json                                  index — see #35 for the schema
sundaeswap-v3/
  plutus.json                                  CIP-57 blueprint, unparameterized validators
  pin.json                                     upstream source + ref
sundaeswap-treasury-v3/
  plutus.json                                  CIP-57 blueprint, parameterized validators
  pin.json                                     upstream source + ref
amaru-treasury/
  journal-2026.json                            deployment registry — applied script hashes,
                                               owners, addresses, deployment outrefs
  pin.json                                     upstream source + ref
WORKED-EXAMPLE.md                              hand-decode of issue #31's fixture using the
                                               three sources above
```

## Three sources, three roles

| File | Source | Role |
|---|---|---|
| `sundaeswap-v3/plutus.json` | `SundaeSwap-finance/sundae-contracts` | Unparameterized validator hashes match on-chain directly. |
| `sundaeswap-treasury-v3/plutus.json` | `SundaeSwap-finance/treasury-contracts` | Template hashes only; on-chain instances are parameterized. |
| `amaru-treasury/journal-2026.json` | `pragma-org/amaru-treasury` | Maps applied (parameterized) hashes to scope names, owners, addresses, deployment outrefs. |

## Refreshing

Each `pin.json` carries the upstream `ref` and a `refresh_command`. The
intent is that updating a pinned blueprint is a vendor + commit operation,
never a code change.
