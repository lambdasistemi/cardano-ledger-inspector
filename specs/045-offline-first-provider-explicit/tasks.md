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

## Orchestrator Finalization

- [ ] T0457 Run the inherited `./gate.sh` and full
  `nix develop --quiet -c just ci` at final HEAD.
- [ ] T0458 Record a real preview-browser network transcript for authenticated
  Koios and explicit Blockfrost, proving no cross-provider request; escalate
  unsupported CORS and keep the PR draft until resolved.
- [ ] T0459 Audit the issue checklist and PR body, and verify `gate.sh` remains
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

The ticket orchestrator marks each accepted implementation task complete by
amending the reviewed slice commit before pushing it. T0457-T0459 are
orchestrator-owned finalization tasks and do not authorize implementation edits.
