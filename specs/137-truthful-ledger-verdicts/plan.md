# Plan

## Context

`FFI.Json.normalizeValidation` currently converts the canonical verdict fields
into metric display strings. `renderValidationVerdictBanner` then treats a
successfully normalized validation response plus SHACL conformance as one
boolean and combines ledger and SHACL row counts. This can make the browser
assert a green ledger result without proving all three ledger-success fields.

## Design

Introduce a small pure verdict mapping with explicit ledger and SHACL input
states. Its output is structured tone/title/detail data; no presentation tone
is inferred from a rendered label. Normalization retains the ledger fields and
the mapped ledger verdict. SHACL gets a separately rendered structured verdict
from its report/error state. Ledger filters and tally report ledger evidence
only.

The dependency-free `lean/` Lake project models the same state mapping:
four ledger statuses crossed with SHACL pass/fail/error. It proves that a
green ledger tone entails the complete valid ledger triple and that changing
SHACL state cannot change ledger tone. A hermetic pure JavaScript matrix imports
the same mapping used by browser normalization; Playwright then proves the
separate rendered axes and the provider/missing-context journeys.

## Slice 1: Formal, normalized verdict contract

Owned files:

- `docs/inspector/src/FFI/ValidationVerdict.mjs`
- `docs/inspector/src/FFI/Json.js`
- `docs/inspector/src/FFI/Json.purs`
- `docs/inspector/tests/tx-identify.spec.mjs`
- `lean/lakefile.lean`
- `lean/lean-toolchain`
- `lean/ValidationVerdict.lean`
- `lean/.gitignore`

Implementation shape:

- Define a pure, total ledger mapping over the four canonical statuses and
  explicit `complete` / `valid_for_supplied_context` evidence, plus a separate
  pure SHACL pass/fail/error mapping.
- Preserve the source ledger fields and explicit row tones in the normalized
  browser records. Normalized `valid` means the response decoded, never that
  the ledger passed.
- Add the 4 × 3 hermetic matrix as pure implementation tests importing the
  mapping used by normalization.
- Create the focused Lean model and prove the green precondition and
  SHACL-independence theorems without `sorry` or declared axioms.

## Slice 2: Independent browser presentation and journeys

Owned files:

- `docs/inspector/src/Main.purs`
- `docs/inspector/src/FFI/Json.js`
- `docs/inspector/src/FFI/Json.purs`
- `docs/inspector/tests/tx-identify.spec.mjs`

Implementation shape:

- Render ledger and SHACL verdict banners independently, using their structured
  verdict/severity values. Keep `invalid` and `rejected` visibly distinct.
- Add validation-specific structured metric tones at the FFI boundary and make
  `Main.purs` consume them, removing the remaining validation metric/row tone
  inference from rendered text.
- Make the ledger filter tally ledger-only; retain SHACL findings in the SHACL
  panel without allowing them to determine ledger success.
- Exercise the rendered status × SHACL matrix through hermetic operation/SHACL
  test doubles, including missing context and provider error paths. Preserve
  the existing valid and broken example journeys.

## Verification

- RED/GREEN for slice 1: run the pure verdict matrix and the standalone
  `lake build`; inspect `#print axioms` output and confirm no `sorry` or
  custom `axiom` declaration occurs.
- RED/GREEN for slice 2: run the focused Playwright truthful-verdict tests on
  an isolated `PLAYWRIGHT_PORT` if 4173 is occupied, then run `./gate.sh`.
- Final: run `nix develop --quiet -c just ci`, followed by the valid and broken
  example journeys. Confirm `gate.sh` remains byte-identical to `origin/main`.
