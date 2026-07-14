# Issue 136: Restore decoded-result hierarchy after the loaded-screen redesign

## P1 User Story

As a transaction analyst, I decode a transaction and observe the Structure
result immediately below compact loaded context without a duplicated books
panel.

## Requirements

- `/inspect` remains a single-column vertical Material 3 workspace.
- The loaded header retains source, network, provider, transaction identity,
  Change input, Library, and Apply books controls.
- A decoded transaction renders exactly one books summary/control surface.
- The full Resolution books card is absent when the loaded header already
  exposes its controls.
- The result tabs and Structure heading are visible in the first viewport at
  1024×768 and 390×844.
- Empty and fetch-error states keep corrective input controls reachable.
- Change input, re-decode, Library, and Apply books continue to work.

## Acceptance

- `nix develop --quiet -c just ci` passes.
- The CQuisitor UX capture scenarios pass.
- Playwright coverage proves the loaded hierarchy at laptop and mobile widths.

## Non-Goals

- Redesigning the loaded header or books library.
- Changing decode, validation, provider, RDF, or book semantics.
- Returning to a two-pane layout.
