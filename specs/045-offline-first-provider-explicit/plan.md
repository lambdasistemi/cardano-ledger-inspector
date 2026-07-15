# Plan

## Context

The initial Halogen state currently selects Fetch by hash and Blockfrost. More
critically, every successful pasted-CBOR decode calls
`resolveProducerTxContext`; when Blockfrost lacks a key,
`fetchValidationContextEffect` silently calls Koios. The loaded header then
names the selected provider even when another provider was called. Provider
errors are rendered in a result card below the initiating form and transport
failures are reduced to browser exception strings.

## Design

Keep the deterministic ledger pipeline unchanged. Add explicit browser-shell
state for whether external context is enabled and make offline the default.
Local decode invokes the same Haskell/WASM operations with `{}` context and no
provider adapter call. Hash fetch and opted-in context resolution share one
provider-readiness function: both Blockfrost and Koios require their selected
credential before network access in this browser workflow.

The provider boundary returns stable failure categories for 401/403, 429, 5xx,
network transport, and CORS. Halogen renders category-specific inline guidance
beside the initiating action and moves focus/scroll to the alert. Because the
Fetch API deliberately hides CORS response detail, CORS classification must be
based only on observable adapter/provider behavior and the deployed-browser
smoke; copy must not claim that a token fixes CORS until that smoke proves it.

No provider response acquires ledger semantics: provider adapters continue to
return transaction CBOR and validation-context JSON which are passed as
explicit arguments into Haskell/WASM.

## Slice 1: Network-silent offline path

Owned files:

- `docs/inspector/src/Main.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

Implementation shape:

- Select Paste CBOR on first run and add external-context opt-in state that is
  off by default.
- Skip all provider resolution for pasted CBOR and examples while opt-in is
  off; use `{}` context for downstream ledger operations.
- Render offline versus exact-provider context truthfully in the settings
  summary and loaded header.
- Explicitly label bundled offline examples as structurally conformant with
  potentially incomplete ledger validation.
- Add RED/GREEN Playwright coverage with a strict provider-host request
  recorder proving first-run paste and every bundled example issue zero
  Blockfrost/Koios requests. Update existing journeys that intentionally need
  context to enable it explicitly.

Focused proof:

```text
PLAYWRIGHT_PORT=<isolated> nix develop --quiet -c sh -c 'cd docs/inspector && ... playwright test tests/tx-identify.spec.mjs --grep "offline|bundled examples" --reporter=list'
```

Commit contract:

```text
fix(inspector): make local decode offline by default

Tasks: T0450, T0451, T0452
```

## Slice 2: Exact provider readiness and diagnostics

Owned files:

- `docs/inspector/src/Main.purs`
- `docs/inspector/src/Provider.purs`
- `docs/inspector/src/Provider.js`
- `docs/inspector/src/FFI/Blockfrost.js`
- `docs/inspector/src/FFI/Koios.js`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

Implementation shape:

- Remove Blockfrost-to-Koios validation-context fallback and centralize
  credential/readiness checks for both providers.
- Block hash fetch and opted-in external context inline until the selected
  provider is ready, with a direct Settings action.
- Ensure provider labels are derived from the dispatched provider, not from an
  unrelated persisted/default selection.
- Categorize 401/403, 429, 5xx, network, and CORS failures at the provider
  boundary; render distinct actionable messages next to the action and focus
  or scroll the alert into view.
- Add RED/GREEN Playwright coverage that treats any request to the non-selected
  provider as a failure, proves missing credentials make no request, exercises
  both exact provider paths, and covers every required failure class.

Focused proof:

```text
PLAYWRIGHT_PORT=<isolated> nix develop --quiet -c sh -c 'cd docs/inspector && ... playwright test tests/tx-identify.spec.mjs --grep "provider|401|403|429|5xx|network|CORS" --reporter=list'
```

Commit contract:

```text
fix(inspector): make provider dispatch explicit

Tasks: T0453, T0454, T0455, T0456
```

## Orchestrator Finalization: Live boundary and full gate

The external boundary cannot be proven by hermetic request interception. After
both slices land, the ticket owner runs the packaged UI in a real preview
browser context, explicitly selects Koios and Blockfrost, and records request
method/URL/provider plus browser outcome. The transcript must show no request
to the non-selected provider. Authenticated Koios must be attempted. If either
provider is CORS-blocked in that deployment, record and escalate it; the PR
stays draft and the UI message is corrected before another smoke.

Because this smoke requires credentials/network access, it is a named operator
follow-up rather than a hermetic `gate.sh` command. The existing shared
`gate.sh` is inherited from `origin/main` and must remain byte-identical.

Final proof:

- `./gate.sh`
- `nix develop --quiet -c just ci`
- preview browser/network transcript for authenticated Koios and explicit
  Blockfrost, including the absence of cross-provider requests
- `sha256sum gate.sh` matching `git show origin/main:gate.sh | sha256sum`

## Boundary Review Question

What system boundary does the unit suite not exercise? The deployed browser's
actual fetch/CORS policy against Koios and Blockfrost. The mandatory transcript
is therefore merge-blocking evidence, not an optional manual check.
