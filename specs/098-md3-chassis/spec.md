# Issue 98 Spec: MD3 Chassis For Inspector SPA

## User Story

As a Cardano user inspecting transaction CBOR in the browser, I want the
existing inspector to sit inside the shared Material Design 3 shell used by the
reference frontend, so the tool feels like a modern general-purpose transaction
inspector without changing any decode behavior.

## Scope

- Add a shared topbar and footer with general `cardano-ledger-inspector`
  branding and source/docs links for this repository.
- Add Material Design 3 system color tokens with light/dark theme support via a
  `data-theme` attribute on `<html>`.
- Load Material Web custom elements through a static `dist/material.js` script
  mirroring `/code/amaru-treasury-tx/frontend/dist/material.js`.
- Add a client-side routing skeleton with `/inspect`, `/settings`, and
  `/library`; only `/inspect` mounts the existing inspector workflow.
- Keep the provider panel, CBOR/hash input, overlay-book controls, decode flow,
  and all result panels functionally unchanged.

## Acceptance Criteria

- `nix build .#packages.x86_64-linux.tx-inspector-ui` builds clean locally.
- The packaged SPA renders under the Material shell with working topbar nav.
- The topbar theme toggle switches light/dark and persists through the
  `data-theme` attribute on `<html>`.
- `/inspect` runs the existing paste-CBOR-to-Decode flow and renders results.
- `/settings` and `/library` are empty placeholder routes only.
- Existing Playwright decode/regression coverage remains green.

## Non-Goals

- Do not move provider settings to `/settings`.
- Do not add the local book store, export/import, or remove bundled books.
- Do not restructure decoded results into tabs.
- Do not add lens explainers.
- Do not add a catalog backend.

## Reference

- `/code/amaru-treasury-tx/frontend/src/Shell.purs`
- `/code/amaru-treasury-tx/frontend/src/Theme.purs`
- `/code/amaru-treasury-tx/frontend/src/Routing.purs`
- `/code/amaru-treasury-tx/frontend/src/Main.purs`
- `/code/amaru-treasury-tx/frontend/dist/styles.css`
- `/code/amaru-treasury-tx/frontend/dist/material.js`
