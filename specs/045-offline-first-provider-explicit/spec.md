# Issue 45: Offline-first, provider-explicit Inspector

## P1 User Story

As a first-time Inspector user, I paste or fetch a transaction and observe
either zero-setup local success or an explicit provider requirement/error,
never a silent provider switch.

## Architectural Invariants

- Pasted CBOR and bundled examples decode locally with no Blockfrost or Koios
  request unless the user explicitly enables external context.
- The provider named by the UI is exactly the provider called. Offline results
  name their context source as offline and do not display a provider as used.
- Blockfrost never falls back to Koios. Missing credentials fail before any
  network request.
- Koios hash fetch and external-context resolution require a non-empty bearer
  token before a request. This is a readiness signal, not a promise that CORS
  will succeed.
- Provider responses remain byte/context inputs to Haskell/WASM. Browser
  adapters do not decode CBOR or decide ledger validity.
- The live browser smoke, rather than assumptions in UI copy, determines
  whether an authenticated provider is usable from the deployed preview.

## User Scenarios

### 1. Decode locally with zero setup

The initial Inspector view selects Paste CBOR. Pasting transaction CBOR or
choosing a bundled example runs local Haskell/WASM operations with empty
explicit context and makes no provider request. External context is off by
default. Offline validation remains truthful: a structurally conformant
example is labelled as such and may retain an incomplete ledger verdict.

### 2. Opt into external context

The user explicitly enables external context, sees the selected provider,
network, and readiness state, and can follow a direct Settings link when the
provider is not ready. Resolution invokes only that provider. Disabling
external context restores a network-silent local decode path.

### 3. Fetch by transaction hash

Fetch by hash is an explicitly online action. Its button is blocked inline
until the selected provider has the credential required by this browser
workflow. The inline state names the provider and links directly to Settings.
No attempted Blockfrost fetch can substitute Koios.

### 4. Recover from provider failures

The initiating control presents an actionable inline failure that distinguishes
authentication/authorization (401/403), rate limiting (429), provider 5xx,
network transport, and CORS. The failure receives focus or is scrolled into
view. A CORS failure is not described as repairable by adding credentials
unless the live-boundary smoke proves that claim.

## Functional Requirements

- The initial input mode is Paste CBOR, independent of persisted provider
  selection.
- External context is a separate, explicit opt-in state and defaults off on
  every first load.
- Local decode skips `Provider.resolveProducerTxContext` entirely while
  external context is off and passes `{}` as operation arguments.
- Fetch by hash always uses the selected provider and its configured network;
  it cannot invoke until that provider is ready.
- Both Blockfrost and Koios credential readiness is checked before a browser
  request. Credentials remain session-only unless the existing persistence
  opt-in is enabled.
- `Provider.fetchValidationContextEffect` dispatches Blockfrost to Blockfrost
  even when credentials are absent; absence is rejected by its caller before
  invocation. It never dispatches to Koios as a fallback.
- Provider boundary failures have stable categories that the Halogen UI maps
  to distinct, actionable inline messages.
- Offline loaded-context UI says no external provider was used. Online loaded-
  context UI names the exact provider used.
- Bundled examples explicitly say that their offline proof is structural and
  that ledger validation may be incomplete without supplied context.
- Hermetic Playwright coverage records all Blockfrost/Koios requests and proves
  network silence, exact dispatch, no fallback, readiness blocking, failure
  categories, and error focus/scroll behavior.
- The PR remains draft until a real preview-browser network transcript records
  explicit Koios and Blockfrost attempts and verifies that no other provider
  endpoint was called. Unsupported CORS is a failing finding to escalate.

## Acceptance Criteria

- [ ] Paste CBOR is the default first-run mode and succeeds without credentials.
- [ ] Bundled examples make zero Blockfrost/Koios requests unless external context is explicitly enabled.
- [ ] Hash Decode is disabled or blocked inline when the selected provider is not ready, with a direct Settings action.
- [ ] Selecting Blockfrost calls only Blockfrost; selecting Koios calls only Koios.
- [ ] 401/403, 429, 5xx, network, and CORS failures are visibly distinguished beside the initiating action.
- [ ] Fetch/decode errors receive focus or are scrolled into view and never appear only below the fold.
- [ ] At least one bundled complete-context fixture demonstrates a genuine offline green ledger validation, or the example is explicitly labelled structurally conformant/incomplete.
- [ ] Hermetic Playwright tests prove the zero-request and no-fallback invariants.
- [ ] Before leaving draft, the PR owner records a preview browser/network transcript for explicit Koios and Blockfrost calls; unsupported browser CORS fails the acceptance gate rather than being hidden.
- [ ] `nix develop --quiet -c just ci` passes.

## Clarification Record

- Q-001: require a non-empty Koios bearer token as the inline readiness gate.
  The mandatory live-boundary smoke must still test an authenticated Koios
  request. If it remains CORS-blocked, the UI must say the deployment is
  CORS-blocked and must not imply that entering a token fixes access.

## Non-Goals

- Persisting or encrypting credentials (#116).
- Proxy infrastructure or server-side transaction fetching.
- CLI provider error handling (#138).
- Changing Haskell/WASM ledger validation semantics.
- Editing RDF shapes, Lean models, or book/emitter behavior.
