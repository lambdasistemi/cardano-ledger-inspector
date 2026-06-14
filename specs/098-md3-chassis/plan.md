# Issue 98 Plan: MD3 Chassis

## Current State

`docs/inspector/src/Main.purs` owns both app state and the full single-page
render tree. `docs/inspector/dist/index.html` contains the full visual system
as an inline `<style>` block. The Nix UI package currently installs only
`index.html` and `index.js`, so any new static `styles.css` or `material.js`
must be copied by `nix/wasm-ui.nix`.

## Target Shape

- `Theme.purs` / `Theme.js`: read, apply, persist, and toggle
  `html[data-theme]`.
- `Routing.purs` / `Routing.js`: map browser paths to
  `Inspect | Settings | Library`, with `/` falling back to `/inspect`.
- `Shell.purs`: shared topbar/footer, general inspector branding, source/docs
  links, nav links, and theme-toggle action.
- `Main.purs`: route dispatch and existing inspector component mounted inside
  the shell for `/inspect`; placeholders for `/settings` and `/library`.
- `dist/index.html`: no inline app CSS; links `styles.css`, loads
  `material.js`, keeps `index.js`.
- `dist/styles.css`: MD3 token system and inspector class styling using
  `--md-sys-color-*` variables.
- `dist/material.js`: static Material Web loader copied from the reference
  pattern and adjusted only if needed for this app.
- `nix/wasm-ui.nix`: install all required static assets.

## Slice A: Material Shell Foundation

Install the route/theme/shell foundation and update tests to make the routing
and theme requirements observable.

Owned files:

- `docs/inspector/src/Main.purs`
- `docs/inspector/src/Shell.purs`
- `docs/inspector/src/Theme.purs`
- `docs/inspector/src/Theme.js`
- `docs/inspector/src/Routing.purs`
- `docs/inspector/src/Routing.js`
- `docs/inspector/dist/index.html`
- `docs/inspector/dist/material.js`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`
- `nix/wasm-ui.nix`

Proof:

- RED: Playwright assertions for `/inspect`, `/settings`, `/library`, and the
  topbar theme toggle fail before implementation.
- GREEN: focused Playwright route/theme test passes.
- Gate: `./gate.sh`.

Commit subject:

`feat(inspector): add md3 shell foundation`

## Slice B: Inspector MD3 Reskin

Retain behavior and reshape the existing inspector surfaces under the MD3 token
system. This is CSS/markup styling only: provider controls remain on
`/inspect`, books remain bundled, and result panels remain in their current
flat order.

Owned files:

- `docs/inspector/src/Main.purs`
- `docs/inspector/src/Shell.purs`
- `docs/inspector/dist/styles.css`
- `docs/inspector/tests/tx-identify.spec.mjs`

Proof:

- RED: update/add Playwright checks that assert the decoded inspector still
  renders under the shell and remains within the viewport after decode.
- GREEN: focused Playwright visual/flow checks pass.
- Gate: `./gate.sh`.

Commit subject:

`feat(inspector): reskin inspect flow with md3 tokens`

## Final Verification

After both slices are accepted:

- Run `./gate.sh`.
- Run or verify `nix build .#packages.x86_64-linux.tx-inspector-ui`.
- Perform a browser smoke against the packaged UI: paste the committed Conway
  fixture CBOR, click Decode, and confirm a decoded result renders under the
  Material shell in light and dark modes.
- Update PR #99 with delivered behavior and evidence.
