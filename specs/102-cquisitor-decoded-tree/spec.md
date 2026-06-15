# Issue 102 — CQuisitor Decoded Tree

## User Story

As a Cardano transaction inspector user, I want `/inspect` to behave like the
CQuisitor decoded transaction workspace: transaction input on the left and an
expandable, type-aware decoded structure on the right.

## Scope

- Load Material Symbols Outlined, Roboto Flex, and Roboto Mono in the
  inspector HTML shell so Material icons and typography render correctly.
- Replace the remaining hand-styled primary inspector controls with real
  Material Web `md-*` components where the bundled Material runtime supports
  them.
- Reshape `/inspect` into a two-pane workspace:
  left pane for transaction hash/CBOR input, active chain-data summary, and a
  placeholder books slot; right pane for decoded structure.
- Render the decoded structure as an expandable tree from SPARQL views over
  the existing `tx.rdf` Turtle graph.
- Keep opaque leaves raw for this child, while query rows include optional
  label/type hooks so later book-resolution triples can replace raw values.

## Non-Goals

- Do not implement book resolution.
- Do not add a local book store, export, or import flow beyond the existing
  overlay controls and a visible placeholder slot.
- Do not add byte-to-node highlighting.
- Do not add raw-CBOR mode.
- Do not add validation or Plutus script views beyond the existing panels.
- Do not change Haskell ledger operation semantics.

## Acceptance Criteria

- `/inspect` is a two-pane Material workspace on desktop and stacks cleanly on
  mobile.
- The theme button shows a Material Symbols icon instead of the literal
  `dark_mode` or `light_mode` text.
- Inspector typography uses Roboto Flex for UI text and Roboto Mono for code,
  preformatted data, CBOR input, and hashes.
- Pasting the committed Conway fixture renders a `Decoded structure` tree from
  SPARQL over the transaction RDF graph.
- Tree nodes expand and collapse, and nodes are labelled with semantic type
  plus value or count where available.
- The tree includes the transaction root plus body, inputs, outputs, mint,
  certificates, withdrawals, fee, validity, required signers, witnesses,
  redeemers, and metadata sections when present in the graph.
- Opaque leaves such as addresses, script hashes, policy ids, asset names, and
  datum values render raw for now.
- Playwright covers Material icon loading, the two-pane layout, decoded tree
  expand/collapse, and existing subpath deep-link plus refresh behavior for
  `/inspect`, `/settings`, and `/library`.
- `nix build .#packages.x86_64-linux.tx-inspector-ui`, `just ui-check`, and
  `just test-playwright` pass before completion.
