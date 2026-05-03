# Feature Specification: tx.intent Withdrawal Detail

**Feature Branch**: `feat/txintent-information-audit-fields-decoded-by-the-l`
**Created**: 2026-05-03
**Status**: Draft
**Input**: GitHub issue #57: "tx.intent: information audit — fields decoded by the ledger but dropped from the envelope", scoped to the highest-value remaining withdrawal gap on current `main`

## User Scenarios & Testing

### User Story 1 - See Which Reward Account Is Withdrawing (Priority: P1)

An API consumer calls `tx.intent` and can see each withdrawal as structured
data instead of only a `withdrawal_count`.

**Why this priority**: A withdrawal is a real value flow. Count-only output is
not enough to tell whether the transaction is withdrawing rewards, treasury,
or a zero-coin script trigger.

**Independent Test**: Run the existing `tx-intent-smoke` fixture through
`tx.intent` and verify the result contains a structured `withdrawals[]` array,
then render the committed SundaeSwap diagnosis fixture and verify the report
shows the non-empty withdrawal row.

**Acceptance Scenarios**:

1. **Given** a transaction body with one or more withdrawals, **When**
   `tx.intent` runs, **Then** the response includes one structured row per
   withdrawal with a stable index, reward-account identity, and amount.
2. **Given** a transaction body with no withdrawals, **When** `tx.intent` runs,
   **Then** the response still decodes successfully and emits an empty
   withdrawals list rather than omitting the field.

### User Story 2 - Read Withdrawals in the Explain Report (Priority: P2)

A report reader can see which reward account is being withdrawn from and how
much, without inferring it from a redeemer count or raw CBOR.

**Why this priority**: The explain report already shows script calls and
per-output detail. Leaving withdrawals as a blank count hides a material part
of the transaction's value movement.

**Independent Test**: Render the committed golden diagnosis case and verify the
markdown includes a dedicated withdrawals section plus a more specific
rewarding-script target when the corresponding withdrawal exists.

**Acceptance Scenarios**:

1. **Given** a `tx.intent` payload with structured withdrawals, **When**
   `summary.md` and `explain.md` are rendered, **Then** they include a
   `Withdrawals` section with reward account and amount columns.
2. **Given** a rewarding redeemer whose index matches a structured withdrawal,
   **When** the script-call table is rendered, **Then** the target text points
   at that withdrawal row rather than only saying `rewarding #<n>`.

### Edge Cases

- Reward-account identity must remain deterministic even though withdrawals are
  map-backed in the ledger body.
- Zero-coin withdrawals must still be shown because they often exist only to
  trigger a script path.
- The renderer must tolerate missing `withdrawals[]` data in older stored
  diagnosis envelopes without crashing.

## Requirements

### Functional Requirements

- **FR-001**: `tx.intent` MUST emit a top-level `withdrawals` array.
- **FR-002**: Each `withdrawals[]` item MUST include a stable `index`,
  `reward_account_hex`, `network`, credential identity, and `amount_lovelace`.
- **FR-003**: `tx.intent` MUST emit `withdrawals: []` when no withdrawals are
  present.
- **FR-004**: The `tx.intent` schema, human contract documentation, and OpenAPI
  example MUST document the new `withdrawals[]` shape in the same PR.
- **FR-005**: The explain renderer MUST include a `Withdrawals` section when
  structured withdrawals are present.
- **FR-006**: The smart-contract call table MUST use structured withdrawal
  detail to refine rewarding-target text when possible.
- **FR-007**: Existing stored diagnosis envelopes without `withdrawals[]` MUST
  still render successfully.

### Key Entities

- **Intent Withdrawal Row**: One structured view of a reward-account withdrawal
  emitted by `tx.intent`.
- **Reward Account Identity**: The reward account's serialized hex plus its
  network and staking credential identity.
- **Withdrawal Report Section**: The markdown table in `summary.md` /
  `explain.md` that exposes structured withdrawals to readers.

## Success Criteria

### Measurable Outcomes

- **SC-001**: `tx-intent-smoke` asserts that `result.intent.withdrawals` is
  always present as an array, even on fixtures with zero withdrawals.
- **SC-002**: The committed golden `summary.md` and `explain.md` snapshots show
  a dedicated withdrawals section with the fixture's withdrawal amount.
- **SC-003**: The renderer continues to pass the existing snapshot harness for
  older fields while adding the new section deterministically.
- **SC-004**: The contract schema and generated OpenAPI stay byte-identical to
  the committed versions after regeneration.

## Assumptions

- This branch is a focused slice of issue #57, not the entire information
  audit inventory.
- The first withdrawal-detail slice is reward-account oriented; it does not
  attempt off-chain naming or on-chain-state verification.
- Reward account hex is an acceptable machine-readable address form for the
  contract and report in this phase.
