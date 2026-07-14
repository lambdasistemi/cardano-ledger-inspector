# Tasks: Export the protocol registry as a reusable flake output

## Slice 1 — `protocol-registry` package + drift check

- [X] T149 Add `packages.<system>.protocol-registry`, packaging
      `docs/inspector/protocols` verbatim; add
      `checks.<system>.protocol-registry-drift-check`, asserting every file
      `tx-deep-diagnosis` bundles is byte-identical to the same relative
      path in `protocol-registry`; verify `tx-deep-diagnosis`'s own package
      and checks are unaffected.
