# Plan

## Context

#98 introduced the MD3 shell, topbar routes, theme handling, and subpath-safe
routing. `/settings` and `/library` are placeholders. The provider controls
are still rendered inside `docs/inspector/src/Main.purs` as
`renderProvider`, and Playwright still expects `.provider-panel` on
`/inspect`.

## Implementation

Use one vertical slice because this ticket is a single UI behavior move:

- Keep settings state in the existing Halogen root component so route changes
  do not remount or lose memory-only credentials.
- Load `provider`, `network`, `persist_api_keys`, and persisted credentials at
  startup. Read credentials from localStorage only when persistence is enabled.
- Render the provider/key/network/persist form only on `/settings`.
- Render `/inspect` as a full-width input/results workspace with a compact
  settings summary and Settings link.
- Keep `/library` as a placeholder.
- Update shell/intro/footer copy so the product is framed as a general Cardano
  transaction inspector instead of a Haskell/WASI showcase.
- Adjust CSS grid rules for the full-width inspect layout and the settings
  form.
- Update Playwright assertions for the moved settings form and extend the
  existing subpath test to deep-link and refresh all three routes.

## Owned Files

- `docs/inspector/src/Main.purs`
- `docs/inspector/src/Shell.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

## Verification

- `./gate.sh`
- Manual smoke after build: serve `result/` under a non-root subpath and check
  `/inspect`, `/settings`, `/library` direct loads, navigation, refresh, and
  decode.
- Final preview smoke on `preview.dev.plutimus.com` before `COMPLETE`.

## Risks

- Provider credentials may be accidentally persisted when the toggle is off.
  The handler must continue clearing stored API keys when persistence is
  disabled.
- Network persistence is newly required by #100; use the `network` key without
  renaming existing provider keys.
- The settings form must not become a second source of truth; `/inspect` must
  decode from the same state edited on `/settings`.
