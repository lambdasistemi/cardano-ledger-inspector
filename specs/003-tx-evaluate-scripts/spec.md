# Feature Specification: Transaction Script Evaluation Operation

**Feature Branch**: `003-tx-evaluate-scripts`
**Created**: 2026-04-27
**Status**: Draft
**Input**: User description: "Specify tx.evaluate.scripts ledger operation for phase-2 script evaluation over candidate transaction CBOR plus explicit context; report per-redeemer execution units, total execution units, ledger failures, missing context, and contradictory context; no submission, signing, hidden provider lookups, transaction mutation, fee update, balancing, or provider-specific UTxO JSON as authoritative evidence."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Evaluate Phase-2 Scripts (Priority: P1)

A user with a candidate transaction and the required ledger context can ask
whether every phase-2 script in the transaction evaluates successfully and how
many execution units each redeemer consumes.

**Why this priority**: Script evaluation is the next useful ledger operation
after validation because it gives transaction builders precise Plutus execution
feedback before any separate balancing, signing, or submission step.

**Independent Test**: Can be tested by supplying a candidate transaction with
phase-2 scripts plus complete explicit context and verifying that the result
reports per-redeemer evaluation status and total execution units without
returning modified transaction bytes.

**Acceptance Scenarios**:

1. **Given** a well-formed candidate transaction with phase-2 scripts and
   complete explicit context, **When** the user requests script evaluation,
   **Then** the result reports each evaluated redeemer, its script purpose,
   execution units, and an overall successful evaluation status.
2. **Given** a well-formed candidate transaction whose script fails for the
   supplied context, **When** the user requests script evaluation, **Then** the
   result reports an unsuccessful evaluation, identifies the failing redeemer,
   and includes a user-readable ledger failure.
3. **Given** the same candidate transaction and identical explicit context,
   **When** script evaluation is requested repeatedly, **Then** the result is
   equivalent each time and does not depend on prior calls.

---

### User Story 2 - Diagnose Missing or Invalid Evaluation Context (Priority: P2)

A user can learn exactly which external context is missing or contradictory
when phase-2 script evaluation cannot yet run.

**Why this priority**: Script evaluation requires source outputs, protocol
parameters, cost models, time/network context, datums, reference scripts, and
other ledger facts. A result that guesses those facts or reports a generic
failure is not actionable.

**Independent Test**: Can be tested by omitting or corrupting required context
from an evaluation request and verifying that the response distinguishes
incomplete context from an actual script failure.

**Acceptance Scenarios**:

1. **Given** a candidate transaction with a script input whose source output is
   unavailable, **When** the user requests script evaluation, **Then** the result
   reports incomplete evaluation and identifies the unresolved input.
2. **Given** a candidate transaction whose Plutus language needs a missing cost
   model or protocol parameter, **When** the user requests script evaluation,
   **Then** the result reports that missing context category without claiming
   that the script passed or failed.
3. **Given** supplied context that contradicts the transaction, such as producer
   evidence for the wrong transaction id or output index, **When** evaluation is
   requested, **Then** the result rejects that context and does not use it for
   script evaluation.

---

### User Story 3 - Navigate Script Evidence and Budgets (Priority: P3)

A user inspecting a transaction can connect every script evaluation result back
to the transaction area that caused it, including the redeemer, datum, script,
input, withdrawal, certificate, minting policy, or governance action involved.

**Why this priority**: Raw script failures and execution units are difficult to
act on unless the UI can point back to the exact transaction value and copy the
relevant hashes or identifiers.

**Independent Test**: Can be tested by evaluating a transaction with multiple
redeemer purposes and verifying that each result has stable labels, paths, and
copyable identifiers for navigation.

**Acceptance Scenarios**:

1. **Given** a candidate transaction with spending and non-spending redeemers,
   **When** script evaluation completes, **Then** every redeemer result includes
   its purpose, index, related script identifier, related data identifier when
   available, and a path back to the relevant transaction area.
2. **Given** a script evaluation result with execution-unit budgets in the
   transaction, **When** the result is displayed, **Then** the user can compare
   the budgeted units with the evaluated units for each redeemer and for the
   transaction total.
3. **Given** a candidate transaction with no phase-2 scripts, **When** script
   evaluation is requested, **Then** the operation reports that there were no
   scripts to evaluate instead of treating that as a command error.

### Edge Cases

- Candidate transaction bytes are malformed, empty, truncated, or not a
  supported transaction.
- Candidate transaction has no phase-2 scripts or no redeemers.
- Candidate transaction contains Plutus versions whose cost models are missing
  from the supplied protocol context.
- Referenced inputs, reference scripts, inline datums, datum hashes, collateral
  inputs, withdrawals, certificates, minting policies, or governance actions
  require context that is absent.
- Supplied producer transaction evidence has the wrong transaction id, lacks
  the requested output index, or conflicts with another supplied context item.
- Script evaluation can be run for some redeemers but not all because different
  redeemers require different missing context.
- A script fails before all execution units can be measured.
- The transaction budgets fewer execution units than evaluation consumes.
- Context is internally inconsistent, stale, duplicated, or belongs to a
  different network or era.
- The transaction is large and includes many scripts, redeemers, datums,
  reference inputs, and assets.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST accept a candidate transaction as canonical
  transaction bytes on every script-evaluation request.
- **FR-002**: The system MUST accept all evaluation context explicitly from the
  request and MUST NOT depend on hidden workspace state, prior calls, or
  implicit provider lookups.
- **FR-003**: The system MUST return one of these evaluation outcomes:
  successful for the supplied context, failed for the supplied context,
  incomplete because required context is missing, or rejected because the
  request/context is malformed or contradictory.
- **FR-004**: The system MUST distinguish script failure from missing evaluation
  context and from malformed or contradictory request context.
- **FR-005**: The system MUST report every redeemer that can be associated with
  the candidate transaction, including its purpose, index, evaluation status,
  and related transaction location.
- **FR-006**: The system MUST report evaluated execution units for every
  successfully evaluated redeemer and a total execution-unit summary.
- **FR-007**: The system MUST report script failures with the affected redeemer,
  ledger failure detail, and enough location information for a user to navigate
  back to the relevant transaction value.
- **FR-008**: The system MUST identify missing context at the smallest
  actionable level available, such as a specific source output, datum, reference
  script, cost model, protocol parameter, slot, network, certificate state,
  withdrawal state, or governance context.
- **FR-009**: The system MUST be able to use supplied producer transaction bytes
  to resolve source outputs when the producer transaction identifier and output
  index match a referenced input.
- **FR-010**: The system MUST reject or ignore mismatched producer transaction
  evidence and report the mismatch as invalid context.
- **FR-011**: The system MUST NOT treat provider-specific UTxO snapshots as
  canonical ledger evidence unless they are supplied as explicit context and
  identified as caller-provided context in the result.
- **FR-012**: The system MUST NOT submit, sign, balance, patch, recalculate
  fees, update redeemer budgets, or otherwise mutate the candidate transaction.
- **FR-013**: The system MUST NOT return a modified transaction as part of this
  operation.
- **FR-014**: The system MUST state that successful script evaluation means
  "scripts evaluate for the supplied context" and is not a guarantee that the
  whole transaction is valid or will be accepted by the network.
- **FR-015**: The system MUST produce deterministic results for identical
  candidate transaction bytes and identical explicit context.
- **FR-016**: The system MUST support partial reporting: redeemers that can be
  associated with the transaction are returned even when other redeemers cannot
  be fully evaluated because context is missing.
- **FR-017**: The system MUST report request-level errors separately from
  ledger script evaluation failures.

### Key Entities *(include if feature involves data)*

- **Candidate Transaction**: The transaction selected by the user, represented
  by canonical transaction bytes and treated as the only authoritative
  transaction document for this operation.
- **Evaluation Context**: Explicit external facts supplied with the request,
  such as source-output evidence, protocol settings, cost models, time/network
  context, datums, scripts, and other ledger state needed for script
  evaluation.
- **Producer Transaction Evidence**: Canonical bytes for a transaction that
  created one or more outputs referenced by the candidate transaction.
- **Redeemer Evaluation**: The per-redeemer result, including purpose, index,
  related identifiers, status, execution units, and any failure or blocked
  context.
- **Execution Units**: Memory and step counts reported per redeemer and in
  total for evaluated scripts.
- **Evaluation Failure**: A ledger-reported reason a script did not evaluate
  successfully for the supplied context.
- **Missing Context Item**: A specific required fact or context category that
  prevents complete script evaluation.
- **Evaluation Result**: The complete outcome returned to the user, including
  status, redeemer results, total execution units, failures, warnings, missing
  context, and request-level errors.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For a candidate transaction with complete explicit context, users
  can determine whether all phase-2 scripts evaluated successfully from the
  top-level result.
- **SC-002**: For every evaluated redeemer, users can see memory and step
  execution units without reading raw ledger diagnostics.
- **SC-003**: For a failed script, users can identify the affected redeemer and
  a user-readable failure from the result.
- **SC-004**: For incomplete evaluation, users can identify at least one
  concrete next context item to provide.
- **SC-005**: Repeating evaluation with identical transaction bytes and
  identical explicit context produces an equivalent result every time.
- **SC-006**: Evaluation results never imply that the transaction was submitted,
  signed, balanced, patched, had fees recalculated, or was otherwise changed.
- **SC-007**: A user can navigate from every reported redeemer, failure, or
  missing-context item to the relevant transaction area or referenced value.

## Assumptions

- Initial scope evaluates one selected candidate transaction per request.
- Applications may manage multiple transaction documents, but selection and
  persistence of those documents happens outside this operation.
- External ledger context can change over time, so script evaluation is scoped
  to the context supplied in the request.
- Producer transaction evidence is preferred for resolving source outputs
  because it is stable and transaction-centric.
- Full transaction validation, balancing, patching, signing, and submission are
  separate features that may use script evaluation results but are not part of
  this feature.
