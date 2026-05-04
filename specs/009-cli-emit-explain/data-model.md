# Data Model: tx-deep-diagnosis Stdout Explain Format

## Output Format

- `json`: the existing machine-readable diagnosis envelope on stdout
- `explain`: the single-file markdown explanation on stdout

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
