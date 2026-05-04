# Data Model: Formalize tx.intent Output Rows and Asset Detail

## Intent Output Row

- `index`: output index in transaction order
- `bucket`: signer/control bucket label already used by the value summary
- `address_hex`: serialized output address
- `coin_lovelace`: lovelace amount for this exact output
- `assets`: nested policy-id → asset-name → quantity map
- `datum`: datum state (`no_datum`, `datum_hash`, or `inline_datum`)

## Asset Preview

- `empty`: render `—`
- `single asset`: render one compact `policy.asset = qty` preview
- `multiple assets`: render a deterministic comma-separated preview in sorted
  order

The preview is purely for report readability. The JSON contract remains the raw
`assets` object.
