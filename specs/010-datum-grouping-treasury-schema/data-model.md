# Data Model: Datum Grouping and Explicit Amaru Treasury Schema

## Datum Group Key

- `cbor_hex`: the exact inline datum bytes rendered in the output
- `destination_label`: the resolved destination label already used in datum
  block titles

Two outputs belong to the same rendered datum block only when both values are
equal.

## Decoded Datum

- `index`: output index in the tx intent view
- `destination`: resolved destination label
- `cbor`: inline datum hex
- `ast`: decoded Plutus Data tree
- `schema`: optional datum schema resolved from the payment script hash

## Treasury Instance Schema

- `scope`: the Amaru Network Compliance treasury instance
  (`32201dc1e82708364c6c42a53f89f675314bb9ad5da2734aa10baa0d`)
- `source`: `manual`
- `purpose`: make the treasury change output's observed commitment shape
  explicit at the instance level
- `fallback`: if the AST diverges from the vendored schema, the renderer keeps
  its existing untyped mismatch fallback
