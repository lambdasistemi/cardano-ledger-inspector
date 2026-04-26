# Feature Specification: Transaction Validation Operation

**Feature Branch**: `002-tx-validate`

**Created**: 2026-04-26

**Status**: Draft

**Input**: User description: "Specify tx.validate ledger operation for validating a candidate Cardano transaction with explicit ledger context, structured validation results, and missing-context diagnostics. The operation receives current transaction CBOR on every call, uses explicit context only, may reuse producer transaction CBOR for referenced inputs, and excludes submission, signing, hidden workspace state, provider UTxO JSON, and stateful RPC."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Validate a Candidate Transaction (Priority: P1)

A user with a candidate transaction and the required ledger context can ask whether the transaction is valid for that context before taking any separate action such as signing, balancing, or submitting it.

**Why this priority**: Validation is the first useful ledger operation beyond inspection because it tells users whether the transaction they are editing can satisfy ledger rules.

**Independent Test**: Can be tested by providing a candidate transaction plus complete explicit context and verifying that the result clearly reports valid or invalid, including the checks that were evaluated.

**Acceptance Scenarios**:

1. **Given** a well-formed candidate transaction and complete explicit context, **When** the user requests validation, **Then** the result reports that the transaction is valid for the supplied context and lists the evaluated check groups.
2. **Given** a well-formed candidate transaction with a ledger-rule failure and complete explicit context, **When** the user requests validation, **Then** the result reports that the transaction is invalid and includes the failing rule group, the affected transaction area, and a user-readable explanation.
3. **Given** the same candidate transaction and same explicit context, **When** validation is requested repeatedly, **Then** the result is the same each time and does not depend on prior calls.

---

### User Story 2 - Diagnose Missing Validation Context (Priority: P2)

A user can learn exactly which external ledger context is missing when a transaction cannot yet be fully validated.

**Why this priority**: A validation result that silently guesses context or returns a generic failure is not actionable. Users need to know what to fetch or supply next.

**Independent Test**: Can be tested by omitting required context from a validation request and verifying that the response distinguishes incomplete context from an invalid transaction.

**Acceptance Scenarios**:

1. **Given** a candidate transaction that spends inputs whose source outputs are not available, **When** the user requests validation, **Then** the result reports incomplete validation and identifies each unresolved transaction input.
2. **Given** a candidate transaction that requires time, protocol, or governance context that is not supplied, **When** the user requests validation, **Then** the result reports the missing context category without marking the transaction valid or invalid.
3. **Given** a candidate transaction with both missing context and locally detectable failures, **When** validation is requested, **Then** the result reports all failures that can be evaluated and separately lists the missing context that prevented complete validation.

---

### User Story 3 - Resolve Inputs From Producer Transactions (Priority: P3)

A user can provide the canonical bytes of transactions that produced the candidate transaction's inputs, allowing validation to use stable source-output evidence instead of provider-specific output snapshots.

**Why this priority**: Producer transactions are stable ledger evidence for transaction outputs and fit the transaction-document workflow better than mutable provider-specific UTxO objects.

**Independent Test**: Can be tested by validating a transaction whose inputs are resolvable from supplied producer transactions and by checking that mismatched producer evidence is rejected.

**Acceptance Scenarios**:

1. **Given** a candidate transaction that spends an input and the producer transaction for that input is supplied, **When** validation is requested, **Then** the referenced output is resolved from that producer transaction and used as validation context.
2. **Given** supplied producer transaction evidence whose transaction identifier or output index does not match the referenced input, **When** validation is requested, **Then** the result reports invalid context and does not use that evidence.
3. **Given** multiple supplied producer transactions for different inputs, **When** validation is requested, **Then** the result reports which inputs were resolved and which remain unresolved.

### Edge Cases

- Candidate transaction bytes are malformed, empty, truncated, or not a transaction.
- Candidate transaction is well formed but belongs to an era or network that conflicts with the supplied context.
- Referenced input points to a missing producer transaction, a missing output index, or producer evidence with a mismatched identifier.
- Some checks can be evaluated while other checks require missing external context.
- Transaction includes reference inputs, scripts, datums, redeemers, certificates, withdrawals, governance actions, minted assets, or collateral that require additional context.
- Supplied context is stale, inconsistent, duplicated, or internally contradictory.
- Validation is requested for a large transaction with many inputs and witnesses.
- Transaction is currently valid for supplied context but may become invalid if time-sensitive or chain-state-sensitive context changes later.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST accept a candidate transaction as canonical transaction bytes on every validation request.
- **FR-002**: The system MUST accept all validation context explicitly from the request and MUST NOT depend on hidden workspace state, prior calls, or implicit provider lookups.
- **FR-003**: The system MUST return one of these validation outcomes: valid for supplied context, invalid for supplied context, incomplete because required context is missing, or rejected because the request/context is malformed or contradictory.
- **FR-004**: The system MUST distinguish transaction invalidity from missing validation context.
- **FR-005**: The system MUST report evaluated check groups, unevaluated check groups, failures, warnings, and missing context in a structured result that is also understandable to a user.
- **FR-006**: The system MUST identify missing context at the smallest actionable level available, such as a specific transaction input, source output, time range, protocol setting, network, script execution context, certificate context, or governance context.
- **FR-007**: The system MUST be able to resolve source outputs from supplied producer transaction bytes when the producer transaction identifier and output index match a referenced input.
- **FR-008**: The system MUST reject producer transaction evidence that does not match the referenced input and report the mismatch as invalid context.
- **FR-009**: The system MUST report which source outputs were resolved from producer transactions and which remain unresolved.
- **FR-010**: The system MUST NOT treat provider-specific UTxO snapshots as canonical ledger evidence unless they are supplied as explicit context and identified as caller-provided context in the result.
- **FR-011**: The system MUST NOT submit, sign, balance, patch, or mutate the candidate transaction during validation.
- **FR-012**: The system MUST state that a valid result means "valid for the supplied context" and is not a guarantee of future network acceptance if external context changes.
- **FR-013**: The system MUST produce deterministic results for identical candidate transaction bytes and identical explicit context.
- **FR-014**: The system MUST preserve enough location information for each failure or missing-context item to let a user navigate back to the relevant transaction field or referenced value.
- **FR-015**: The system MUST support partial reporting: failures that can be evaluated are returned even when other required context is missing.
- **FR-016**: The system MUST report request-level errors separately from ledger validation failures.

### Key Entities *(include if feature involves data)*

- **Candidate Transaction**: The transaction currently selected by the user, represented by canonical transaction bytes and treated as the only authoritative transaction state for validation.
- **Validation Context**: Explicit external facts supplied with the request, such as referenced outputs, producer transactions, time and network context, protocol settings, and other ledger state needed for validation.
- **Producer Transaction Evidence**: Canonical bytes for a transaction that created one or more outputs referenced by the candidate transaction.
- **Resolved Source Output**: An output used by the candidate transaction, resolved from producer transaction evidence or from explicitly labeled caller-provided context.
- **Validation Check Group**: A user-visible category of ledger checks that can pass, fail, or remain unevaluated because required context is missing.
- **Validation Failure**: A specific reason the candidate transaction does not satisfy a check for the supplied context.
- **Missing Context Item**: A specific required fact or context category that prevents complete validation.
- **Validation Result**: The complete outcome returned to the user, including status, evaluated checks, failures, warnings, missing context, resolved outputs, and request-level errors.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For a candidate transaction with complete explicit context, users can determine whether it is valid or invalid from the top-level result without reading raw diagnostics.
- **SC-002**: For a candidate transaction with missing context, users can identify at least one concrete next context item to provide from the result.
- **SC-003**: Repeating validation with identical candidate transaction bytes and identical explicit context produces an equivalent result every time.
- **SC-004**: Validation results never imply that a transaction was submitted, signed, balanced, patched, or otherwise changed.
- **SC-005**: For transactions with referenced inputs, the result shows which inputs were resolved from producer transactions and flags any mismatches.
- **SC-006**: A user can navigate from every reported failure or missing-context item to the relevant transaction area or referenced value.

## Assumptions

- Initial scope validates one selected candidate transaction per request.
- Applications may manage multiple transaction documents, but selection and persistence of those documents happens outside this operation.
- External ledger context can change over time, so validation is scoped to the context supplied in the request.
- Producer transaction evidence is preferred for resolving source outputs because it is stable and transaction-centric.
- Balancing, patching, signing, and submission are separate features that may use validation results but are not part of this feature.
