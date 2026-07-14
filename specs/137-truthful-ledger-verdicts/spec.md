# Issue 137: Render truthful ledger validation verdicts

## P1 User Story

As a transaction analyst, I inspect validation and observe a verdict that
faithfully distinguishes valid, invalid, incomplete, and rejected results.

## Invariant

The browser has two independent validation axes:

1. Ledger validation, whose canonical result is the structured triple
   `(status, complete, valid_for_supplied_context)`.
2. RDF SHACL/book conformance, whose structured result is pass, fail, or
   evaluation error.

The ledger banner is green exactly when `status = valid`, `complete = true`,
and `valid_for_supplied_context = true`. SHACL conformance and any tally of
SHACL findings cannot alter that ledger verdict. Missing ledger context is an
amber warning: it neither invents a ledger failure nor qualifies as a pass.

## Requirements

- The canonical ledger states remain `valid`, `invalid`, `incomplete`, and
  `rejected` from the Haskell/WASM contract.
- Browser normalization retains ledger status, completeness, and supplied-
  context validity as structured fields, rather than relying on display text.
- Ledger verdict and SHACL/book-conformance verdict are independently
  presented and independently toned from structured status/severity fields.
- The ledger summary/filter tally counts ledger findings only. It must not
  combine SHACL findings into evidence for a ledger verdict.
- `valid` without the required complete/context-valid evidence is conservative
  (not green) and is surfaced as inconsistent evidence.
- `incomplete` remains a warning even if all reported checks pass.
- `invalid` and `rejected` have distinct red headings and retain actionable
  ledger failures or context/provider errors.
- Provider errors render as failures; unresolved/missing context renders as a
  warning. Neither may obtain a green ledger pass badge.
- The focused formal model defines the four ledger states and three SHACL
  states, proves that green ledger tone implies the complete valid ledger
  triple, and proves that the ledger tone is independent of SHACL state.

## Acceptance Criteria

- [ ] A complete valid result renders a green ledger verdict.
- [ ] An incomplete result renders an amber not-fully-evaluated verdict even when every evaluated check passed.
- [ ] Invalid and rejected results render distinct red outcomes with actionable detail.
- [ ] Failures and missing context may coexist without inventing a final valid/invalid decision.
- [ ] Provider errors render as failures and unresolved/missing context renders as warnings; neither receives a green pass badge.
- [ ] SHACL conformance is shown separately from ledger status and combined tallies cannot produce a false green verdict.
- [ ] A hermetic test matrix covers all four ledger statuses crossed with SHACL pass/fail/error.
- [ ] A small no-`sorry`, no-custom-axiom Lean model proves the green-verdict invariant and its state mapping is mirrored by pure implementation tests.
- [ ] `nix develop --quiet -c just ci` and the broken/valid example journeys pass.

## Non-Goals

- Changing Conway ledger validation semantics.
- Treating missing context as a ledger failure.
- Fetching additional chain data.
- Redesigning unrelated Structure, Witness, or Graph tabs.
