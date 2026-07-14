# Plan

## Context

`renderInspector` already knows when a successful decoded transaction has a
loaded header. That header contains the selected-book summary plus the
Library and Apply selected books controls. It then currently renders the full
`Resolution books` card before the result panel, despite
`renderBooksPanel` already supporting a collapsed (omitted) presentation.
The CQuisitor helper presently encodes that duplicate-card layout.

## Design

Use the existing collapsed rendering path only for decoded loaded state. The
input screen continues rendering the full books panel, so empty and fetch
error states retain their existing corrective input and book controls.

Update the CQuisitor Playwright helper to treat the loaded header as the one
books control surface, assert that no `Resolution books` card appears after a
successful decode, and assert the result tabs plus `Decoded transaction`
heading fit in the first viewport at 1024×768 and 390×844. Keep existing
checks for Change input, Library, Apply selected books, re-decode, and the
prefixed `/inspect` route.

## Slice 1: Loaded hierarchy and visual regression

Owned files:

- `docs/inspector/src/Main.purs`
- `docs/inspector/tests/tx-identify.spec.mjs`

Implementation shape:

- Omit the full books card when `showLoadedHeader` is true, preserving the
  loaded header's compact summary and controls.
- Keep non-loaded `renderLoadForm` behavior unchanged.
- Replace the obsolete duplicate-card assertion with exact-one-surface and
  first-viewport assertions at the acceptance dimensions, retaining the
  control-flow coverage in the same CQuisitor scenario.

## Verification

- RED: run the focused CQuisitor Playwright test against the pre-change UI and
  observe its duplicate-card/viewport assertions fail.
- GREEN: run the focused test on an isolated `PLAYWRIGHT_PORT` if the shared
  default port is unavailable, then run `./gate.sh`.
- Final: run `nix develop --quiet -c just ci`; preserve the CQuisitor capture
  evidence in `WIP.md`.
