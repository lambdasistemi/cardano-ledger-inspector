# Amaru treasury deployment book

This directory publishes a pinned deployment registry in two forms:

- `journal-2026.json` is the upstream Amaru deployment journal, retained as
  source material.
- `journal-2026.ttl` is the generated generic transaction book. Consumers
  should use this file.

The Turtle overlay resolves the five treasury scopes, their owners, treasury
addresses, treasury/permissions/registry script hashes, and deployment output
references. It is a data package: importing it must not require a consumer to
know the Amaru JSON schema.

## Consumer use

```text
csk tx intent --tx-file transaction.cbor --book journal-2026.ttl --output json
```

## Provenance

`pin.json` identifies the upstream source revision. Regenerate
`journal-2026.ttl` from the pinned JSON whenever that revision changes, and
review the resulting Turtle diff as deployment data.
