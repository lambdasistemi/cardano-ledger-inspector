# Tasks

## Slice 1: Network-silent offline path

- [X] T0450 Make Paste CBOR the first-run default and add an explicit external-
  context opt-in that defaults off.
- [X] T0451 Keep pasted CBOR and every bundled example entirely local while
  external context is off; label offline example validation as structurally
  conformant and potentially ledger-incomplete.
- [X] T0452 Add hermetic Playwright request-ledger coverage proving zero
  Blockfrost/Koios requests for first-run paste and bundled examples, and adapt
  context-dependent journeys to opt in explicitly.

## Slice 2: Exact provider readiness and diagnostics

- [X] T0453 Remove Blockfrost-to-Koios fallback and require selected-provider
  readiness before hash fetch or external-context resolution makes a request.
- [X] T0454 Render inline provider readiness with a direct Settings action and
  ensure offline/online context labels name the source actually used.
- [X] T0455 Distinguish 401/403, 429, 5xx, network, and CORS failures beside the
  initiating action, then focus or scroll the error into view.
- [X] T0456 Add hermetic Playwright coverage for missing-credential silence,
  exact provider dispatch, no fallback, every failure category, and error
  focus/visibility.

## Follow-up: Empirical Koios browser boundary

- [X] T0460 Keep the inline Koios token gate while stating honestly that the
  deployed browser flow is CORS-blocked and a token does not remove the
  restriction.
- [X] T0461 Add focused readiness and CORS guidance assertions reflecting the
  empirical token/no-token live-browser finding.

## Follow-up: Disable unsupported Koios browser provider

- [X] T0462 Remove Koios as a selectable/usable browser provider, migrate
  legacy Koios browser state to Blockfrost readiness, and state that Koios is
  unsupported because its responses omit the required CORS headers.
- [X] T0463 Replace browser-success assumptions for Koios with hermetic
  coverage for disabled/nonactionable Koios, legacy-state fail-safe behavior,
  Blockfrost-only dispatch, and retained non-browser Koios adapter contracts.

## Orchestrator Finalization

- [X] T0457 Run the inherited `./gate.sh` and full
  `nix develop --quiet -c just ci` at final HEAD.
- [X] T0458 Record a real preview-browser network transcript for explicit
  Blockfrost with no cross-provider requests, the disabled Koios browser UI,
  and the empirical Koios token/no-token diagnostic proving that token
  presence changes authentication status but does not supply the missing CORS
  response header. No valid Koios bearer transcript is required by A-002.
- [X] T0459 Audit the issue checklist and PR body, and verify `gate.sh` remains
  byte-identical to `origin/main` before marking ready.

## Commit Contracts

Slice 1:

```text
fix(inspector): make local decode offline by default

Tasks: T0450, T0451, T0452
```

Slice 2:

```text
fix(inspector): make provider dispatch explicit

Tasks: T0453, T0454, T0455, T0456
```

Koios browser support correction:

```text
fix(inspector): disable unsupported Koios browser provider

Tasks: T0462, T0463
```

The ticket orchestrator marks each accepted implementation task complete by
amending the reviewed slice commit before pushing it. T0457-T0459 are
orchestrator-owned finalization tasks and do not authorize implementation edits.
