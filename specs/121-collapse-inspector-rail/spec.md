# Issue #121: Collapse Inspector Rail After Decode

## User Story

As a transaction analyst using `/inspect`, I want the decoded structure to take over the page after a transaction is loaded, while keeping input, provider, and book controls reachable from a compact header, so I can inspect the transaction without a permanent half-width control rail crowding the tree.

## Functional Requirements

- FR1: When `state.result` is `Nothing`, `/inspect` MUST keep the current two-pane layout: settings summary, mode tabs, and books on the left; result placeholder on the right.
- FR2: When an error is present without a decoded result, `/inspect` MUST keep the current two-pane input layout so the user can correct the input in place.
- FR3: When `state.result` is `Just _`, `/inspect` MUST render a compact loaded-state header above the result and let the decoded structure/results span the full workspace width.
- FR4: The loaded-state header MUST show loaded transaction context: source/provider/network and a transaction id/hash when available.
- FR5: The loaded-state header MUST provide reachable controls to change input and to access/apply selected books without making the old rail permanently consume half the workspace.
- FR6: The change MUST be presentation-only: no ledger operation, provider resolution, transaction decode, book store, RDF, or validation logic changes.
- FR7: Narrow viewports MUST stack sensibly, with no overlapping text or inaccessible controls.

## Acceptance Criteria

- AC1: Empty `/inspect` still has visible `.workspace-left` and `.workspace-right` panes with approximately even desktop widths.
- AC2: After decoding `specs/001-ledger-functional-layer/fixtures/conway-mainnet-tx.hex`, the workspace switches to loaded mode, the old left rail is collapsed into a slim header, and the decoded result spans nearly the full workspace width.
- AC3: The loaded header exposes provider/network/source context, a transaction id/hash, an input-change affordance, and book context/access.
- AC4: Playwright asserts both the unchanged empty layout and the loaded full-width/collapsed layout, including subpath behavior.
- AC5: `nix build .#packages.x86_64-linux.tx-inspector-ui`, `just test-playwright`, `just format-check`, and `just hlint` pass.
- AC6: The draft PR preview is browser-smoked at `/lambdasistemi/cardano-ledger-inspector/pr-<N>/inspector/` with the Conway fixture and a screenshot of the loaded full-width state.

## Non-Goals

- No decode, provider, validation, RDF, witness, book-resolution, or WASM behavior changes.
- No dependency, lockfile, generated hash, or deployment workflow changes.
- Do not rename the product wordmark; it remains "Ledger Inspector".
