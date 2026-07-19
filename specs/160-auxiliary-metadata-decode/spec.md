# Feature Specification: Decode auxiliary transaction metadata

**Feature Branch**: `feat/160-metadata-decode`  
**Created**: 2026-07-19  
**Status**: Ready for implementation  
**Input**: GitHub issue #160, "Decode transaction auxiliary_data/metadata map
(engine-side), not just a count"

## User Story

As a signer or transaction analyst, I need the engine to return the complete
auxiliary metadata map as typed recursive data, so a host can render every
metadata value without decoding Cardano CBOR or guessing whether a JSON string
was originally an integer, byte string, or text string.

## Acceptance Scenarios

1. Given a transaction whose auxiliary metadata contains integer, byte-string,
   text-string, list, and map values at arbitrary nesting depths, when
   `tx.intent` succeeds, then `result.intent.auxiliary_data.metadata` contains
   one label/value entry per ledger metadata label and every recursive value is
   tagged with its original metadata constructor.
2. Given a metadata integer outside JavaScript's safe integer range, the value
   is emitted as an exact decimal string; given metadata bytes, the value is
   emitted as lowercase hexadecimal. Text remains text, list order is
   preserved, and a map is represented as ordered key/value entries so
   non-text keys and duplicate keys are not collapsed into a JSON object.
3. Given a transaction with no auxiliary metadata, the metadata array is empty.
4. Existing `claims` and `metadata_claims` remain compatible and all existing
   ledger-operation checks continue to pass.

## Functional Requirements

- **FR-001**: The Haskell/WASI engine MUST expose decoded metadata under the
  existing `tx.intent` result envelope; hosts MUST NOT need a Cardano metadata
  decoder.
- **FR-002**: A decoded metadata node MUST be one of these tagged shapes:
  `{"type":"int","value":"<decimal>"}`,
  `{"type":"bytes","hex":"<lowercase hex>"}`,
  `{"type":"text","value":"<text>"}`,
  `{"type":"list","items":[<node>...]}`, or
  `{"type":"map","entries":[{"key":<node>,"value":<node>}...]}`.
- **FR-003**: Metadata labels MUST be decimal strings paired with decoded
  values under `intent.auxiliary_data.metadata[]`.
- **FR-004**: Recursive list and map structure, ordering, and original scalar
  types MUST be preserved without lossy JSON-object coercion.
- **FR-005**: The existing human-oriented metadata claim fields MUST remain
  unchanged for compatibility.
- **FR-006**: The public JSON schema and ledger-functional API contract MUST
  document the new field and recursive union.
- **FR-007**: A hermetic regression MUST observe RED before implementation and
  cover all five metadata constructors, nesting, the no-metadata case, and
  compatibility with existing claim fields.

## Success Criteria

- `just check-intent`, `just check-openapi`, `just format-check`, and
  `just hlint` pass with assertions over the typed metadata tree.
- `./gate.sh` passes at the accepted commit.
- No WebUI, provider, network, or repository-external files are changed.

## Non-goals

- Rendering metadata in cardano-swiss-knife or any other host.
- Interpreting metadata according to a particular CIP or protocol.
- Changing provider/network behavior or validating self-declared claims.

