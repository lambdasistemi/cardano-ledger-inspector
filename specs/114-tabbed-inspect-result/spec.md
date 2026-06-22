# Issue 114: Tabbed Inspect Result

## User Story

As a transaction inspector user, I want a decoded transaction result to open on a compact summary and the decoded structure tree, so I can inspect the transaction shape first without scrolling through every legacy diagnostic panel.

## Requirements

- The inspect result shows a top summary card with intent/title, fee, input/output counts, and warnings when available.
- The result uses tabs, with `Structure` as the default selected tab.
- The `Structure` tab contains the decoded-structure tree and is visible immediately after decoding a genuine Conway fixture.
- Legacy panels remain reachable through tabs instead of being stacked in one long page:
  - `Witness`: signing/intent summary and witness plan.
  - `Validation`: ledger validation and SHACL conformance.
  - `Graph / RDF`: transaction Turtle, selected books overlay, SPARQL lenses, transaction browser, and raw JSON.
- Conway identity is not rendered as a standalone full panel above the tree; its key facts are folded into the summary and the structure tree.
- The Books panel and active chain-data summary stay in the left pane.
- No transaction decoding, provider, book, resolution, validation, or route logic changes are in scope.

## Acceptance

- Decoding `specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex` lands on the summary and `Structure` tab by default.
- Playwright asserts the tab bar is present, `Structure` is selected by default, the decoded tree is visible, other legacy sections are reachable through their tabs, and document height stays below a small multiple of the viewport.
- Existing `/inspect`, `/settings`, and `/library` navigation works under a non-root preview subpath, including refresh and deep links.
- `nix build .#packages.x86_64-linux.tx-inspector-ui`, format/lint gates, and Playwright pass before the PR is marked complete.
