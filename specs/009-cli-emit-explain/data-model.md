# Data Model: tx-deep-diagnosis Runtime --emit-explain

## Explain Artifact

- `path`: relative file name under the output directory
- `body`: rendered text content
- `kind`: always-present vs conditional-on-failures

## Known Artifact Set

- `parties.mmd`
- `value-flow.tsv`
- `topology.mmd`
- `failures.mmd`
- `summary.md`
- `explain.md`

The runtime emitter may remove known artifacts that are not produced for the
current transaction, but it must not touch unrelated files in the destination
directory.

## Diagnosis Envelope

The runtime emitter consumes the existing `DiagnosisDoc` typed view:

- `summary`
- `intent`
- `validate`

No new JSON fields are added by this slice.
