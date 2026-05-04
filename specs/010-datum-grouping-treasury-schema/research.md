# Research: Datum Grouping and Explicit Amaru Treasury Schema

## Findings

1. `Render.Summary.groupByCbor` currently groups only by `ddCbor`, so the
   representative output can leak both destination label and schema across
   unrelated destinations that happen to share identical datum bytes.
2. In the committed SundaeSwap/USDM fixture, output `#0` (Amaru treasury
   change) and the SundaeSwap order outputs share identical inline datum bytes.
   The current renderer therefore shows the treasury output inside the order
   block.
3. The issue body's wording about order outputs `#1-#9` being identical is
   slightly too broad. In the committed fixture, outputs `#1-#8` share one
   inline datum body, while output `#9` has different bytes near the tail and
   therefore remains its own order block even after the grouping fix.
4. The registry layer already supports instance-level datum schemas via
   `riDatumSchema`, and the renderer already supports `manual` schema
   provenance through `SourceManual`.
5. The pinned upstream `SundaeSwap-finance/treasury-contracts` source at
   `dea9e52671f7a696f0ec6a0f475c7fbe52689c9b` does not define a typed treasury
   datum for `treasury.treasury.spend`; the validator treats the datum as
   opaque `Data`.
6. The fixture's treasury change datum is still order-shaped. That makes an
   explicit instance-level manual schema the truthful way to keep the output
   typed without pretending the upstream treasury validator supplied those field
   names.

## Decision

Implement the issue in two parts:

- change datum grouping to `(ddCbor, ddDestination)`
- vendor a manual datum schema on the Amaru treasury instance that reuses the
  observed order-shaped field structure but carries explicit “manual analysis,
  no upstream typed source” provenance

This preserves the useful typed rendering while making the provenance auditable
and preventing grouping order from smuggling the SundaeSwap order schema onto
the treasury change output.
