# Data Model: tx.intent Required Signer Coverage

## Signer Reference

Used for present witness lists.

| Field | Type | Notes |
|---|---|---|
| `hash` | string | Signer hash in lowercase hex |
| `source` | string | `tx_body.required_signers`, `witness_set.vkey`, or `witness_set.bootstrap` |

## Required Signer Row

One element of `result.intent.signing.required_signers[]`.

| Field | Type | Notes |
|---|---|---|
| `hash` | string | Declared required signer hash |
| `source` | string | Always `tx_body.required_signers` |
| `witness_status` | string | `present_vkey`, `present_bootstrap`, or `missing` |

## Report Projection

The markdown report projects each required signer row to:

| Column | Source |
|---|---|
| `Label` | fixed text describing a declared required signer |
| `Value` | `required_signers[].hash` |
| `Detail` | human-readable witness coverage from `witness_status` |

## Compatibility Rule

If the new signer arrays are absent in an older diagnosis envelope, the
renderer behaves as if they were empty and omits the new section.
