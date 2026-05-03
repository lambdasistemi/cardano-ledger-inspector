# Data Model: tx.intent Withdrawal Detail

## Intent Withdrawal Row

One structured element of `result.intent.withdrawals[]`.

| Field | Type | Notes |
|---|---|---|
| `index` | integer | Stable ordinal used by the renderer and rewarding redeemer targets |
| `reward_account_hex` | string | Serialized reward account bytes encoded as lowercase hex |
| `network` | string | `mainnet` or `testnet` |
| `credential.kind` | string | `key` or `script` |
| `credential.hash` | string | Staking credential hash in lowercase hex |
| `amount_lovelace` | string | Withdrawal amount in lovelace |

## Report Projection

The markdown renderer projects each withdrawal row to:

| Column | Source |
|---|---|
| `#` | `withdrawals[].index` |
| `Reward account` | `network`, `credential`, and truncated `reward_account_hex` |
| `Amount` | `amount_lovelace`, formatted as ADA |

## Compatibility Rule

If `result.intent.withdrawals` is absent, the renderer behaves as if the array
were empty.
