# Data Model: Explain Markdown Parity Phase 1

## Explain Layout

- **Purpose**: Ordered view of the single transaction explanation as read by a
  human.
- **Core fields**:
  - `headline`
  - `verdict`
  - `validation_failures`
  - `balance`
  - `fees_resources`
  - `observations`
  - `smart_contract_calls`
  - `outputs`
  - `datums`
  - `claims`
  - `effects`
  - `warnings`
  - `diagrams`
- **Validation rules**:
  - Headline, verdict, and balance must appear before secondary narrative
    sections.
  - Diagram sections may be collapsed, but their content must remain present.

## Headline Action Summary

- **Purpose**: One-line statement answering "what appears to be happening and
  what was the outcome?"
- **Core fields**:
  - `action_text`
  - `outcome_text`
  - `dominant_destination_hint`
  - `confidence_source` (`claim`, `title`, or `fallback`)
- **Validation rules**:
  - Must degrade gracefully when claims are absent.
  - Must never claim more certainty than the current envelope supports.

## Fees & Resources Panel

- **Purpose**: Compact operational summary shown near the top of the report.
- **Core fields**:
  - `fee_lovelace`
  - `tx_size_bytes`
  - `redeemer_count`
  - `committed_memory`
  - `committed_steps`
- **Validation rules**:
  - Unknown values may be omitted, but known values must remain deterministic.
  - Resource totals must be derived from committed redeemer data already in the
    envelope.

## Failure Lead

- **Purpose**: Reader-facing summary of one validation failure.
- **Core fields**:
  - `summary_sentence`
  - `raw_rule_name`
  - `supporting_detail`
- **Validation rules**:
  - The summary sentence is the primary visual cue.
  - The raw rule name remains available for audit/debug context.

## Claim Provenance Badge

- **Purpose**: Mark content that comes from metadata rather than verified ledger
  evidence.
- **Core fields**:
  - `label_text`
  - `provenance` (`self_declared`)
  - `warning_text`
- **Validation rules**:
  - Self-declared badges must appear inline where the claim is rendered.
  - Registry-derived parties must not be mislabeled as self-declared.

## Diagram Fold

- **Purpose**: Collapsed wrapper around an inline Mermaid block in `explain.md`.
- **Core fields**:
  - `summary_label`
  - `diagram_body`
  - `default_state` (`collapsed`)
- **Validation rules**:
  - Collapsing must not remove or rewrite the underlying diagram text.
  - Summary labels must stay readable in plain markdown view.
