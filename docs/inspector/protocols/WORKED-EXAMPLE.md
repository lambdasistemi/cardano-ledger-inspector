# Issue #31 fixture, fully decoded by hand

Reference for what the inspector should produce once issues
[#32](https://github.com/lambdasistemi/cardano-ledger-wasi/issues/32),
[#33](https://github.com/lambdasistemi/cardano-ledger-wasi/issues/33),
[#34](https://github.com/lambdasistemi/cardano-ledger-wasi/issues/34),
[#35](https://github.com/lambdasistemi/cardano-ledger-wasi/issues/35),
[#36](https://github.com/lambdasistemi/cardano-ledger-wasi/issues/36) and
[#37](https://github.com/lambdasistemi/cardano-ledger-wasi/issues/37) ship.

Fixture: `specs/001-ledger-functional-layer/fixtures/sundae-swap-usdm-disbursement.hex`
(the tx from [issue #31](https://github.com/lambdasistemi/cardano-ledger-wasi/issues/31)).

## Sources used

| Repo | Pinned commit | Role |
|---|---|---|
| [SundaeSwap-finance/sundae-contracts](https://github.com/SundaeSwap-finance/sundae-contracts) | `be33466b7dbe0f8e6c0e0f46ff23737897f45835` | Blueprint for `order.spend` (matches cluster B directly) |
| [SundaeSwap-finance/treasury-contracts](https://github.com/SundaeSwap-finance/treasury-contracts) | `dea9e52671f7a696f0ec6a0f475c7fbe52689c9b` (HEAD) and `ad4316d0d36cdef780f85fc2ec8b307e645ddc2a` (cited in the tx metadata) | Template blueprint for `treasury.treasury.spend` (parameterized) |
| [pragma-org/amaru-treasury](https://github.com/pragma-org/amaru-treasury) | `99600d8cedf0e3c4894fe7f45d5e8abad2289d76` | Deployment registry — `journal/2026/metadata.json` maps applied script hashes to scope names, owners, addresses, deployment outrefs |
| [KtorZ/aicone](https://github.com/KtorZ/aicone) | `a9ae9ef8b6bdb183ea020ea97f6b648f9343924e` | Provides `sundae/multisig/MultisigScript` used by the order datum |

## On-chain identity, fully resolved

### Cluster B — SundaeSwap V3 order outputs

Direct hash match against the unparameterized blueprint.

- Validator: `order.spend`, hash `fa6a58bbe2d0ff05534431c8e2f0ef2cbdc1602a8456e4b13c8f3077`.
- 9 outputs at this script, each ~12,503.28 ADA.
- Datum schema: `OrderDatum` from `lib/types/order.ak`.

### Cluster A — Amaru Network Compliance treasury

Hash not present in either Sundae blueprint as-is — it's the
`treasury.treasury.spend` template (`03d983a1…f6ed`) parameterized for the
Amaru **network_compliance** scope. Identification comes from the Amaru
treasury journal.

```
journal/2026/metadata.json → treasuries.network_compliance:
  owner               = 8bd03209d227956aaf9670751e0aa2057b51c1537a43f155b24fb1c1
  budget              = 1,450,000 ADA / period
  address             = addr1xyezq8wpaqnssdjvd3p220uf7e6nzjae44w6yu625y965rfjyqwur6p8pqmycmzz55lcnan4x99mnt2a5fe54ggt4gxs8thzgk
  treasury_script     = 32201dc1e82708364c6c42a53f89f675314bb9ad5da2734aa10baa0d   ← cluster A payment cred
                        deployed_at 810bfcbde85ae72f27d7e8cd154c03c802de15d3fa0dd83a32a4b0fdba330b3c#00
  permissions_script  = a64d1b9e1aeffe54056034d84977061b45a92691efc282fbee3fc094   ← tx withdrawal stake credential
                        deployed_at 25ba96f5deb14bb5c56e7542d6a9ba8450f52cc698ebd74574e1a0525d861095#02
  registry_script     = 38c627d45835744a2d6c727124f2b5852e5564aeab3f608e0e84ea6d
                        deployed_at e7b395a93d49a17994d66df0e4778a01dee05e7711e6612f28d97b63e4e6311c#02
```

### Cross-references (all byte-equal — no inference)

| Tx field | Bytes | Identified as |
|---|---|---|
| Required signer #1 | `8bd03209…4fb1c1` | network_compliance owner |
| Required signer #2 | `f3ab64b0…d23e2e` | ops_and_use_cases owner |
| Reference input #1 (outref) | `11ace24a7b…cf54#00` | scope_owners (Amaru shared) |
| Reference input #2 (outref) | `25ba96f5…1095#02` | network_compliance permissions_script |
| Reference input #3 (outref) | `810bfcbde…3b3c#00` | network_compliance treasury_script |
| Reference input #4 (outref) | `e7b395a9…311c#02` | network_compliance registry_script |
| Withdrawal stake credential | `f1 a64d1b9e…3fc094` | network_compliance permissions_script (zero-coin invocation handle) |
| Cluster A payment+stake | `32201dc1…baa0d` (self-staked) | network_compliance treasury_script |
| Order owner key #1 | `7095faf3…beffb` | core_development scope owner |
| Order owner key #2 | `f3ab64b0…d23e2e` | ops_and_use_cases scope owner |
| Order owner key #3 | `8bd03209…4fb1c1` | network_compliance scope owner |
| Order owner key #4 | `97e0f6d6…49df2` | middleware scope owner |
| Cluster C payment+stake | `dea7197a…2626d` / `bc1597ad…cc1369` | (vendor key, not in any registry — likely Antithesis) |

## Outputs

| # | Cluster | Address | ADA | Other | Datum |
|---|---|---|---|---|---|
| 1 | A | network_compliance treasury (`32201dc1…`) | 1,041,836.73 | dust USDM | Treasury Payout (commitment) |
| 2-9 | B | SundaeSwap V3 order (`fa6a58bb…`), staked to network_compliance | 8 × 12,503.28 = 100,026.24 | – | Standard order datum |
| 10 | B | same as 2-9 | 12,503.28 | – | Odd-leg order datum |
| 11 | C | key `dea7197a…/bc1597ad…` | 49,968.00 | – | none |
| 12 | C | same as 11 | 50,030.07 | – | none |

Total ADA across all outputs ≈ **1,254,365 ADA**. Fee 1.043795 ADA.

## OrderDatum — standard leg (8 of the 9 cluster B outputs + the cluster A template)

```json
{
  "pool_ident": "64f35d26b237ad58e099041bc14c687ea7fdc58969d7d5b66e2540ef",
  "owner": {
    "AnyOf": {
      "scripts": [
        { "Signature": { "key_hash": "7095faf3…beffb", "amaru_scope": "core_development" } },
        { "Signature": { "key_hash": "f3ab64b0…d23e2e", "amaru_scope": "ops_and_use_cases" } },
        { "Signature": { "key_hash": "8bd03209…4fb1c1", "amaru_scope": "network_compliance" } },
        { "Signature": { "key_hash": "97e0f6d6…49df2",  "amaru_scope": "middleware" } }
      ]
    }
  },
  "max_protocol_fee": 1280000,
  "destination": {
    "Fixed": {
      "address": {
        "payment_credential": { "ScriptCredential": "32201dc1…baa0d", "label": "network_compliance treasury" },
        "stake_credential":   { "Some": { "Inline": { "ScriptCredential": "32201dc1…baa0d" } } }
      },
      "datum": "NoDatum"
    }
  },
  "details": {
    "Swap": {
      "offer":        { "policy_id": "", "asset_name": "", "amount": 12500000000, "label": "12,500 ADA" },
      "min_received": {
        "policy_id":  "c48cbb3d5e57ed56e276bc45f99ab39abe94e6cd7ac39fb402da47ad",
        "asset_name": "0014df105553444d",
        "amount":     3062894752,
        "label":      "≥ 3,062.894752 USDM"
      }
    }
  },
  "extension": null
}
```

## OrderDatum — odd leg (1 of 10 datums)

Identical except for `details.Swap`:

```json
"details": {
  "Swap": {
    "offer":        { "policy_id": "", "asset_name": "", "amount": 8163265306, "label": "8,163.265306 ADA" },
    "min_received": {
      "policy_id":  "c48cbb3d…47ad", "asset_name": "0014df105553444d",
      "amount": 2000000000, "label": "≥ 2,000.000000 USDM"
    }
  }
}
```

## Aggregate swap commitment

| Quantity | Value |
|---|---|
| Total ADA offered | **108,163.265306 ADA** (8 × 12,500 + 1 × 8,163.27) |
| Min USDM received | **≥ 26,503.158016 USDM** (8 × 3,062.894752 + 1 × 2,000) |
| Effective rate | **0.245 USDM / ADA** — exact match to the metadata claim "$0.245 per ADA" |
| Max protocol fees total | 9 × 1.28 = **11.52 ADA** (rebatable on small batches) |
| USDM asset | `c48cbb3d…47ad / 0014df105553444d` (CIP-68 prefix `\x00\x14\xDF\x10` + ASCII "USDM") |

## Executive summary the inspector should display

```
Amaru Network Compliance treasury — disbursement (Conway tx 30723408…2a00f)

The Amaru Network Compliance treasury (script 32201dc1…baa0d, address
addr1xy…thzgk, ~1.04M ADA on-hand, 1.45M ADA annual budget) is doing two
things in this transaction:

  1. Creating 9 SundaeSwap V3 swap orders (script fa6a58bb…3077):
       sell  108,163 ADA
       buy   ≥ 26,503 USDM   at 0.245 USDM/ADA (matches metadata claim)
       max protocol fees    11.52 ADA
       proceeds returned to the same Network Compliance treasury
                            → SELF-ROUTED swap (no external recipient)
       cancellation         any of the 4 Amaru scope owners
                            (core_development, ops_and_use_cases,
                             network_compliance, middleware)

  2. Paying 99,998 ADA in two ~50k-ADA chunks to key address dea7197a…/bc1597ad…
     (not in any known registry — almost certainly the Antithesis vendor leg
      cited in the metadata).

Authorization: 2-of-2 by network_compliance (8bd03209…) and
               ops_and_use_cases (f3ab64b0…) scope owners.

Reference inputs all match Network Compliance's deployment outrefs:
  scope_owners            11ace24a…cf54#00
  permissions_script      25ba96f5…1095#02
  treasury_script         810bfcbde…3b3c#00
  registry_script         e7b395a9…311c#02

Withdrawal: zero-coin handle on permissions_script a64d1b9e…3fc094
(script invocation, no money flow).

Fee: 1.043795 ADA.
```

That single block answers all six bullets of issue #31's "What the Viewer
Should Explain" section, **derived deterministically from CBOR + three
vendored JSON files (sundae-contracts blueprint, treasury-contracts
blueprint, amaru-treasury journal)**, with no address book and no resolved
producer transactions required (resolved producers would only refine the
"net signer change" arithmetic — the identity work is complete from
reference data alone).
