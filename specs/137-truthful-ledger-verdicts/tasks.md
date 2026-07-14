# Tasks

## Slice 1: Formal, normalized verdict contract

- [X] T1370 Define total, structured ledger and SHACL verdict mappings that
  cannot emit green without the complete valid ledger triple.
- [X] T1371 Preserve canonical ledger verdict fields and structured tones in
  browser normalization; stop deriving validation-row tone from rendered
  metric/label text.
- [X] T1372 Add the hermetic 4 ledger-status × 3 SHACL-state pure matrix and
  a no-`sorry`, no-custom-axiom Lean model proving the green invariant and
  SHACL independence.

## Slice 2: Independent browser presentation and journeys

- [X] T1373 Render a ledger-specific structured verdict and a separate SHACL
  verdict, with distinct red invalid/rejected outcomes and actionable detail.
- [X] T1374 Add structured validation metric tones at the normalization
  boundary, then restrict ledger tally/filter evidence to ledger findings while
  retaining missing context as a warning and provider/context errors as
  failures.
- [X] T1375 Add hermetic Playwright coverage for every ledger-status × SHACL
  pass/fail/error combination plus valid and broken example journeys.

## Commit Contracts

Slice 1:

```text
fix(inspector): normalize ledger verdict contract

Tasks: T1370, T1371, T1372
```

Slice 2:

```text
fix(inspector): separate ledger and SHACL verdicts

Tasks: T1373, T1374, T1375
```

The ticket orchestrator will mark each accepted slice's tasks complete by
amending the reviewed commit before pushing it.
